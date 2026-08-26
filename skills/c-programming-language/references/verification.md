# Verification

How to produce evidence that C code is correct, and how to judge how strong that evidence is.
Everything here is about attacking the implementation on purpose; none of it substitutes for the reasoning in `references/c-correctness.md`.

## Testing

### What a C test suite is arguing

A test run proves one thing: these inputs, on this build, on this platform, did not trip a check that was actually present. Nothing more. Every claim of the form "it works" must be reducible to a list of configurations, inputs, and instrumentation. When you cannot name those, you have not verified anything.

"It compiles clean and runs clean" is not evidence:

- Warnings only fire on patterns the compiler models; most UB is invisible to it.
- Sanitizers only report on code that executed with instrumented memory. An untaken branch is unexamined.
- A passing run under ASan proves that this path did not touch poisoned memory. It does not prove the path is memory-safe for other inputs, other allocation sizes, or other alignments.
- Undefined behavior can be silently benign at `-O0` and fatal at `-O2`.

State results positively: "parser fuzzed 4 CPU-hours under ASan+UBSan, no new crashes; corpus of 812 inputs replays clean; allocation failure injected at every site in `doc_parse`, no leaks" — not "tests pass".

### Harness shape

For C specifically, run each test in its own process. A test that segfaults or hits `abort()` must be a reported failure with a name, not a dead runner. A forking runner buys you:

- crash isolation and the ability to assert that a call *does* abort;
- a clean address space per test, so leak checks are per-test rather than per-suite;
- per-test timeouts (`alarm()` in the child, or `SIGKILL` from the parent);
- deterministic ordering independent of leaked global state.

Report the signal and the test name. Frameworks that fork by default: Check, Criterion, cmocka. Header-only, non-forking, fine for pure logic: greatest, µnit, Unity. Do not adopt a framework where a 60-line runner with `fork`/`waitpid` and an exit-code convention would do; the framework is not the thing being verified.

### Table-driven tests

The default shape for anything with a value domain. Keep the case name in the table so a failure identifies itself.

```c
static const struct {
    const char *name;
    const char *input;
    size_t      input_len;
    int         want_rc;
    uint64_t    want_value;
} cases[] = {
    { "empty",        "",        0, EINVAL, 0 },
    { "zero",         "0",       1, 0,      0 },
    { "max",          "18446744073709551615", 20, 0, UINT64_MAX },
    { "max_plus_one", "18446744073709551616", 20, ERANGE, 0 },
    { "trailing_nul", "1\0" "2", 3, EINVAL, 0 },
};

for (size_t i = 0; i < sizeof cases / sizeof cases[0]; i++) {
    uint64_t v = 0xdeadbeef;             /* poison: proves the callee wrote it */
    int rc = parse_u64(cases[i].input, cases[i].input_len, &v);
    CHECK(rc == cases[i].want_rc, "case %s (#%zu): rc=%d want=%d",
          cases[i].name, i, rc, cases[i].want_rc);
    if (rc == 0)
        CHECK(v == cases[i].want_value, "case %s: value", cases[i].name);
    else
        CHECK(v == 0xdeadbeef, "case %s: out param modified on failure",
              cases[i].name);
}
```

Two habits in that snippet matter more than the table itself: poisoning the output parameter before the call, and asserting it was *not* written on the error path. Most "returns an error but also half-writes the output" bugs are only findable this way.

Boundary rows are not optional: `0`, `1`, `n-1`, `n`, `n+1`, `SIZE_MAX`, empty, single byte, exactly one buffer's worth, one byte over, embedded `NUL`, and non-UTF-8 bytes if text is involved.

### Testing failure paths specifically

Failure paths are the least-executed and least-reviewed code in any C program, and they are where the double frees live. Test them directly:

- **Force each error return.** For every `return ERR_x` in a function, there must be a test that produces it. Coverage tooling tells you which ones you missed (see *Coverage*); fault injection makes the unreachable ones reachable (see *Fault injection*).
- **Assert the specific error**, not `rc != 0`. A test that accepts any nonzero return will keep passing when the function starts failing for a different reason.
- **Assert post-failure state.** After a failed call, the object is either untouched, or fully destroyed, or in a documented degraded state. Pick one in the contract and assert it. Then call the object again and assert the second call behaves as documented — "usable after a failed operation" is a contract clause that is almost never tested.
- **Partial failure.** For batch/vectored APIs, assert exactly how many elements were applied and that the rest were not. `pwritev` returning short, a bulk insert failing at element 7, a callback returning an error mid-iteration: assert the boundary, not just the error code.
- **Idempotent teardown.** Call the destructor on a partially constructed object. Call it twice if the contract allows. Call it on `NULL`.
- **`errno` discipline.** If the contract mentions `errno`, tests must set `errno` to a sentinel before the call and assert the value after. Note that `errno` is only meaningful after a call that documents it, and library functions may clobber it on success.

### Test doubles without a framework

C has no dependency injection; it has link seams. Ranked by how little they distort the code under test:

1. **A vtable in the struct.** The component already takes an allocator/clock/IO interface as a pointer to a const struct of function pointers. Tests pass a fake. This is a design choice made before the tests exist and it is the right one for anything with an IO or time dependency.
2. **Weak symbols.** Define the production function `__attribute__((weak))`; the test TU defines a strong override. GNU/ELF only; does not work on Mach-O the same way, and LTO can defeat it.
3. **`-Wl,--wrap=symbol`** (GNU ld, LLD). Calls to `symbol` link to `__wrap_symbol`; the real one is `__real_symbol`. Only intercepts *cross-TU* calls that survive to link time — a call inside the same TU, or inlined, is not wrapped. Not available on macOS `ld64` (use `-Wl,-interpose` or `DYLD_INSERT_LIBRARIES` with an interpose section).
4. **`LD_PRELOAD` shim** with `dlsym(RTLD_NEXT, "malloc")`. Process-wide, catches everything including libc internals, awkward to make deterministic.
5. **Including the `.c` under test** from the test TU (`#include "parser.c"`), or compiling with `-DSTATIC=` where the source writes `STATIC void helper(void)`. This is how you test `static` helpers. The tradeoff is real: the test now depends on internal names and will break on refactors. Use it for algorithmic cores, not for API-level tests.

