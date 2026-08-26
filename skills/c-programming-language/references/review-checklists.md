# Review Checklists

Working checklists for reviewing C, fixing C bugs, adding new C modules, and deciding when C work is finished. SKILL.md names the steps; this file states how to perform each one and what evidence closes it.

Work a checklist top to bottom. An item passes only when you can point at the line, the bound, the test, or the command output that closes it — "looks fine" is not a pass. An item that does not apply is marked N/A with a reason, not silently dropped.

## Code Review Checklist

Sections 1–2 reconstruct what the code claims. Sections 3–13 attack it. Section 16 comes last, always.

### 1. Contract and invariants

- [ ] Contract reconstructed from the code itself, not from the commit message: inputs, valid ranges, outputs, side effects, owner on success, owner on failure, thread-safety, callback reentrancy, persistence effects. Pass: you can state it in a few sentences without rereading.
- [ ] Reconstructed contract matches the documented contract in the header. A divergence is a finding — one of the two is wrong.
- [ ] Every invariant the code depends on is written down (`len <= cap`; `p` points into `buf[0..len]`; the handle is in exactly one state). Pass: each invariant has an establishing point, and every mutation site preserves it.
- [ ] The diff was read in context, not in isolation: the whole changed function, plus every caller of every changed function (all callers in the TU for `static` ones).
- [ ] For each changed function, you know who may call it concurrently, reentrantly, from a callback, or from a signal handler.

### 2. Allocation and ownership

- [ ] Every acquisition has its failure return checked before the result is used: `malloc`/`calloc`/`realloc`/`strdup` (NULL), `open`/`dup` (-1), `fopen` (NULL), `mmap` (`MAP_FAILED`, not NULL), lock acquisition, thread creation. Pass: point at the check.
- [ ] Allocation sizes use `sizeof *ptr`, not a repeated type name. A type change must not silently under-allocate.
- [ ] Element-count multiplications are overflow-checked or use `calloc` semantics. `malloc(n * sizeof *p)` with untrusted `n` is a finding.
- [ ] Every allocation has exactly one matching release on every path, and you can name the owner at each point.
- [ ] Release uses the matching deallocator and allocator domain: the library's own free function for objects it allocated, the platform's free for platform-allocated memory, and never `free()` across a DLL/shared-library boundary that has its own CRT.
- [ ] `realloc` result is assigned to a temporary; the original pointer is not overwritten by the call. On failure the original is still valid and still released; on success the original is never used again.
- [ ] No pointer, index, or alias into a block survives a `realloc`, a container growth, a `free`, or a scope exit. Pass: interior pointers are recomputed after every possible move, or the container is documented as non-moving.
- [ ] Ownership transfer is explicit at every boundary, including on failure: when a "takes ownership" function fails, the checklist says who frees the argument.
- [ ] Objects are zeroed or fully NULL-initialized at allocation so the destructor tolerates partial construction, or construction unwinds in reverse.
- [ ] No `alloca`, VLA, or stack buffer sized by untrusted input.
- [ ] Flexible-array-member and trailing-data sizing is `offsetof`-based and overflow-checked.
- [ ] No pointer returned to a static or stack buffer where the caller expects to own or outlive it.

### 3. Integer arithmetic feeding sizes, indices, and lengths

