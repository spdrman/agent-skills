# Rust Verification and Tooling Reference

## Test Layers

Use applicable unit tests, integration tests, doctests, regression tests, property tests, fuzzing, compile-fail/UI tests, concurrency model tests, Miri, sanitizers, target tests, coverage, mutation testing, and benchmarks.

## Regression Rule

Every reproducible bug should become a permanent regression test when practical. Test the root behavior, not merely one crash message.

## Property Testing

Useful properties include encode/decode round-trips, parse/format round-trips, idempotence, ordering laws, equivalence to a reference implementation, state-machine invariants, and conservation/counting rules. Preserve minimized failures.

## Fuzzing

Fuzz parsers, protocol decoders, serializers, safe wrappers around unsafe internals, state machines, file formats, and collection operation sequences. Use structured generators where raw bytes rarely reach meaningful states.

“No panic” is not enough; add semantic oracles.

## Miri

Use Miri especially for raw pointers, aliasing, uninitialized memory, invalid values, custom collections, and unsafe abstraction internals. Miri does not model all FFI/platform behavior, so target testing still matters.

## Sanitizers

Use supported Address/Memory/Thread/UB sanitizer configurations as appropriate, including native dependencies. Understand target/toolchain limitations.

## Loom

Use Loom or equivalent model checking for compact concurrent primitives involving atomics, publication, wakeups, lock-free transitions, and shutdown races. Keep the modeled state space small enough to explore.

## Compile-Fail / UI Tests

Use when API correctness includes “this misuse must fail to compile,” particularly proc macros, lifetimes, typestate, derives, and diagnostic behavior.

## Clippy and Lints

Use a curated policy. Treat lints as review assistants, not authorities. High-value checks often include ignored must-use values, unsafe-related issues, suspicious casts, and missing safety docs. Do not contort correct code for stylistic lints.

## Coverage

Use coverage to find behavior without evidence. Prioritize branch/semantic coverage over raw line percentage for critical code.

## Mutation Testing

Useful for critical logic. Pay attention to surviving mutations in comparisons, bounds, error handling, arithmetic, parser acceptance, and state transitions.

## CI Matrix

Consider MSRV, current stable, important targets, default features, no-default features, key feature combinations, docs, examples, and unsafe-specific validation jobs.

## Reproducibility

For fuzz/concurrency failures preserve compiler version, target, feature set, seed, minimized input, and relevant environment.

## Verification Report

Report only commands actually run, toolchain/target/features used, tests added, Miri/sanitizer/fuzzer/model-check results, and measured benchmark/coverage data. Never invent passing execution.