Prefer testing through the public API. A private helper that is hard to reach through the API is usually a sign the API is missing a seam, not that the test needs one.

### Determinism

Nondeterministic tests get muted, and muted tests verify nothing.

- **Seeds.** Any randomized test takes its seed from the environment with a fixed default, and *always* prints it: `seed = getenv("TEST_SEED") ? strtoull(...) : 0x5eed;` then `fprintf(stderr, "seed=%llu\n", seed)`. Use your own PRNG (a small xorshift/PCG in the test), not `rand()` — `rand()` differs across libc implementations, so a "reproducer seed" from CI would not reproduce locally. Randomize seeds only in a nightly job, never in the PR gate.
- **No wall clock, no `getpid()`, no address values, no iteration order of a hash table** in anything a test compares.
- **Fix the locale** (`LC_ALL=C`) and the timezone (`TZ=UTC`) in the runner. `printf("%f")`, `strtod`, and `isalpha` are locale-sensitive.
- **Threading tests are not deterministic**; make them *sensitive* instead. Run the racy section many times, add jitter, run under TSan, and assert invariants rather than schedules. Treat a threading test that passes once as unrun.

### Golden files

For serializers, formatters, disassemblers, and anything with a large stable output:

- Make the output canonical first: sorted, no timestamps, no pointers, no absolute paths, no addresses, fixed float formatting (`%a` or `%.17g` if the value must round-trip).
- Store goldens as files in the repo, compare byte-for-byte, and print a unified diff on failure.
- Provide `UPDATE_GOLDEN=1` regeneration, but treat a golden diff in review as a *behavior change requiring justification*. The failure mode of golden tests is a reviewer regenerating them to make CI green.
- Goldens catch unintended change; they do not establish correctness. Pair each golden with at least one property assertion (round-trip, schema validity) so a wrong-but-stable output is still caught.

### Beyond examples

- **Property and metamorphic tests.** `parse(print(x)) == x`; `decompress(compress(x)) == x`; `sort` output is a permutation of its input and is ordered; `insert` then `lookup` finds it; adding an element never decreases `count`. These generalize past the examples you thought of. `theft` is a usable property-testing library for C; a hand-rolled generator plus a shrink loop is often enough.
- **Differential testing against a model.** Implement the operation a second time, slowly and obviously (a linked list beside the hash table, a naive parser beside the fast one), and assert they agree across a random operation stream. This is the highest-yield technique for data structures and is far cheaper than it looks.
- **Soak/stress.** Long-running loops that assert an accounting invariant (allocations == frees, refcounts return to zero, arena high-water mark bounded). Runs nightly, not in the PR gate.

## Assertions

### `assert` versus a runtime check

The distinction is the single most commonly blurred thing in C verification.

| | Assertion | Runtime check |
|---|---|---|
| Claim | "I have proven this is true" | "This may be false" |
| Source of the value | internal, already validated | untrusted input, environment, syscall result |
| Violation means | a bug in this program | an expected condition |
| Behavior | abort, loudly, at the earliest point | return an error, or reject the input |
| Present in release | maybe not | always |

`assert(len <= buf_size)` where `len` was read off a wire is a security bug: compile with `-DNDEBUG` and it becomes an unchecked overflow. The same expression is correct when `len` is a field the module itself computed and maintains.

Rule of thumb: if you can write down the input that violates the condition, it is not an assertion.

### Mechanics that bite

- `NDEBUG` is evaluated at each `#include <assert.h>`, not once per TU. A header included after `#define NDEBUG` disables asserts for what follows. Do not rely on this; do not fight it.
- **Assertions must be pure.** `assert(pop(&q) == 0)` deletes the `pop` in release builds. If you need the side effect, hoist it: `int rc = pop(&q); assert(rc == 0); (void)rc;` — and note the `(void)rc` is needed to avoid an unused-variable warning in release.
- `assert(cond && "explanation")` puts the explanation in the message. `assert(!"unreachable state")` for impossible branches.
- `assert` calls `abort()`, which raises `SIGABRT` and dumps core. In a library, this kills the host process. That is often correct — continuing after an invariant violation corrupts data — but it is a contract decision that belongs in the documentation.

### A project assert that survives NDEBUG

Almost every serious C codebase needs two macros, not one:

```c
/* Always compiled in. Violation means unrecoverable corruption. */
#define PROJ_CHECK(cond) \
    ((cond) ? (void)0 : proj_fail(#cond, __FILE__, __LINE__, __func__))

/* Debug-only. Violation means a bug, but the release build can survive. */
#ifdef NDEBUG
#  define PROJ_ASSERT(cond) ((void)0)
#else
#  define PROJ_ASSERT(cond) PROJ_CHECK(cond)
#endif

_Noreturn void proj_fail(const char *expr, const char *file, int line,
                         const char *func);
```

Use `PROJ_CHECK` where the cost of continuing exceeds the cost of stopping: before writing to persistent state, at allocator boundaries, on refcount underflow, on any condition where the alternative is silent corruption. Use `PROJ_ASSERT` for dense internal invariants in hot paths.

`proj_fail` should be a real function (not inlined) that writes a single line to `stderr` with everything needed to file a bug, then aborts. Async-signal-safety matters if it can be reached from a handler; `write(2)` of a preformatted buffer, not `fprintf`.

### What assert-free release builds cost

Compiling out assertions converts loud, local failures into silent, distant corruption. The bug does not go away; the *diagnosis* goes away. Weigh that against the actual measured cost, which for a predictable branch is usually indistinguishable from zero outside the tightest loops.

Defensible positions, in order of preference:

1. Ship with assertions **on**. Fail fast. Correct for most software.
2. Ship with a *subset* on (`PROJ_CHECK`) and the dense ones off. Correct for hot code.
3. Ship with all off, but pair every compiled-out assertion on an externally influenced value with a release-mode check that returns an error. This is "defense in depth" and it must be deliberate, not accidental.