- [ ] Every addition, multiplication, or shift whose result becomes a size, index, offset, or loop bound is overflow-checked before use, or bounded by a stated precondition. Use the repository's existing checked helper if it has one.
- [ ] No check written as `if (a + b > limit)` where `a + b` can wrap. The correct form is `if (a > limit - b)`.
- [ ] No post-hoc signed-overflow test (`if (x + y < 0)`). Signed overflow is undefined; the compiler may delete the check. Detect before, not after.
- [ ] No silent narrowing: `int len = strlen(s)`, `int` from `size_t`, `long` from `off_t`/`ssize_t`/`time_t`. Each narrowing is preceded by a range check, or the type is widened.
- [ ] Signed/unsigned comparisons audited. `for (int i = 0; i < len; i++)` with `size_t len` converts `i` to unsigned, so a negative `i` passes the test. Pass: the build is clean under the project's sign-compare warning.
- [ ] Unsigned subtraction cannot go below zero: `len - 1` with `len == 0`, `end - start` where `start > end`, `avail - needed` before comparing.
- [ ] Pointer subtraction only between pointers into the same object.
- [ ] Shift counts are strictly less than the width of the promoted left operand, and never negative. `1 << 31` on 32-bit `int` and `1 << 63` are findings; use `1u`/`UINT64_C(1)`.
- [ ] `char` values are cast to `unsigned char` before being passed to `<ctype.h>` functions or used as an array index. `char` signedness is implementation-defined.
- [ ] Return values that overload a sentinel (`-1` in a signed type, `(size_t)-1`) are checked against the sentinel before being used as a length.
- [ ] See [references/c-correctness.md](c-correctness.md) for promotion and conversion rules.

### 4. Bounds: indexing, pointer arithmetic, bulk copies

- [ ] Every index derived from input is checked against a count, and it is the same count that governs the object being indexed. Two different lengths for one buffer is a finding.
- [ ] The check precedes the access. A validation after a dereference is already too late.
- [ ] Off-by-one audited at each boundary: `<` vs `<=`, `len` vs `len - 1`, inclusive vs exclusive range, and consistent naming so the reader can tell which is meant.
- [ ] Pointer arithmetic stays within the object or one past its end. Computing an out-of-range pointer is undefined even without dereferencing it.
- [ ] For every `memcpy`/`memmove`/`memset`/`strncpy`-style call: destination capacity proved, source extent proved, length clamped to the smaller of the two. Overlapping regions use `memmove`.
- [ ] Loop bounds are re-read after anything that can change the container inside the loop: a callback, a reallocation, recursion, or another thread.
- [ ] Multi-dimensional and stride arithmetic checked: row index against row count and column index against stride, not just the flat product.
- [ ] Terminator and delimiter searches are length-bounded (`memchr` over a known extent) rather than scanning for a byte that may not exist.

### 5. Strings and formatting

- [ ] Every buffer holding a C string has room for the terminator, and the terminator is actually written on every path.
- [ ] `strncpy` uses are audited: it does not terminate when the source fills the buffer. Either terminate explicitly or use a different function.
- [ ] `snprintf` return value handled: it is the length that *would* have been written. `>= size` means truncation; `< 0` means encoding error. Ignoring it is a finding.
- [ ] Every truncation is impossible by construction, detected and handled, or documented as acceptable — never silently discarded.
- [ ] `strcpy`, `strcat`, `sprintf`, `gets` with non-constant sizes flagged.
- [ ] No format string derived from input. Conversion specifiers match argument types and widths (`%zu` for `size_t`, `PRIu64` for `uint64_t`). Pass: clean under the project's format warnings.
- [ ] Length vs size vs capacity distinguished in names and in use; buffers holding bytes read from I/O are not passed to `str*` functions unless separately terminated.
- [ ] Embedded NUL bytes handled as data wherever the format permits them.
- [ ] Locale-sensitive functions (`toupper`, `strcoll`, `atoi`, `strtod` decimal separator, `isspace`) are not used where behavior must be locale-independent, such as protocol and file-format parsing.

### 6. Error returns that are actually checked

- [ ] `close()` return checked where it matters — it can report deferred write errors and can be interrupted on some platforms.
- [ ] `fclose()` checked: it flushes, so it is where a write error surfaces. Discarding it can silently lose data.
- [ ] `fwrite`/`fputs`/`fprintf` return values checked, or `ferror()` consulted before treating the stream as successful.
- [ ] `read`/`write` short results looped, not assumed complete. `EINTR` handled where the platform can raise it.
- [ ] Durability calls checked where the code claims durability: `fflush`, `fsync`/`fdatasync`, `rename`, and directory sync if the format claims crash safety.
- [ ] `snprintf` (see above), `strtol`/`strtoul`/`strtod` (`errno` zeroed before, `endptr` inspected, `ERANGE` checked), and locking/threading calls all checked.
- [ ] `errno` is read immediately after the failing call, and saved before any cleanup call that could clobber it.
- [ ] A deliberately ignored return is marked as such with a reason, not omitted silently.
- [ ] Error categories are propagated with meaning. Collapsing distinct failures into a single boolean or `-1` where the caller must distinguish them is a finding.

