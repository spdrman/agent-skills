# Verification, Tooling, Testing, and CI

## Evidence Layers

Use applicable independent evidence:

- compiler warnings;
- clang-tidy/static analysis;
- unit tests;
- integration tests;
- property tests;
- fuzzing;
- sanitizers;
- race detection;
- coverage;
- mutation testing;
- multiple compilers;
- multiple optimization levels;
- benchmark regression;
- ABI checks.

## Warnings

For GCC/Clang begin with a strong project-compatible baseline:

```text
-Wall -Wextra -Wpedantic
```

Consider additional warnings deliberately:
- conversion/sign;
- shadowing;
- old-style casts;
- non-virtual destructor;
- overloaded virtual;
- null dereference;
- format issues.

Do not enable noisy warnings without a policy to keep signal high.

MSVC builds should use an equivalently curated warning level.

## `-Werror`

Useful in CI with a stable curated warning set.

Be cautious across compiler upgrades and external headers.

## clang-tidy

Use profiles relevant to project:
- bugprone;
- performance;
- modernize;
- cppcoreguidelines;
- readability selectively.

Do not apply all modernize fixes blindly.

## Sanitizers

Use:
- ASan;
- UBSan;
- TSan;
- MSan where supported;
- leak detection.

Sanitizers are mandatory evidence for low-level pointer/lifetime code where supported.

## Fuzzing

Fuzz:
- parsers;
- protocol decoders;
- reflection-based serializers;
- binary formats;
- state machines;
- public APIs with hostile inputs.

Preserve minimized crashes as regression tests.

## Property Tests

Useful properties:
- encode/decode round-trip;
- sort ordering/permutation;
- parser normalization idempotence;
- reflection-generated adapter equivalence with manual oracle;
- serialization backward compatibility.

## Contract Testing

Do not only test happy contract conditions.

Test:
- boundary preconditions;
- postconditions;
- violation handler/build modes if part of system;
- release configuration semantics.

Do not assert a security guarantee based solely on a debug-only contract mode.

## Reflection Testing

Compile reflection code across every supported reflection compiler.

Reflection is a compiler-front-end-heavy feature; cross-compiler testing matters.

Test generated behavior and compilation diagnostics.

## ABI Testing

For stable libraries:
- compare exported symbols;
- run old consumer against new library where supported;
- use ABI checker tools;
- keep serialized protocol golden files.

## Compiler Matrix

At minimum for portable libraries, use two independent major compiler families where practical.

C++26 features may require a dedicated experimental/latest job in addition to mainstream compatibility jobs.

## Feature Matrix

Test:
- C++26-enabled path;
- fallback path;
- optional feature combinations;
- exception/no-exception if supported;
- RTTI/no-RTTI if supported;
- hardened library mode where relevant.

## Coverage

Use branch/condition coverage to find untested decisions.

Do not delete meaningful defensive code just to reach 100%.

## Mutation Testing

Use on critical:
- validation;
- state transitions;
- arithmetic;
- serialization;
- security checks.

Surviving mutations reveal weak tests.

## Benchmarks

Benchmark separately from correctness tests.

Store baselines and flag material regressions.

Do not make CI fail on tiny noisy changes without statistical discipline.

## Reproducibility

Record:
- compiler version;
- standard library;
- flags;
- standard mode;
- CPU;
- OS;
- feature macros;
- test seed;
- sanitizer config.

## Verification Report

When reporting completion state only what actually ran.

Never say:
- "all tests pass";
- "no leaks";
- "faster";
- "supported on GCC/Clang/MSVC";

unless verified.