What is **not** defensible: replacing an assertion with `__builtin_unreachable()` / C23 `unreachable()` in release. That does not remove a check, it grants the optimizer permission to assume the condition and to delete the code that would have handled the violation. `if (!(x)) __builtin_unreachable();` is an *assumption*, not an assertion; use it only for invariants you have actually proven and only where the codegen win was measured.

Never define `NDEBUG` in fuzz builds, sanitizer builds, or CI test builds. Assertions are the fuzzer's oracle: without them the only bug class it finds is "crashes".

### `static_assert`

Free, checked at compile time, catches an entire class of portability and layout bugs. Available as `_Static_assert` (C11) and as `static_assert` via `<assert.h>`; C23 makes `static_assert` a keyword and allows omitting the message.

```c
static_assert(CHAR_BIT == 8, "port assumes 8-bit bytes");
static_assert(sizeof(struct wire_header) == 16, "wire layout changed");
static_assert(offsetof(struct wire_header, length) == 4, "wire layout changed");
static_assert(sizeof(names) / sizeof(names[0]) == OP_COUNT,
              "names table out of sync with enum");
static_assert((FLAG_MASK & FLAG_RESERVED) == 0, "flag overlap");
```

The table/enum synchronization assertion is the highest-value one; it turns "someone added an enum value and forgot the string table" from a runtime out-of-bounds read into a build error.

Pre-C11 fallback: `typedef char proj_sa_##line[(cond) ? 1 : -1];`

## Fault injection

Untested cleanup paths are where leaks, double frees, and half-initialized objects live, because they are the only code in the program that never runs during development. Inspection does not find these; enumeration does.

### Allocation failure, exhaustively

The technique: make the Nth allocation fail, iterate N from zero until the operation no longer reaches N allocations, and check the world after each run.

```c
/* alloc_hook.c — linked into test builds only. */
static long fail_at = -1;   /* -1 disables injection */
static long calls;

void *proj_malloc(size_t n)
{
    if (fail_at >= 0 && calls++ == fail_at)
        return NULL;
    return malloc(n);
}
long proj_alloc_calls(void)      { return calls; }
void proj_alloc_reset(long at)   { calls = 0; fail_at = at; }
```

```c
for (long n = 0; ; n++) {
    proj_alloc_reset(n);
    int rc = run_operation();          /* the full operation under test */
    bool injected = proj_alloc_calls() > n;

    if (!injected) {
        /* n is past the operation's allocation count: all sites covered. */
        CHECK(rc == 0, "uninjected run must succeed");
        break;
    }
    /* A failure may be tolerated (an optional cache) or propagated. */
    CHECK(rc == 0 || rc == PROJ_ENOMEM, "unexpected error %d at n=%ld", rc, n);
    verify_invariants_and_teardown();
}
```

The termination condition is `!injected`, not `rc == 0`. A run can succeed *while* an allocation failed, if the failure was for something optional — terminating on `rc == 0` silently stops the sweep early and leaves later sites untested.

What to check after each injected run:

- **Leaks.** Either fork per iteration so LeakSanitizer runs at each child's exit, or call `__lsan_do_recoverable_leak_check()` from `<sanitizer/lsan_interface.h>` after teardown. Without one of these the leak report at process exit cannot tell you *which* N leaked.
- **No double free / use-after-free.** ASan covers this if the run is under ASan. Run the sweep under `-fsanitize=address,undefined`.
- **State validity.** The object under test is either untouched or destroyed; a subsequent operation on it behaves as documented.
- **Error propagation.** The error surfaced to the caller, not swallowed and turned into a `NULL` field discovered three functions later.
- **Recovery.** Retry the operation with injection disabled and assert it now succeeds.

Getting the hook in: the cleanest design routes the module's allocations through a project allocator (a `struct proj_alloc *` on the context), which the test replaces — no linker tricks and it works on every platform. Failing that, `-Wl,--wrap=malloc,--wrap=calloc,--wrap=realloc,--wrap=free` on GNU ld/LLD, or `LD_PRELOAD`. Note that `--wrap` misses intra-TU and inlined calls, and misses allocations inside libc itself (`strdup`, `getline`, `asprintf`) unless you wrap those too.

A coarse alternative for a smoke test is `setrlimit(RLIMIT_AS, ...)`, but it is not deterministic, cannot target a specific site, and on Linux with overcommit may not fail at all.

### Syscall and I/O failure

The same discipline applies to every fallible external call. Common gaps:

| Condition | How to produce it |
|---|---|
| Short `read`/`write` | pipe or `socketpair` with a small `SO_SNDBUF`; a pty; a wrapper that truncates every write to 1 byte |
| `EINTR` | `sigaction` with `SA_RESTART` cleared plus `setitimer` firing during the call |
| `ENOSPC` | small tmpfs or loopback filesystem; `strace -e inject=write:error=ENOSPC:when=3` |
| `EMFILE` | `setrlimit(RLIMIT_NOFILE, ...)` |
| `EAGAIN` | non-blocking fd with a full/empty buffer |
| `fsync` failure | device-mapper `dm-error`/`dm-flakey`, or a wrapper |
| Arbitrary errno at call N | `libfiu` (`fiu-run -x -c 'enable_random name=posix/io/*,probability=0.05' ./prog`), or `strace -e inject=` on Linux |
| Crash / power loss | kill -9 between operation N and N+1, then run recovery and verify; `dm-log-writes` + replay for real barrier semantics |

Wrap the syscalls the module actually uses behind a thin internal layer (`proj_read`, `proj_write`, `proj_fsync`) and inject there. This costs one indirection and buys deterministic, portable injection with no `LD_PRELOAD`.

For persistent state, the property to test is not "the write succeeded" but "after an interruption at any point, recovery produces either the old valid state or the new valid state". Enumerate interruption points the way you enumerate allocation sites.

### Keeping the hook honest

Injection hooks that are `#ifdef`'d out of release builds mean the tested binary is not the shipped binary. Prefer a hook that is always compiled in but inert — a function pointer that is `NULL` in production, or a `fail_at` that is `-1` — so the shipped code path is the tested code path. If the branch is genuinely unaffordable, accept the `#ifdef` and note that the injection build is a distinct configuration in the release matrix.

Make injection reproducible: when injection is randomized, print the seed and the site index on failure so the exact scenario can be replayed.