### 7. Error paths and cleanup on every exit

- [ ] For each `return`, `goto`, and loop exit in a changed function, list the resources held at that point. Each is released or transferred. Pass: no path releases fewer than it holds, and none releases twice.
- [ ] A single cleanup path releases in reverse acquisition order, and each label is reachable only when the corresponding resources are held.
- [ ] A partially constructed object is only handed to a destructor that tolerates partial construction.
- [ ] The error path does not free something already transferred to the caller; the success path does not free something the caller now owns.
- [ ] Output parameters are left untouched on failure, or the header documents exactly what is written on failure. No half-updated caller state.
- [ ] `errno` or the platform's last-error value is preserved across cleanup when the caller is expected to read it.
- [ ] No exit between acquiring and releasing a lock without unlocking; no `goto` that jumps over a release.
- [ ] Every error path is reachable by a test or by fault injection. Unreachable-in-testing error paths are the ones that are wrong. See [references/verification.md](verification.md).

### 8. Initialization and struct completeness

- [ ] Every field of a newly constructed struct is initialized, or `= {0}` is used and all-zero is a valid state.
- [ ] If the change adds a field to an existing struct, every construction site was found and updated. Pass: you ran the search over the type name and counted the initializers.
- [ ] Designated initializers used for multi-field structs so reordering cannot silently reassign values.
- [ ] No path reads an automatic variable before assignment, including the branch believed unreachable.
- [ ] Padding bytes are not compared with `memcmp`, hashed, or written to disk/wire without deliberate zeroing.
- [ ] Statically initialized locks and atomics use the correct static initializer, not a zeroed struct assumed equivalent.
- [ ] Pointer fields are NULLed after release so cleanup is idempotent and use-after-free turns into an immediate null dereference.

### 9. `const`, interfaces, naming

- [ ] Pointer parameters the function does not modify are `const T *`. `const` is never cast away.
- [ ] `const` is applied at the intended level for pointer-to-pointer parameters.
- [ ] Returned pointers into internal state are documented as borrowed, with lifetime and the operations that invalidate them.
- [ ] New public functions are the minimum surface needed; internals stay out of the public header.
- [ ] Changed headers remain self-contained and include what they use. No reliance on transitive includes.
- [ ] New external symbols carry the project's prefix; anything not intended for export is `static` or hidden.
- [ ] Names carry units and meaning (`len_bytes`, `count`, `capacity`, `offset`), so the reader does not have to infer whether a number is bytes or elements.

### 10. Global and static mutable state

- [ ] Any new global or file-scope mutable state is justified; otherwise the state belongs in a context struct passed by the caller.
- [ ] Static buffers reused across calls or returned to callers break reentrancy and thread safety — removed, or documented as such at the public interface.
- [ ] Lazy initialization of shared state is race-free (a proper once-initialization primitive or correctly ordered atomics), not naive double-checked locking.
- [ ] Signal handlers touch only `volatile sig_atomic_t` objects and async-signal-safe functions — no `malloc`, no `printf`, no locks.

### 11. Concurrency and reentrancy

- [ ] For every shared object touched by the change, the protecting lock (or the atomicity argument) is named. An unprotected shared access is a finding.
- [ ] Lock acquisition order matches the project's documented order; the diff introduces no new ordering. Pass: list every acquisition sequence in the change and check it against the global order for a cycle.
- [ ] No user callback, blocking call, or unbounded work runs under a lock unless deliberate and documented, and no lock is held across a callback that can re-enter the module.
- [ ] Condition-variable waits are inside a predicate loop; no bare wait, no assumption that a wake means the predicate holds.
- [ ] Atomics state and justify their memory ordering. `volatile` is not used for synchronization.
- [ ] Data published by pointer uses a matching release/acquire pair so the pointee's initialization is visible.
- [ ] Reference counts are atomic, only the decrement-to-zero destroys, and there is no path that resurrects an object at count zero.
- [ ] Across `fork`/`exec`: descriptors are created close-on-exec, and no lock is held across `fork` in a threaded process.
- [ ] Concurrency changes were run under a thread sanitizer. See [references/verification.md](verification.md).

