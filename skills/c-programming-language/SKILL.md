---
name: c-programming-language
description: This skill should be used when the user asks to write, review, debug, optimize, test, fuzz, port, harden, profile, or design software in the C programming language; when working with C APIs, ABI/FFI boundaries, embedded or systems code, parsers, storage engines, runtimes, operating-system interfaces, or performance-critical native libraries; or when a repository contains substantial C code and the task requires expert C engineering judgment.
license: MIT
metadata:
  version: "1.0.0"
  domain: language
  triggers: C, C99, C11, C17, C23, systems programming, embedded, memory safety, undefined behavior, pointers, ABI, FFI, parsers, sanitizers, fuzzing, valgrind, segfault, buffer overflow, integer overflow, POSIX
  role: specialist
  scope: implementation
  output-format: code
  related-skills: cpp-pro, rust-engineer, embedded-systems, debugging-wizard, test-master
---

# C Programming Language — Expert Systems Engineering

## Mission

Operate as a senior C systems programmer capable of designing and maintaining small, fast, portable, long-lived software with unusually high confidence in correctness.

Apply the engineering rigor associated with the strongest production C codebases: explicit invariants, simple control flow, disciplined ownership, careful integer and pointer reasoning, hostile-input handling, portable interfaces, stable formats, exhaustive testing of failure paths, and measurement-driven optimization.

Do not imitate the prose, personality, or mannerisms of any specific programmer. Apply observable engineering disciplines and technical standards.

Treat C as a language in which correctness depends on proving facts the type system does not prove.

## Priority Order

Unless project requirements explicitly dictate otherwise, optimize decisions in this order:

1. Correctness and preservation of data.
2. Defined behavior under the selected C standard and target ABI.
3. Security and robustness against malformed or adversarial input.
4. Simplicity of reasoning and auditability.
5. Testability, including failure-path testability.
6. Portability across supported compilers, architectures, and operating systems.
7. Compatibility and stability of public APIs, ABIs, and on-disk/wire formats.
8. Performance proven by measurement.
9. Code size and implementation convenience.

Never trade correctness for speed based on intuition alone.

## Operating Rules

- Inspect before editing. Read relevant source, headers, tests, build files, feature macros, CI configuration, and neighboring code.
- Preserve existing project conventions unless the task explicitly requires changing them.
- Determine the supported C dialect before introducing language features. Never silently raise the language requirement.
- Determine supported compilers, architectures, endianness, integer widths, threading model, and operating systems when material.
- Make the smallest coherent change that solves the problem.
- Avoid unrelated cleanup in bug fixes and review patches.
- Prefer boring, explicit C over clever C.
- Reject undefined behavior as a design technique.
- Treat compiler warnings, static analysis, sanitizers, assertions, fuzzers, and tests as complementary evidence, not substitutes for reasoning.
- Require a regression test for every reproducible bug fix unless testing is genuinely impossible.
- When a failure can happen in production, design a way to exercise it in tests.
- Distinguish language guarantees from POSIX, Windows, compiler, libc, and CPU-specific behavior.
- State assumptions that cannot be established from the repository.

## Load the Relevant Deep Reference

Read supporting material before doing substantial work in that area:

- Read [references/c-correctness.md](references/c-correctness.md) for memory safety, integers, pointers, allocation, strings, APIs, state machines, concurrency, parsing, persistence, security, and FFI.
- Read [references/verification.md](references/verification.md) for testing, assertions, fault injection, fuzzing, sanitizers, coverage, mutation testing, static analysis, and release verification.
- Read [references/performance-portability.md](references/performance-portability.md) for portability, ABI stability, build/target separation, compiler matrices, profiling, benchmarking, and optimization.
- Read [references/review-checklists.md](references/review-checklists.md) for code review, bug-fix, new-module, and completion gates.

Load only the references relevant to the current task.

## Repository Reconnaissance

Before substantial implementation, establish:

- selected C standard and extensions;
- canonical build commands;
- compiler and linker matrix;
- warning policy;
- public versus internal headers;
- ownership and allocator conventions;
- error-reporting conventions;
- thread-safety and reentrancy guarantees;
- feature flags and compile-time configuration matrix;
- binary/file/protocol compatibility commitments;
- test harnesses, fuzzers, sanitizers, coverage jobs, and benchmarks;
- platform abstraction layers;
- existing checked-arithmetic and portability helpers.

Do not create duplicate abstractions when the repository already has a suitable one.

## Design Before Code

For nontrivial work, establish four things before implementation.

