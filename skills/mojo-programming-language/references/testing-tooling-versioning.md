# Mojo Testing, Tooling, Debugging, and Versioning Reference

## Capture Version

Record `mojo --version` for reproducibility. Include it in reports involving syntax, compiler behavior, kernels, or performance.

## Stable vs Nightly

Do not assume nightly features exist in stable. Do not require nightly unless the repository already uses it or the user explicitly accepts that dependency.

## Tests

For current Mojo, `mojo test` has been removed. Use the repository's canonical runner; current Modular guidance uses `TestSuite.discover_tests[...]().run()` in a test file executed with `mojo run`. Older pinned projects may differ. Test value semantics, ownership/moves where observable, lifecycle/destruction, errors, reference/origin APIs, parsing, SIMD tails, CPU/GPU results, dtypes/layouts, and FFI boundaries as relevant.

## Regression Rule

Every reproducible defect should get a regression test when feasible.

## Differential Testing

Compare optimized Mojo against scalar Mojo, Python, NumPy, or another trusted implementation. Generate diverse shapes/values and preserve minimized failures.

## Boundary Shapes

Test zero dimensions where valid, 1, tiny shapes, odd/prime dimensions, tile-1/tile/tile+1, SIMD-width boundaries, non-multiples, and large indexes.

## Dtypes

Test supported integer/sign boundaries, representative floats, NaN/inf, and relevant conversions. Do not test combinations the contract does not support.

## Layouts and Strides

Test contiguous and supported strided/transposed layouts. Do not let optimized code silently assume contiguity unless it is an explicit precondition.

## Error Paths

Test invalid shapes, unsupported dtype/device/layout, malformed input, foreign-call errors, missing Python/environment dependency, and illegal index where APIs expose those failures.

## Unsafe Memory Tests

Test smallest allocations, vector/tail boundaries, alignment-sensitive cases, partial initialization, transfer of ownership, destruction, and allocator pairing. Use external sanitizer/native tooling when integration supports it.

## GPU Tests

Use small correctness cases across required targets. Validate launch bounds, synchronization-sensitive paths, repeated deterministic behavior where promised, reference parity, and device capability checks.

## Debug Method

When compiler errors are unclear:

1. minimize the construct;
2. verify Mojo version;
3. search repository for a working equivalent;
4. consult current docs/changelog;
5. distinguish compiler limitation from program bug.

Do not rewrite large modules based on one uncertain diagnostic.

## Version Migration

For migrations, read changelog across skipped releases, identify removed/deprecated constructs, migrate in coherent groups, and run tests after each group. Benchmark after semantic migration is stable.

Avoid mixing unrelated refactors into a language-version migration.

## Compatibility Report

State original version, target version, syntax/API migrations, semantic changes, actual test results, measured performance changes, and remaining limitations.

## Reproducibility

For kernel/compiler/performance bugs capture Mojo version, OS, architecture, CPU/GPU, driver/runtime if relevant, shape/dtype/layout, invocation, and minimized input.

Never report a tool as passing unless actually run.