## Fuzzing

### Coverage-guided versus blind

Blind fuzzing (random bytes, random mutations, no feedback) finds shallow bugs and plateaus within minutes. Coverage-guided fuzzing instruments every edge, keeps inputs that reach new edges, and mutates from that corpus — it hill-climbs into states no hand-written test reaches. Use coverage-guided fuzzing; there is no reason not to.

The two engines worth knowing:

- **libFuzzer** — in-process, links into your target, driven by `LLVMFuzzerTestOneInput`. Fastest per-exec, simplest to set up, best for library APIs. It is in maintenance mode upstream but remains the OSS-Fuzz baseline.
- **AFL++** — out-of-process by default (with a fast persistent mode), a much richer mutator and scheduler set, and a large tooling ecosystem. Generally finds more over long campaigns.

They are not mutually exclusive: AFL++ ships `aflpp_driver` (`libAFLDriver.a`), so a libFuzzer harness runs unmodified under `afl-fuzz`. Write the harness once in libFuzzer shape.

### Writing `LLVMFuzzerTestOneInput`

```c
#include <stddef.h>
#include <stdint.h>
#include <assert.h>
#include "doc.h"

int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size)
{
    if (size < 1)
        return 0;

    /* Take control bytes from the END: front-anchored data stays stable
       when the mutator inserts or deletes bytes at the front. */
    unsigned flags = data[size - 1] & DOC_FLAG_MASK;
    size -= 1;

    struct doc *d = doc_parse(data, size, flags);
    if (d == NULL)
        return 0;                       /* rejection is a valid outcome */

    /* Semantic oracles, not just "did not crash". */
    assert(doc_node_count(d) <= size);  /* no node without an input byte */

    uint8_t *out = NULL;
    size_t out_len = 0;
    if (doc_serialize(d, &out, &out_len) == 0) {
        struct doc *d2 = doc_parse(out, out_len, flags);
        assert(d2 != NULL);             /* our own output must parse */
        assert(doc_equal(d, d2));       /* and round-trip identically */
        doc_free(d2);
        free(out);
    }
    doc_free(d);
    return 0;
}
```

Rules for the body:

- **Assertions are the oracle.** Build fuzz targets *without* `NDEBUG`. A fuzzer with no assertions finds only crashes; a fuzzer with strong invariants finds wrong answers.
- **Return 0.** Return `-1` to tell libFuzzer "reject this input, do not add it to the corpus" — useful for inputs that fail a cheap structural precondition. Other values are reserved.
- **No global state across calls.** The same input must produce the same result on call 1 and call 10000, or crash reproduction fails.
- **No time, PID, randomness, network, or filesystem.** If the API needs a file, use `memfd_create`/`tmpfile` deterministically, or refactor to accept a buffer.
- **Bound allocations by input size.** A length field of `0xFFFFFFFF` that becomes a `malloc` is an OOM report, not a bug — unless it is. Decide: either the library must reject implausible sizes (then assert that it does), or the harness caps them. Use `-rss_limit_mb` and `-malloc_limit_mb` to make the distinction explicit.
- **Keep it fast.** Target >1000 exec/s. No logging to stdout, no `sleep`, no per-call setup that could be hoisted into `LLVMFuzzerInitialize(int *argc, char ***argv)`.
- **One target per entry point**, not one target with a mode byte covering ten APIs — separate targets get separate corpora and separate coverage feedback.

### Structure-aware fuzzing

Byte-oriented mutation is useless against a format with checksums, magic numbers, or a length-prefixed grammar: the fuzzer spends its budget failing the first validation. Options, in increasing order of effort:

1. **Build with checks disabled.** Compile the fuzz target with `-DFUZZING_BUILD_MODE_UNSAFE_FOR_PRODUCTION` and skip CRC verification under that macro. Cheapest and very effective. Fuzz a second target *with* the check on so the check itself is exercised.
2. **`-use_value_profile=1`** (libFuzzer) or **CmpLog/Redqueen** (`AFL_LLVM_CMPLOG=1` at build, `-c <cmplog_binary>` at run) — both let the engine solve magic-value comparisons. AFL++'s `AFL_LLVM_LAF_ALL=1` splits multi-byte comparisons so coverage feedback can climb them.
3. **Interpret the input as a script.** For stateful APIs, treat the buffer as an opcode stream: each byte selects an operation, following bytes are arguments. This is how you fuzz a hash table, an allocator, or a state machine, and it is the highest-value structure-aware technique for C.

```c
    while (p < end) {
        switch (*p++ % OP_COUNT) {
        case OP_INSERT: /* consume key/value bytes, insert */ break;
        case OP_ERASE:  /* consume a key, erase */            break;
        case OP_ITER:   /* walk and assert ordering */        break;
        }
        assert(map_invariants_hold(m));   /* after every operation */
    }
```

4. **Custom mutator.** libFuzzer: `size_t LLVMFuzzerCustomMutator(uint8_t *data, size_t size, size_t max_size, unsigned seed)`, which may call `LLVMFuzzerMutate` for sub-mutations; plus `LLVMFuzzerCustomCrossOver`. AFL++: a shared object exporting `afl_custom_init`/`afl_custom_fuzz`, loaded via `AFL_CUSTOM_MUTATOR_LIBRARY`.
5. **Grammar/protobuf-based generation** (libprotobuf-mutator). Powerful, C++-only in practice, real maintenance cost. Justify it before adopting it.

### Corpus, dictionaries, minimisation

- **Seed corpus.** Start from real, valid, small, *diverse* inputs — one per feature, not a thousand near-duplicates. Existing test fixtures and regression files are the best seeds. A good corpus is worth more than a day of extra fuzzing.
- **Dictionary.** A plain file of tokens, AFL/libFuzzer compatible:
  ```
  # keywords the format cares about
  kw_head="\xff\xd8\xff"
  kw_null="null"
  kw_open="<?xml"
  ```
  Pass with `-dict=x.dict` (libFuzzer) or `-x x.dict` (AFL++). Cheap, disproportionately effective on text formats.