### 12. Anything reachable from untrusted input

- [ ] For each parsing/decoding entry point in the diff, trace every untrusted byte to every use as a length, index, offset, count, allocation size, or loop/recursion bound. Each such use has a range check.
- [ ] Declared lengths are validated against the bytes actually available, not against the header's claimed total.
- [ ] Recursion and nesting depth are bounded by an explicit limit, and hitting the limit is a clean error.
- [ ] Input-derived allocations are capped by a documented limit; a 4-byte length field is not a licence to allocate 4 GiB.
- [ ] No `assert()` validates untrusted input. Assertions vanish under `NDEBUG`; the release build must still reject the input.
- [ ] Truncation at every field boundary is handled: input ending mid-header, mid-length, mid-payload. No read past the end.
- [ ] Offsets and indices inside the project's *own* file format are treated as untrusted; the file may have been corrupted or crafted.
- [ ] Binary fields are decoded through fixed-width types with explicit endianness, not by casting a byte pointer to a struct.
- [ ] A fuzz target exists for the changed surface, or was updated to reach it. See [references/verification.md](verification.md).

### 13. Compatibility: API, ABI, on-disk and wire format

- [ ] No change to a public function's signature, semantics, error codes, or ownership rules without an explicit compatibility decision recorded in the change.
- [ ] No layout change to a type callers allocate, embed, or pass by value: fields added, reordered, or resized; enum widened; a macro constant's value changed. These break ABI even when the header still compiles.
- [ ] On-disk/wire encoding, field order, alignment, version number, and defaults are unchanged, or the change carries a version bump and a migration path. Pass: old data still reads, and new data is either readable by old code or cleanly rejected by it.
- [ ] Any deliberate behavior change to an existing API is documented, and in-tree callers are updated in the same change.
- [ ] The exported symbol set is unchanged unless intended, with the project's export list or version script updated.

### 14. Portability and build

- [ ] No new assumption about pointer or integer width, endianness, `char` signedness, struct padding, alignment, or `long`/`wchar_t` width. See [references/performance-portability.md](performance-portability.md).
- [ ] Unaligned data is accessed by copying into an object of the right type, not by casting a byte pointer and dereferencing.
- [ ] No compiler extension or language feature above the project's declared standard, unless the project already uses it.
- [ ] The change builds warning-clean under the project's own warning flags, on every supported compiler available.
- [ ] New files are wired into the build, and the feature-macro and configuration permutations still compile.

### 15. Would the tests have caught this?

- [ ] Ask of every defect found: would the existing suite have detected it? If not, that gap is itself a finding.
- [ ] New tests cover the failure paths introduced, not only the success path.
- [ ] Tests assert semantic outcomes and invariants, not merely absence of a crash.
- [ ] No test in the change passes identically with and without the change.

### 16. Performance (only after correctness)

- [ ] Performance claims in the change are backed by measurement, not by reasoning about the code.
- [ ] No invariant, bound, or clarity was traded away for an unmeasured win.
- [ ] Complexity of new loops and structures is stated, and no input-controlled path is accidentally quadratic. See [references/performance-portability.md](performance-portability.md).

### Reporting findings

For each finding give: `file:line`, the invariant violated, the conditions that trigger it, the consequence, the smallest correct repair, and the regression test that would catch it. State confidence. Do not present a suspicion as a proof, and do not pad the review with speculative items.

## Bug-Fix Checklist

Ordered. Do not jump to the fix.

### Reproduce