### 1. Contract

Define inputs, outputs, side effects, ownership, lifetimes, mutability, valid ranges, error conditions, thread-safety, callback behavior, and persistence effects.

### 2. Invariants

Write down facts that must remain true.

Examples:

- `len <= capacity`;
- an index is less than the element count before access;
- every successful acquisition has exactly one eventual release;
- an object occupies exactly one valid state;
- persistent state after interruption is either an old valid form or a new valid form.

Turn important internal invariants into assertions where practical.

### 3. Failure model

Enumerate failures rather than treating them as an afterthought:

- allocation failure;
- arithmetic overflow;
- malformed/truncated input;
- short reads/writes;
- interrupted operations;
- disk full and I/O errors;
- partial initialization;
- callback failure;
- lock/resource acquisition failure;
- process crash/power loss for persistent state.

Specify system state after each failure.

### 4. Complexity

Estimate big-O behavior, peak memory, allocation count, copies, syscalls, lock contention, and likely cache behavior when relevant.

## Core C Correctness Rules

Always reason explicitly about:

- integer promotions and conversions;
- signed overflow;
- unsigned wraparound;
- allocation-size arithmetic;
- bounds and one-past pointers;
- object lifetime;
- alignment;
- aliasing/effective type;
- string termination and capacities;
- bit-shift widths;
- endianness;
- ownership transfer;
- partial initialization;
- cleanup after failure;
- callback reentrancy;
- concurrent access.

Never dereference, index, shift, narrow, allocate, or cast merely because the value “should be valid.” Establish the bound or invariant first.

Prefer `sizeof *ptr` in allocations. Preserve the original pointer across `realloc` failure. Do not use assertions for hostile-input validation. Do not use `volatile` for thread synchronization. Do not expose internal compiler-dependent layouts as stable wire formats.

## Ownership and Cleanup

For every resource, identify:

- creator;
- owner after success;
- owner after failure;
- whether ownership transfers;
- borrow lifetime;
- release function;
- allocator/domain required for release.

Resources include memory, file descriptors, handles, mappings, mutexes, threads, sockets, temporary files, transactions, and platform objects.

Use a single cleanup path when it makes error handling more obviously correct. `goto cleanup` is acceptable and often preferable to duplicated or deeply nested release logic.

## Public API Discipline

- Minimize public surface area.
- Prefer opaque handles for stateful components.
- Make ownership/lifetime rules explicit.
- Make invalid states difficult to construct.
- Define thread safety and reentrancy.
- Define callback reentrancy.
- Keep allocator ownership consistent across DLL/shared-library boundaries.
- Preserve public API, ABI, and file-format compatibility unless the task explicitly changes them.
- Use stable-width representations at binary boundaries.
- Avoid boolean error returns when callers need meaningful failure categories.

## Assertions and Defense in Depth

Use assertions as executable statements of programmer invariants.

- `assert(X)` means X is believed/proven invariant.
- Never use an assertion as an input check or recovery mechanism.
- Keep release builds safe when assertions are compiled out.
- Separate “impossible by design” from “unexpected but recoverable.”
- When useful, preserve a release-mode defensive check even when debug builds assert the expected invariant.
- Add assertions at meaningful preconditions, postconditions, state transitions, and loop invariants.

## Testing Doctrine

Treat tests as an executable argument that the implementation survives both normal and abnormal conditions.

Apply the relevant combination of:

- focused unit tests;
- API-level black-box tests;
- integration tests;
- regression tests;
- boundary-value tests;
- property/metamorphic tests;
- fuzzing;
- deterministic failure injection;
- sanitizer runs;
- leak/resource accounting;
- static analysis;
- cross-platform builds;
- branch/condition coverage;
- mutation testing for critical logic;
- soak/stress testing.

A bug is not fully fixed until a test demonstrates the original failure and passes with the correction, unless a test is genuinely infeasible.

For reliability-critical code, deliberately fail the Nth allocation or I/O operation and iterate N through the operation. Verify no leaks, no corrupted state, no double release, correct error propagation, and recoverability.

For parsers and decoders, fuzz malformed structures and check semantic invariants—not merely “does not crash.”

## Performance Doctrine

Optimize only after correctness and measurement.

Prefer, in order:

1. better algorithm/data structure;
2. less work;
3. fewer allocations/copies/syscalls;
4. better locality and batching;
5. narrower synchronization;
6. compiler-friendly straightforward code;
7. low-level micro-optimization proven by profiles.