- **Minimise the corpus** before committing it:
  ```sh
  ./fuzz_doc -merge=1 corpus_min corpus_raw     # libFuzzer: keeps coverage, drops redundancy
  afl-cmin -i corpus_raw -o corpus_min -- ./target @@
  ```
- **Minimise a crash** before filing it:
  ```sh
  ./fuzz_doc -minimize_crash=1 -runs=100000 crash-6f3a...
  afl-tmin -i crash -o crash.min -- ./target @@
  ```
- **Commit the minimised corpus** and replay it in CI as a regression suite (`./fuzz_doc corpus_min` runs every input once, deterministically, in seconds). Every fixed fuzz crash gets its reproducer added to the corpus.

### Running

```sh
# libFuzzer
clang -g -O1 -fno-omit-frame-pointer \
      -fsanitize=fuzzer,address,undefined -fno-sanitize-recover=undefined \
      fuzz_doc.c doc.c -o fuzz_doc

./fuzz_doc corpus/ -dict=doc.dict -max_len=65536 -jobs=8 -workers=8 \
           -max_total_time=3600 -rss_limit_mb=2048 -print_final_stats=1
```

Prefer `-max_len=` over rejecting oversized inputs inside the target: the mutator learns nothing from a rejected input.

```sh
# AFL++
AFL_USE_ASAN=1 AFL_USE_UBSAN=1 afl-clang-lto -g -O2 fuzz_doc.c doc.c \
    -o target /path/to/libAFLDriver.a
afl-fuzz -i corpus -o findings -x doc.dict -M main -- ./target
afl-fuzz -i corpus -o findings -S sec1 -- ./target      # parallel workers
```

`afl-clang-lto` gives collision-free coverage instrumentation and is preferred where LTO is usable; `afl-clang-fast` otherwise. Persistent mode (`__AFL_FUZZ_INIT()`, `while (__AFL_LOOP(10000))`, `__AFL_FUZZ_TESTCASE_BUF`/`_LEN`) is worth an order of magnitude in exec/s over fork mode; the driver above provides it for you.

Note that ASan roughly halves fuzzing throughput and its allocator changes heap layout, so ASan and non-ASan campaigns find somewhat different bugs. Run both when the budget allows; ASan first if it does not.

### OSS-Fuzz shape

Even if you never submit, structuring the build this way keeps the harness portable:

```
projects/<name>/project.yaml     # language, sanitizers, fuzzing_engines, maintainer emails
projects/<name>/Dockerfile       # FROM gcr.io/oss-fuzz-base/base-builder; deps; COPY build.sh
projects/<name>/build.sh         # builds the library and each fuzzer into $OUT
```

`build.sh` must honor `$CC`, `$CXX`, `$CFLAGS`, `$CXXFLAGS`, and link fuzzers with `$LIB_FUZZING_ENGINE`. Artifacts go in `$OUT`: the fuzzer binary, `<fuzzer>_seed_corpus.zip`, `<fuzzer>.dict`, and optionally `<fuzzer>.options` containing `[libfuzzer]` settings such as `max_len`. Test locally with `infra/helper.py build_fuzzers --sanitizer address <name>`, `check_build`, `run_fuzzer`, and `reproduce` for a ClusterFuzz testcase.

## Sanitizers

Compile-time instrumentation that turns latent UB into a diagnosed abort. Necessary, cheap, and not sufficient — a sanitizer only reports on code that *executed*, so its value is bounded by the inputs you feed it. Sanitizers plus fuzzing is the productive combination; sanitizers plus a thin unit suite is close to theatre.

| Sanitizer | Detects | Misses | Cost | Notes |
|---|---|---|---|---|
| **ASan** `-fsanitize=address` | heap/stack/global overflow, use-after-free, use-after-return, use-after-scope, double free, invalid free; leaks via LSan | uninitialized reads, integer overflow, races, overflows *within* a struct, anything in a custom pool allocator | ~2x CPU, ~3x RSS | needs `-g -fno-omit-frame-pointer`; `-O1` is the usual build |
| **UBSan** `-fsanitize=undefined` | signed overflow, shift-out-of-range, null/misaligned deref, `bool`/enum with invalid value (Clang), float-cast overflow, div-by-zero, VLA bound, `unreachable` reached | anything not on the checked list; most memory errors | ~20% and up | **defaults to log-and-continue** — see below |
| **MSan** `-fsanitize=memory` | reads of uninitialized memory, incl. uninit values used in branches and passed/returned | everything ASan covers | ~3x CPU | Clang only, Linux mostly; **requires all linked code instrumented**, or you get false positives |
| **TSan** `-fsanitize=thread` | data races, some lock-order and pthread API misuse | races in interleavings that did not occur; races in uninstrumented libraries | 5–15x CPU, 5–10x RSS | needs all threaded code instrumented; `-fPIE -pie` |
| **LSan** `-fsanitize=leak` | leaks only | everything else | near zero | standalone, link-time only; useful in a plain release-ish build |

Compatibility: **ASan + UBSan** and **ASan + LSan** compose (LSan is on inside ASan by default on Linux). **UBSan composes with everything.** **ASan, MSan, and TSan are mutually exclusive** — three separate builds, three separate CI jobs.

### The flags that actually matter

```sh
# The default developer/CI build
clang -g -O1 -fno-omit-frame-pointer \
      -fsanitize=address,undefined -fno-sanitize-recover=undefined ...
```

`-fno-sanitize-recover=undefined` (or `=all`) is the one people forget. By default UBSan **prints a diagnostic and keeps going**, so a CI job full of UBSan reports exits 0 and looks green. Without it, UBSan in CI is decoration. ASan already halts by default.

Useful runtime options (colon-separated in the env var):

```sh
export ASAN_OPTIONS=detect_leaks=1:abort_on_error=1:detect_stack_use_after_return=1:strict_string_checks=1:check_initialization_order=1:allocator_may_return_null=0
export UBSAN_OPTIONS=print_stacktrace=1:halt_on_error=1
export TSAN_OPTIONS=halt_on_error=1:second_deadlock_stack=1
export LSAN_OPTIONS=suppressions=lsan.supp:print_suppressions=0
```