- [ ] The failure was reproduced before any code changed, and the exact command is recorded. Pass: you can trigger it on demand.
- [ ] The reproduction is deterministic, or its rate is measured (for example "8 of 100 runs") so you can later tell whether it actually stopped. For races, raise the rate under a thread sanitizer or stress before measuring.
- [ ] The environment that matters is recorded: compiler and version, optimization level, C standard, target, allocator, sanitizers on or off. A bug that appears only at higher optimization or only under a sanitizer is a clue about its class.
- [ ] If it cannot be reproduced, say so, and treat any subsequent fix as unverified rather than proceeding as though it were confirmed.

### Minimize

- [ ] The input and the step sequence are reduced to the smallest that still fails, with each removal re-tested.
- [ ] The entry point is reduced too: a direct call into the failing unit, rather than the full end-to-end path, where that still reproduces.
- [ ] The minimized reproducer is the seed for the regression test.

### Diagnose

- [ ] The violated invariant is named, not the crashing line. Pass: a sentence of the form "at X the code assumes P, and Y made P false."
- [ ] The crash site was checked for being a victim rather than a cause. For memory corruption, read the allocation and free stacks from the sanitizer or debugger report; a null dereference, an absurd length, or a freed pointer usually originates elsewhere. Do not repair at the victim.
- [ ] The moment the invariant broke is separated from the moment the damage surfaced — via an upstream assertion, a watchpoint, or bisecting the data.
- [ ] For a regression, the introducing commit was found and read, and you can say why it broke this.
- [ ] Every observed symptom is explained. An unexplained symptom means the diagnosis is incomplete, not that the extra symptom is noise.
- [ ] The defect is classified — lifetime, bounds, integer, initialization, error path, concurrency, format/compatibility. The class determines which tools run below and which siblings to search for.

### Write the failing test first

- [ ] The regression test was written before the fix.
- [ ] It was run against the unfixed code and observed to FAIL, with the failure matching the real defect (same assertion, same sanitizer report), not merely failing for some other reason. Record that output.
- [ ] The test asserts the violated invariant, so it still catches the bug if the incidental symptom changes (different crash address, different allocation layout).
- [ ] For leak and lifetime defects, the test runs under the sanitizer that detects them, and that check is part of the automated test rather than a manual step. See [references/verification.md](verification.md).

### Fix the cause

- [ ] The fix addresses the invariant identified above, not the place the failure surfaced. No null check added downstream of a corruption, no clamp at the victim, no retry loop — unless null or clamping is genuinely the correct contract.
- [ ] The correction is the smallest complete one. No unrelated cleanup or refactor rides along in the same diff.
- [ ] Contract and invariant comments are updated wherever the fix changes what callers may assume.
- [ ] The fix itself was re-audited against the code-review sections for its defect class.
- [ ] Consider asserting the invariant so a future violation fails loudly, and whether the release build needs a defensive check in addition to the debug assertion.

### Verify

- [ ] The regression test now passes; output recorded.
- [ ] The relevant suites pass, compared against a baseline run of the unmodified tree so pre-existing failures are not mistaken for new ones.
- [ ] The tools matching the defect class were run: address/undefined-behavior sanitizers for memory and integer defects, thread sanitizer for races, the fuzzer for parser defects, static analysis over the touched files. See [references/verification.md](verification.md).
- [ ] The original manual reproducer no longer fails — at the same repeat count used to measure an intermittent bug.
- [ ] Public API, ABI, and format behavior are unchanged, or the change is intentional and documented.

### Find the siblings

- [ ] The tree was searched for the same pattern: the same function misused elsewhere, the same copy-pasted block, the same idiom (every other unchecked `realloc`, every other `strncpy` in the module, every other caller of that API that drops the error). Record the search you ran and the hits you triaged.
- [ ] Each hit is resolved: fixed now if it is plainly the same defect, filed if it is larger, or ruled out with a stated reason.
- [ ] If the class is systemic, a mechanical guard was considered — enabling a warning, introducing a checked helper, asserting in the shared path — instead of an unbounded series of one-off fixes.

### Explain

- [ ] The write-up gives the root cause, the invariant, why it was violated, why the fix restores it, and what the test proves. A list of changed lines is not an explanation.

## New-Module Checklist