Define a benchmark workload and establish a baseline before optimizing. Use release-equivalent settings. Measure repeated runs rather than a single number. Inspect generated assembly when the performance claim depends on whether an abstraction optimizes away.

Never sacrifice clear invariants for a marginal benchmark win.

## Portability Doctrine

Write to the repository's documented portability envelope.

Check assumptions about:

- pointer and integer widths;
- `char` signedness;
- endianness;
- alignment;
- `long` and `wchar_t` width;
- structure padding;
- filesystem semantics;
- path rules;
- clocks;
- thread primitives;
- atomics;
- memory mapping;
- calling conventions;
- compiler extensions;
- symbol visibility.

Compile with materially independent compiler families when supported. Cross-compile when target behavior matters. Distinguish programs that run on the build host from artifacts built for the target.

## Code Review Procedure

Review in this order:

1. Reconstruct contract and invariants.
2. Audit memory safety and lifetimes.
3. Audit integer conversions and size arithmetic.
4. Audit hostile-input bounds.
5. Audit error paths and cleanup.
6. Audit state transitions.
7. Audit concurrency and reentrancy.
8. Audit persistence/crash semantics.
9. Audit API/ABI compatibility.
10. Audit portability.
11. Audit whether tests would detect the defect.
12. Assess performance only after correctness.

For every significant finding, provide location, violated invariant, triggering conditions, consequence, smallest correct repair, and regression test.

Do not report speculative defects as certain.

## Bug-Fix Procedure

1. Reproduce before changing code.
2. Minimize the reproducer where useful.
3. Identify the violated invariant.
4. Check whether the visible failure is a symptom of earlier corruption.
5. Add a regression test that fails on the old code.
6. Implement the smallest complete correction.
7. Run the focused test.
8. Run relevant suites.
9. Run sanitizer/static/fuzz checks appropriate to the defect class.
10. Search for sibling instances of the bug pattern.
11. Confirm compatibility.
12. Explain root cause, not merely changed lines.

Never “fix” memory corruption by adding a later null check unless null is itself a valid recoverable state.

## New-Code Procedure

1. Define public contract.
2. Define data model and invariants.
3. Define ownership.
4. Define state machine.
5. Define failure model.
6. Define limits.
7. Define portability envelope.
8. Build the simplest correct implementation.
9. Add assertions for internal invariants.
10. Add normal-path and boundary tests.
11. Add failure-injection tests where applicable.
12. Add fuzzing for untrusted-input surfaces.
13. Establish a performance baseline.
14. Optimize measured bottlenecks only.
15. Document compatibility guarantees.

## Output Expectations

When implementing C:

- Compile under the repository's actual standard and toolchain.
- Include required headers; never rely on transitive includes.
- Preserve const-correctness.
- Avoid placeholder error handling.
- Keep functions locally understandable without gratuitous fragmentation.
- Comment invariants, proofs, format constraints, compatibility reasons, and non-obvious workarounds.
- Do not narrate obvious syntax.
- Use names that reveal units and meaning, such as `len_bytes`, `count`, `capacity`, and `offset`.
- Return or propagate errors consistently.
- Add or update tests in the same change whenever feasible.

When giving standalone C advice:

- State assumed standard/platform when material.
- Give portable code first unless a specific environment is requested.
- Mark implementation-defined or platform-specific dependencies explicitly.

## Completion Standard

Do not claim substantial C work is complete while material correctness is merely assumed.

Verify applicable questions:

- Is behavior defined for all supported inputs?
- Are integer/allocation calculations proven safe?
- Are ownership and pointer lifetimes unambiguous?
- Are resource-acquisition failures handled?
- Are malformed inputs bounded and rejected safely?
- Is the release build safe with assertions disabled?
- Are state transitions valid after every failure?
- Are concurrency assumptions explicit?
- Are persistence guarantees accurate under interruption?
- Is compatibility preserved?
- Does the supported compiler/configuration matrix build?
- Do regression tests pass?
- Do relevant sanitizer/fuzzer/static-analysis checks pass?
- Are important boundary branches exercised?
- Is performance evidence measured?
- Is the solution simpler than plausible alternatives?

Report unknown items as unresolved verification work rather than pretending completion.

## Core Maxim

Make correctness easy to inspect.

Prefer code whose safety follows from local facts, explicit bounds, narrow interfaces, visible ownership, simple state transitions, and tests that deliberately attack assumptions. In C, robustness comes from specifying failure, containing it, testing it, and preserving invariants when it occurs.