- `detect_leaks=1` is the default on Linux; on Darwin leak detection has historically been off or unsupported, so a macOS-only CI leg does not check leaks. Verify rather than assume.
- `allocator_may_return_null=0` makes a huge allocation an ASan report rather than a `NULL` your code may or may not handle. Setting it to `1` is the right choice for fuzz targets.
- Symbolized stacks need `llvm-symbolizer` on `PATH` or `ASAN_SYMBOLIZER_PATH` set. An unsymbolized report is nearly useless; fix this before debugging anything.

Other flags worth knowing:

- Clang's `-fsanitize=integer` group includes `unsigned-integer-overflow`, `implicit-integer-truncation`, and `implicit-integer-sign-change`. These are **not** undefined behavior — they are suspicious. Enabling them on a codebase full of hashes and checksums produces a flood; enable them selectively and mark the intentional sites with `__attribute__((no_sanitize("unsigned-integer-overflow")))`. GCC has no equivalent.
- GCC's `-fsanitize=bounds` versus Clang's `-fsanitize=array-bounds`: similar intent, different spellings and coverage. GCC also has `-fsanitize=bounds-strict`. Do not assume a flag list ports between compilers; check `-fsanitize=` support per toolchain.
- `-fsanitize-trap=undefined` (Clang, and GCC 12+) replaces the runtime call with a trapping instruction: no runtime library, tiny code growth, no diagnostic message. This is a *hardening* option for production builds, not a debugging one.
- Clang ignorelists: `-fsanitize-ignorelist=file` (formerly `-fsanitize-blacklist=`). Use for third-party code you cannot fix, never for your own code you have not investigated.
- **Custom allocators are invisible to ASan** unless you tell it: `ASAN_POISON_MEMORY_REGION(ptr, size)` / `ASAN_UNPOISON_MEMORY_REGION` from `<sanitizer/asan_interface.h>` around your pool's free/alloc. Without this, a pool allocator silently disables ASan's most valuable checks for everything it manages. The same applies to Valgrind via `VALGRIND_MALLOCLIKE_BLOCK` in `<valgrind/memcheck.h>`.

### MSan's instrumented-libc problem

MSan reports uninitialized reads, which is a class ASan cannot see and which is a common source of nondeterministic C bugs. The cost is that **every** byte of code linked into the process must be MSan-instrumented, or MSan cannot know that a value coming out of it was initialized. In practice: build libc++ (and any dependency) with MSan, or use `-fsanitize-memory-param-retval` behavior in a fully instrumented tree. glibc itself is handled by interceptors, but any third-party `.so` is not.

Cost/benefit: if you cannot build the dependency tree instrumented, use Valgrind memcheck instead. Memcheck finds uninitialized reads on an unmodified binary, at 20–50x slowdown, and with `--track-origins=yes` reports where the uninitialized value came from. What it misses relative to ASan: stack and global buffer overflows (it only has redzones around heap blocks).

```sh
valgrind --error-exitcode=1 --leak-check=full --show-leak-kinds=all \
         --errors-for-leak-kinds=definite,possible --track-origins=yes ./tests
```

### Why passing under sanitizers is not sufficient

- They are dynamic: no execution, no report. Coverage of the *sanitizer build* is the real figure of merit, not whether it passed.
- They check a fixed list. Strict-aliasing violations, most integer truncation, logic errors, protocol violations, and every wrong-answer bug are outside their scope.
- The instrumented build is not the shipped build: different inlining, different layout, different allocator, different timing. Bugs that depend on the release layout will not reproduce, and vice versa.
- ASan's redzones hide small overruns that would corrupt an adjacent object in the real allocator — you get a report instead of corruption, which is the point, but it means the *consequence* in production is untested.

Run the shipped configuration's test suite too, at the shipped optimization level.

## Coverage

Coverage is a tool for finding untested code, not a number to hit. A coverage target creates pressure to write tests that execute lines without asserting anything, which is worse than no test because it is mistaken for one.

### Line, branch, condition, MC/DC

- **Line/statement**: was this line executed. Cheapest, weakest. `if (a && b) return -1;` counts as covered when only the `a == false` path ran.
- **Branch/decision**: was each edge of each decision taken. Detects the untaken `else` and the never-taken error return. This is the minimum useful metric for C.
- **Condition**: was each *sub*-expression evaluated both ways. With short-circuit `&&`/`||` this is meaningfully stronger than branch coverage.
- **MC/DC** (modified condition/decision): each condition independently shown to affect the outcome. Required by DO-178C Level A; expensive elsewhere. Reach for it on genuinely complex boolean logic (permission checks, protocol state guards), not across a codebase.

### GCC / gcov

```sh
gcc --coverage -O0 -g -c foo.c            # == -fprofile-arcs -ftest-coverage
gcc --coverage foo.o test.o -o tests      # .gcno at compile, .gcda at run
./tests
gcov -b -c foo.c                          # branch counts, absolute not percentage
```

For condition coverage, GCC 14 adds `-fcondition-coverage` at compile time and `gcov --conditions` at report time.

Aggregate with `lcov` + `genhtml` or `gcovr`:

```sh
lcov --capture --directory . --output-file cov.info --rc branch_coverage=1
genhtml cov.info --branch-coverage --output-directory cov-html
```

lcov 1.x spells that option `--rc lcov_branch_coverage=1`; lcov 2.x uses `--rc branch_coverage=1`. gcovr's flags likewise shift between major versions — pin the tool version in CI.

### Clang / llvm-cov

```sh
clang -fprofile-instr-generate -fcoverage-mapping -O0 -g foo.c test.c -o tests
LLVM_PROFILE_FILE="prof/%p.profraw" ./tests
llvm-profdata merge -sparse prof/*.profraw -o tests.profdata
llvm-cov report ./tests -instr-profile=tests.profdata
llvm-cov show   ./tests -instr-profile=tests.profdata \
                --show-branches=count --show-line-counts-or-regions foo.c
```

llvm-cov reports **region** coverage, which is finer than line coverage and closer to what you want. `%p` in `LLVM_PROFILE_FILE` expands to the PID, which is required if the test runner forks — otherwise children overwrite each other's profiles. Clang 18+ adds MC/DC: build with `-fcoverage-mcdc` and report with `llvm-cov show --show-mcdc --show-mcdc-summary`.