Design items come before code. If the contract cannot be stated, the file is not ready to be written.

### Before writing code

- [ ] Contract written: purpose, inputs and valid ranges, outputs, error conditions, side effects, ownership of every argument and every return, borrow lifetimes, thread-safety, reentrancy, callback rules, persistence effects.
- [ ] Ownership stated per resource: creator, owner on success, owner on failure, whether ownership transfers, the release function, and the allocator domain the release must use.
- [ ] Data model and invariants written, each with an establishing point and an argument for why every mutation preserves it.
- [ ] State machine enumerated: states, legal transitions, and the resulting state after each possible failure. The object is in exactly one valid state at all times, including mid-failure.
- [ ] Error model chosen and consistent with the repository's existing convention (error enum, negative errno, out-parameter). Never a bare boolean where callers must distinguish causes. Documented: which errors are recoverable, which leave the object usable, which require destruction.
- [ ] Limits documented: maximum sizes, counts, and depths, and the defined behavior at each limit. "Whatever fits in memory" is not a limit.
- [ ] Portability envelope stated: standard, compilers, word size, endianness, threading model, OS interfaces used. See [references/performance-portability.md](performance-portability.md).
- [ ] The repository was searched for an existing abstraction that already covers this — checked arithmetic, buffer type, allocator wrapper, error type, platform layer. Do not add a parallel one.

### Public header

- [ ] The header exposes the minimum: no internal structs, no internal helpers, no implementation-only includes leaking to callers.
- [ ] Stateful components are opaque handles; the struct definition lives in the `.c` file or a private header.
- [ ] The header is self-contained: it compiles on its own and includes exactly what it uses.
- [ ] Every external name carries the project prefix. Everything else is `static` or has hidden visibility.
- [ ] Fixed-width types at any binary boundary; no `long`, no bare `enum`, no `bool` in a serialized or ABI-visible position.
- [ ] Ownership and lifetime are documented per function in caller-facing terms ("caller releases with X", "valid until Y is called").
- [ ] Thread-safety and callback reentrancy documented per function — including "not thread-safe" where that is the honest answer.
- [ ] Invalid states are hard to construct: no create-then-configure sequence that leaves a half-configured object usable.

### Implementation

- [ ] Failure paths were written and tested before the success path was filled in. Construction unwinds in reverse; the destructor tolerates a partially constructed object.
- [ ] A single cleanup path is used where it makes correctness inspectable at a glance.
- [ ] Every acquisition is checked, every size is computed with checked arithmetic, every index is bounded. See [references/c-correctness.md](c-correctness.md).
- [ ] Assertions state programmer invariants at preconditions, postconditions, state transitions, and loop invariants — never as input validation, never with side effects.
- [ ] The release build with `NDEBUG` is safe: no bound or check exists only inside an assertion where reachable input could violate it.
- [ ] No new global mutable state; context is passed explicitly.

### Tests

- [ ] A failure-path test exists for every failure in the failure model, including allocation failure at each allocation site — fail the Nth allocation and iterate N across the operation, checking for leaks, double release, corrupted state, and correct propagation. See [references/verification.md](verification.md).
- [ ] Boundary tests: zero, one, exactly capacity, capacity plus one, the documented maximum, one past it, empty input, single-byte input.
- [ ] Hostile-input tests: truncation at every field boundary, oversized and negative length fields, unterminated strings, embedded NULs, maximal nesting, cyclic or self-referential offsets, duplicate keys, invalid encodings.
- [ ] A fuzz target exists for every untrusted-input entry point, with a seed corpus and assertions on semantic invariants — not merely "did not crash".
- [ ] Tests assert postconditions, including the object's state after a failed call and that a failed call leaks nothing.
- [ ] Leak, descriptor, and handle accounting is part of the test run.

### Build

- [ ] New files are wired into the build system, and the build is warning-clean under the project's full warning set on every supported compiler available.
- [ ] Every feature-macro and configuration permutation the project supports still compiles.
- [ ] The code compiles under the project's declared C standard, using no extension the project does not already rely on.
- [ ] The sanitizer build passes and static analysis over the new files is clean, or the remaining diagnostics are triaged in writing.