Export for tooling with `llvm-cov export -format=lcov`.

### Using it correctly

The productive workflow is not "measure percentage" but "list what never ran":

1. Build a coverage build, run the whole suite *including the fuzz corpus replay* and the fault-injection sweep.
2. Open the report filtered to zero-count regions.
3. For each one, answer: is this dead code (delete it), unreachable-by-construction (assert it), or an untested failure path (write the test or add the injection point)?

High line coverage with no failure-path coverage is the standard misleading result. A parser can hit 90% of lines from the happy path while every `goto cleanup` and every `return E_TRUNCATED` sits at zero — and those are precisely the branches with the bugs. Look at the error branches first and the percentage never.

Caveats: coverage builds change inlining and optimization, so timing-dependent and optimization-dependent bugs will not reproduce there; `--coverage` at `-O2` produces confusing attribution, so measure at `-O0`; and coverage of a macro-heavy or `static inline`-heavy header is attributed to the point of use, not the definition.

## Mutation testing

Coverage says a line ran. Mutation testing says the test would have *failed* if the line were wrong. It answers the question coverage cannot: are these assertions load-bearing?

The mechanism: mutate the program (`<` → `<=`, `+` → `-`, delete a statement, negate a condition, replace a return with a constant), rerun the suite, and record whether any test failed. A surviving mutant is a behavior change no test noticed. Surviving mutants in error handling, boundary comparisons, and cleanup code are the ones to act on.

Tooling for C, none of it frictionless:

- **Mull** — LLVM-based, mutates IR, runs mutants in-process for speed. Needs the build to emit bitcode (`-fembed-bitcode` / `-grecord-command-line` depending on version) and a `mull.yml`. The most usable option today.
- **Dextool mutate** — source-level, driven by `compile_commands.json`, supports C and C++, has a persistent database and incremental re-runs. Slower, more configurable.
- **universalmutator** — regex-driven, language-agnostic, trivially set up, produces more invalid mutants; you supply the run/compile loop.

Cost/benefit, honestly: a full mutation run is O(mutants × suite runtime) and produces a long tail of equivalent mutants (semantically identical to the original, unkillable by any test) that must be triaged by hand. It is not a PR gate.

Where it pays: a small, critical, pure module — a checksum, a bounds calculation, an allocation-size computation, a protocol state machine, a comparator. Run it once when the module stabilizes, fix the assertions it exposes, and rerun only after significant change.

The cheap approximation, available in every project, is manual: pick the three most safety-relevant conditions in the diff, break each one deliberately (`<=` to `<`, delete the check), and confirm a *named* test fails. If nothing fails, the test suite does not cover the thing you thought it covered. This takes minutes and catches the same class of gap for the code that matters most.

## Static analysis

Cheap, runs on code that never executes, and finds different bugs than any dynamic tool. Layer it: each tier below finds things the tier above does not.

### Tier 1: the compiler

The first and best static analyzer, because it is already running.

```sh
-Wall -Wextra -Wconversion -Wshadow -Wcast-qual -Wpointer-arith \
-Wstrict-prototypes -Wmissing-prototypes -Wold-style-definition \
-Wwrite-strings -Wundef -Wvla -Wdouble-promotion -Wformat=2 \
-Wnull-dereference -Wswitch-enum -Wimplicit-fallthrough -Walloca -Wcast-align
```

What the important ones actually catch:

- `-Wall` — uninitialized use (only with optimization on, since it needs dataflow), unused variables, `printf` format/argument mismatch, misleading indentation, missing `switch` cases for an enum.
- `-Wextra` — signed/unsigned comparison (a real bug generator), unused parameters, missing struct field initializers, some pointless comparisons.
- `-Wconversion` — implicit narrowing and sign-changing conversions. This is the loudest and the most valuable warning in C: it catches `int` → `size_t` sign changes, `size_t` → `int` truncation, and silent loss in arithmetic. Introducing it on a mature codebase produces hundreds of hits; the discipline is to fix them with explicit, *checked* conversions and to leave a cast only where the range is provably safe.
- `-Wshadow` — a local shadowing an outer local or a global. Almost always a refactoring accident, and lethal inside macros.
- `-Wstrict-prototypes` / `-Wmissing-prototypes` / `-Wold-style-definition` — force real prototypes. `void f()` is not `void f(void)` before C23, and the difference disables argument checking entirely.
- `-Wformat=2` — adds `-Wformat-nonliteral` and `-Wformat-security`, catching non-literal format strings.
- `-Wvla` — flags variable-length arrays, which are an unbounded-stack-allocation primitive.

GCC-only additions worth enabling: `-Wduplicated-cond`, `-Wduplicated-branches`, `-Wlogical-op`, `-Wjump-misses-init`, `-Wtrampolines`.
Clang-only: `-Wthread-safety` (needs `__attribute__((guarded_by(...)))` annotations; documentation is C++-centric but the attributes work in C), `-Wassign-enum`, `-Wcomma`. `-Weverything` is not a production setting, but running it once and reading the output is a productive audit.

`-Werror` belongs in **CI on pinned compiler versions**, not in the default build. A new compiler release invents new warnings, and `-Werror` in a shipped build breaks downstream packagers for no correctness gain. Build with `-Werror` in CI; ship without it.

GCC 10+ also has `-fanalyzer`, an interprocedural symbolic-execution pass finding double-free, use-after-free, leaks, and (GCC 13+) file-descriptor leaks. It is C-focused and improving quickly; its false-positive rate on large codebases is still nontrivial, so introduce it as a non-blocking job first.

### Tier 2: dedicated analyzers

- **Clang Static Analyzer**, via `scan-build make` (or `analyze-build` against `compile_commands.json`). Path-sensitive, symbolic, good at null derefs, leaks, uninitialized use, and API misuse. Default scope is one translation unit; cross-TU analysis exists (`--analyzer-config experimental-enable-naive-ctu-analysis=true`, or via CodeChecker) and is worth the setup for a library split across many files. `--status-bugs` makes it exit nonzero.
- **clang-tidy**, which runs the static analyzer plus its own check families:
  ```sh
  clang-tidy -p build --checks='-*,clang-analyzer-*,bugprone-*,cert-*,misc-*' \
             --warnings-as-errors='clang-analyzer-*' src/*.c
  ```
  Requires a `compile_commands.json` (`-DCMAKE_EXPORT_COMPILE_COMMANDS=ON`, or `bear -- make`). Configure in a checked-in `.clang-tidy`; parallelize with `run-clang-tidy`. Start from a small explicit check list; enabling everything guarantees the tool gets turned off.
- **cppcheck** — different engine, different findings, notably low false-positive rate:
  ```sh
  cppcheck --project=compile_commands.json --enable=warning,style,performance,portability \
           --std=c11 --check-level=exhaustive --error-exitcode=1 --inline-suppr
  ```
  Also ships a MISRA addon if the project has that obligation.
- **Coverity-class tools** — Coverity (`cov-build --dir cov-int make`, free tier for open source), CodeQL, Infer, PVS-Studio. Whole-program, interprocedural, and consistently find things the open tools do not, particularly resource-leak and taint chains crossing many functions. Run on a schedule rather than per-PR; the analysis is slow.

Running two independent analyzers finds materially more than running one twice as often. Their overlap is smaller than you would expect.

### False positives without hiding true positives

- **Triage every finding individually.** Never bulk-suppress to make a new tool green on day one.
- **First ask whether the code is unclear rather than wrong.** A large fraction of analyzer warnings mark places where the invariant is real but invisible. Making it visible — an early return, an explicit bound, a `PROJ_ASSERT` the analyzer can propagate — fixes the warning *and* the readability problem. Assertions are the best false-positive suppressor because they are also a runtime check.
- **When you must suppress, suppress narrowly.** Line-scoped, check-specific, with the reason on the same line:
  ```c
  /* NOLINTNEXTLINE(clang-analyzer-unix.Malloc): ownership transfers to q_push. */
  ```
  `// NOLINT(check)` (clang-tidy), `// cppcheck-suppress checkId` with `--inline-suppr`, `__attribute__((no_sanitize(...)))`, `-Wno-` on a single file via the build system. Never a file-wide or project-wide disable of a check that has ever found a real bug.
- **Baseline instead of suppressing.** For legacy code, record the current finding set and fail CI only on *new* findings. Then burn down the baseline; a baseline that never shrinks is a suppression list with extra steps.
- **Track the count.** Number of suppressions is a reviewable metric. A diff that adds a suppression needs the same scrutiny as a diff that adds a cast.

## Release verification

A release claim is a statement about specific artifacts built from a specific commit with specific tools. Anything else is a guess.

### The matrix

Build and test across the axes that change semantics, not just the ones that are easy:

- **Compiler families**: GCC and Clang at minimum, MSVC if supported. They diverge on warnings, UB exploitation, and extensions; a bug latent under one is often loud under the other.
- **Optimization levels**: `-O0` and `-O2` at least, `-O3`/LTO if shipped. UB that is benign at `-O0` becomes visible at `-O2`. Run the *test suite*, not just the build, at each.
- **`NDEBUG` on and off.** The release build has different code. A suite that only ever runs with assertions on has not tested the shipped binary.
- **Word size**: a 32-bit build (`-m32` or a cross target) catches `size_t`/`int`/pointer-width assumptions that 64-bit hides. Cheap and high-yield.
- **Platforms**: each supported OS and libc. Different `char` signedness, alignment strictness, and filesystem semantics.
- **Feature flags**: every compile-time configuration that ships. Combinatorial explosion is real; test the shipped combinations plus all-on and all-off.
- **Standard**: the declared `-std=` plus `-pedantic-errors`, to catch accidental extension use.

### The gate

Before claiming a release is verified, all of these have run against the release commit:

1. Full matrix builds, warning-clean, `-Werror` on pinned compilers.
2. Full test suite green in every matrix cell, in both debug and release configurations.
3. ASan+UBSan run with `-fno-sanitize-recover`, clean.
4. TSan run if the code is threaded, clean.
5. MSan or Valgrind memcheck run for uninitialized reads, clean.
6. Fault-injection sweeps for allocation and I/O, no leaks, no invalid state.
7. Fuzzing: corpus replay clean in CI, plus a campaign of a documented duration with no new crashes since the previous release.
8. Coverage report reviewed — specifically the untested error branches, not the percentage.
9. Static analysis with no new findings against the baseline.
10. ABI and API check for a library: `abidiff old.so new.so` (libabigail) or abi-compliance-checker; exported symbol list diffed (`nm -D --defined-only --extern-only`); version bump consistent with the compatibility policy.
11. On-disk and wire format compatibility: old artifacts read by the new build, and where the policy requires it, new artifacts read by the old build.
12. The shipped configuration's hardening flags are actually present in the artifact (`-D_FORTIFY_SOURCE`, `-fstack-protector-strong`, RELRO/BIND_NOW, PIE) — verified by inspecting the binary, not by reading the makefile.

### Reproducibility

An artifact you cannot rebuild bit-for-bit is an artifact you cannot audit.

- `SOURCE_DATE_EPOCH` for embedded timestamps.
- `-ffile-prefix-map=$PWD=.` (implies `-fdebug-prefix-map` and `-fmacro-prefix-map`) so build paths do not leak into the binary.
- Deterministic archives (`ar` `D` mode; the default in modern binutils) and a fixed link order.
- Pinned toolchain versions, ideally in a container image referenced by digest.
- Verify by building twice in different directories and comparing with `diffoscope`, not `cmp` alone — you want to know *what* differs.

### What a release claim must state

Record, in the release notes or an artifact beside them:

- exact commit hash and any patches applied;
- toolchain versions (compiler, libc, linker) per matrix cell;
- which configurations were tested and which were only built;
- sanitizer runs performed and their durations;
- fuzzing CPU-hours and corpus size at release;
- static analysis tool versions and the finding delta;
- known unverified areas, explicitly.

That last item is the one that distinguishes a verification report from marketing. Areas nobody tested — a platform without CI, a feature flag combination never exercised, a failure path unreachable by the current injection hooks — are stated as unverified, not omitted. Report unknowns as outstanding verification work rather than implying completion.