### Documentation

- [ ] Compatibility guarantees are documented: whether the API is stable, whether the format is versioned, and what is explicitly allowed to change.
- [ ] Non-obvious invariants, proofs, format constraints, and workarounds are commented where the code needs them, giving the reason rather than restating the mechanics.

## Completion Gates

The bar for calling C work done. Each gate closes on evidence produced in this session — a command that was run and its output. Reasoning is not evidence, and "should pass" is not a pass.

### Evidence rules

- [ ] Every claim of the form "builds", "tests pass", "no leaks", "faster" names the command that was run and its result. Not run means not known.
- [ ] Nothing is reported as verified on the strength of reading the code.
- [ ] No stale output is reused: the last edit precedes the last verification run.
- [ ] Anything that could not be run here — an unavailable compiler, another platform, a long fuzz campaign, real hardware — is listed as unresolved verification work, with what would close it. It is neither omitted nor implied to have passed.
- [ ] Every assumption that could not be established from the repository is stated.

### Build gate

- [ ] The project's canonical build command was run and succeeded; command and result recorded.
- [ ] No new warnings under the project's warning flags. Where the tree is not already warning-clean, compare against a baseline build of the unmodified tree.
- [ ] Every compiler, standard, and configuration in the supported matrix that is available here was built. Those unavailable are listed as unverified.

### Correctness gate

Each question is answered from evidence. An unanswerable one is unresolved work, not a pass.

- [ ] Behavior is defined for every supported input, including empty, maximal, and malformed.
- [ ] Every size and index computation is bounded by a check or by a stated precondition.
- [ ] Ownership and lifetime of every pointer crossing an interface are unambiguous.
- [ ] Every acquisition failure is handled and leaves a valid, releasable state.
- [ ] Untrusted input cannot drive an allocation size, index, loop count, or recursion depth without a bound.
- [ ] The `NDEBUG` build is safe: no check exists only as an assertion where reachable input can violate it.
- [ ] State transitions remain valid after every failure; no half-updated object escapes to the caller.
- [ ] Concurrency assumptions are explicit; every shared datum names its lock or its atomicity argument.
- [ ] Persistence guarantees match what the code does under interruption — ordering, flushing, atomic replacement, and recovery.
- [ ] API, ABI, and format compatibility are preserved, or the break is deliberate and documented.

### Test gate

- [ ] The relevant suites were run; command, pass/fail counts, and any failures recorded.
- [ ] A baseline comparison distinguishes pre-existing failures from ones introduced here.
- [ ] Every bug fix carries a regression test that was observed failing before the fix.
- [ ] Failure paths are exercised, not merely present. Where coverage tooling exists, error-branch coverage was checked. See [references/verification.md](verification.md).
- [ ] New untrusted-input surfaces were fuzzed, with the duration reported honestly rather than described as "fuzzed".

### Tool gate

Run what the change's defect class calls for, and report both what was run and what was skipped.

- [ ] Address and undefined-behavior sanitizers were run over the relevant tests and are clean.
- [ ] A thread sanitizer was run for any concurrency change, and is clean.
- [ ] Static analysis over the changed files is clean or the diagnostics are triaged in writing.
- [ ] Leak, descriptor, and handle accounting is clean at exit.

### Performance gate

Applies only when the work claims a performance result.

- [ ] A baseline was measured before the change, on the same machine and the same settings.
- [ ] The build is release-equivalent, and the number comes from repeated runs with variance reported — not a single measurement.
- [ ] The workload is stated, and it is the workload that matters. See [references/performance-portability.md](performance-portability.md).
- [ ] No performance claim is made without these. "Should be faster" is not a result.

### Reporting gate

- [ ] The report states what changed, why, what was verified and by which command, and what remains unverified.
- [ ] Residual risks are named: the input class not tested, the platform not built, the race not reproduced, the assumption not confirmed.
- [ ] Work is not described as complete while any correctness item above is merely assumed. Name the open items instead.
