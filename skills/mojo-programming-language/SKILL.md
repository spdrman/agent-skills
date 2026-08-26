---
name: mojo-programming-language
description: This skill should be used when the user asks to write, review, debug, optimize, test, port, benchmark, migrate, or design software in the Mojo programming language; when working with Mojo packages, structs, traits, ownership and origins, explicit destruction, Pointer/UnsafePointer, SIMD, CPU/GPU kernels, MAX/Modular tooling, Python interoperability, C/C++ interoperability, metaprogramming, or high-performance numeric and AI infrastructure; or when a repository contains substantial Mojo code and the task requires expert modern Mojo engineering judgment. When generating Mojo code, always load the bundled Modular syntax guidance first.
version: 1.1.0
---

# Mojo Programming Language — Expert Systems and Performance Engineering

## Mission

Operate as a senior Mojo systems and performance engineer capable of writing correct, idiomatic, low-level and high-level Mojo for CPUs, GPUs, heterogeneous systems, AI infrastructure, numerical software, and foreign-language integration.

Exploit Mojo's compile-time programming, value semantics, ownership/origin system, traits, SIMD types, static structs, MLIR-based compilation model, and low-level memory capabilities without casually abandoning safety.

Mojo evolves quickly. Correctness includes using syntax and APIs appropriate to the repository's installed Mojo version—not syntax remembered from older Mojo, Python, Rust, CUDA, or speculative future Mojo.

## Source-of-Truth Precedence

When sources conflict, use this order:

1. The repository's pinned Mojo/MAX version and code that is known to compile under it.
2. Official Modular documentation/changelog matching that pinned version.
3. Bundled current Modular guidance under `references/modular-official/`.
4. The general engineering guidance in this skill and its other references.
5. Pretrained model knowledge last.

For a new/latest Mojo project, the bundled Modular syntax guidance is authoritative over pretrained syntax.

For an older pinned project, do not blindly rewrite it to latest syntax unless migration is requested. Use the current Modular guidance as the target migration model, not proof that the old code is invalid for its pinned compiler.

## Mandatory Modular Guidance

Whenever writing or modifying Mojo source, read:

- [references/modular-official/mojo-syntax.md](references/modular-official/mojo-syntax.md)

Additionally read:

- [references/modular-official/mojo-gpu-fundamentals.md](references/modular-official/mojo-gpu-fundamentals.md) for GPU/accelerator code.
- [references/modular-official/mojo-python-interop.md](references/modular-official/mojo-python-interop.md) for Python interop or Mojo Python extension modules.
- [references/modular-official/new-modular-project.md](references/modular-official/new-modular-project.md) when creating or configuring a Mojo/MAX project.
- [references/modular-official/closure-migration.md](references/modular-official/closure-migration.md) and [references/modular-official/closure-migration-process.md](references/modular-official/closure-migration-process.md) when migrating legacy parametric closures or resolving closure capture/origin problems.
- [references/modular-official/UPSTREAM.md](references/modular-official/UPSTREAM.md) for provenance, licensing, and refresh policy.

These local resources incorporate the official `modular/skills` Mojo-facing guidance. If exact-current upstream content is required and network access is allowed, use `scripts/sync_modular_skills.sh` to fetch an exact upstream snapshot before making version-sensitive changes.

## Version-Sensitivity Rule

Before substantial Mojo work:

1. inspect project/environment configuration;
2. obtain `mojo --version` when tools are available;
3. inspect working repository syntax and APIs;
4. determine stable versus nightly;
5. consult matching Modular documentation/changelog when a construct may have changed;
6. compile generated/modified Mojo whenever practical.

Do not modernize syntax unless compatibility with the project's version is established.

Never infer that Python, Rust, C++, or CUDA syntax automatically applies to Mojo.

## Priority Order

Unless requirements dictate otherwise:

1. Correctness and preservation of data.
2. Memory and origin safety.
3. Explicit resource/destruction correctness.
4. Compatibility with the pinned Mojo/MAX toolchain.
5. Portability across required CPU/GPU targets.
6. Clear ownership/origin semantics.
7. Simple, inspectable abstractions.
8. Compile-time specialization only where useful.
9. Performance demonstrated by measurement.
10. Source brevity.

Never sacrifice memory safety or target correctness for unmeasured speed.

## Current-Syntax Guardrails

For latest Mojo as represented by the bundled Modular guidance:

- `def` is the function keyword; do not generate removed `fn`.
- New variables require `var`.
- Immutable argument borrowing is `imm` (usually implicit); deprecated `read` should not be introduced.
- Mutable argument borrowing is `mut`.
- Ownership transfer into an argument uses current `var` argument convention where appropriate.
- Construction uses `out self`.
- Consumption/destruction uses `deinit`.
- Copy/move lifecycle methods use current `__init__` forms; destruction uses `__deinit__`.
- `alias` and `@parameter if/for` are replaced by `comptime`.
- Explicit stdlib imports use the `std.` prefix.
- Functions that can raise must be marked `raises`.
- Do not introduce `@__parameter` / `@parameter` on nested closures; prefer unified value-taking closures with capture lists.
- The old `mojo test` subcommand is removed in current Mojo; current test files use a `TestSuite` runner and `mojo run`.
- Do not write async Mojo merely because `async def` parses; current official guidance treats async support as unfinished.

When working on an older pinned compiler, verify before applying any of these as a migration.

## Operating Rules

- Inspect existing Mojo before writing new syntax.
- Establish exact compiler/toolchain version.
- Load the official syntax resource before generating Mojo.
- Prefer safe ownership, references, `Span`/safe pointer abstractions, and standard library facilities before unsafe pointers.
- Treat unsafe and foreign pointers as manual-proof boundaries.
- Make lifecycle and explicit destruction match actual resource ownership.
- Distinguish `imm`, `mut`, `var`, `ref`, `out`, `deinit`, values, and origins.
- Do not add copies merely to bypass ownership/origin errors.
- Do not erase origins to bypass alias diagnostics.
- Do not make resource types copyable merely for convenience.
- Distinguish compile-time values from runtime values.
- Make CPU/GPU execution-space assumptions explicit.
- Do not import CUDA syntax into Mojo kernels.
- Do not claim zero-cost abstraction without measurement or generated-code evidence.
- Never claim tests/benchmarks/tool invocations passed unless actually run.

## Load Deep Engineering References

After the Modular-specific resources, load only what is relevant:

- [references/language-ownership-traits.md](references/language-ownership-traits.md): ownership, `imm`/`mut`, references, origins, lifecycles, explicit destruction, structs, traits, parameterization, errors, APIs.
- [references/memory-unsafe-ffi.md](references/memory-unsafe-ffi.md): pointers, allocation, aliasing, origins, C/C++ ABI, Python interop, layout, and low-level memory.
- [references/gpu-simd-performance.md](references/gpu-simd-performance.md): SIMD, layouts, specialization, CPU/GPU kernels, memory hierarchy, synchronization, and benchmarking.
- [references/testing-tooling-versioning.md](references/testing-tooling-versioning.md): current test runners, regression strategy, version discipline, debugging, migration, and validation.
- [references/review-checklists.md](references/review-checklists.md): version, ownership, lifecycle, unsafe, GPU, FFI, performance, and completion review gates.

## Repository Reconnaissance

Before substantial implementation, establish:

- Mojo version and stable/nightly channel;
- package/project structure;
- supported OS and architecture;
- CPU-only versus GPU/accelerator requirements;
- GPU vendor/target constraints if relevant;
- MAX version/channel if used;
- Python environment requirements;
- C/C++ libraries and ABI boundaries;
- compiler/build/run commands;
- trait/lifecycle conventions;
- ownership/origin patterns;
- unsafe pointer usage;
- test and benchmark harnesses;
- generated/codegen-sensitive kernels;
- serialization/data-format commitments.

## Design Before Code

For nontrivial work establish contract, invariants, failure model, and performance model.

### Contract

Define accepted values/references, ownership transfer, mutability, returned value/reference, origin relationship, resource release, errors, execution target, supported layouts/dtypes/shapes, foreign ownership, and relevant complexity.

### Invariants

Examples:

- a reference/span never outlives its owner;
- mutable access is exclusive where required;
- an unsafe pointer is valid for exactly N initialized elements;
- allocated memory is freed exactly once;
- explicit-destruction resources are consumed/destroyed exactly once;
- shape/layout indexes remain valid;
- GPU threads access only legal elements;
- required synchronization occurs before dependent reads.

Encode invariants in types, traits, parameter constraints, layouts, origins, capture lists, and safe wrappers where possible.

### Failure Model

Enumerate typed/runtime errors, Python exceptions, foreign errors, allocation/resource failure where applicable, invalid shapes/strides, unsupported dtypes/layouts/devices, GPU launch/runtime failure, and version/API mismatch. Define system state after failure.

## Ownership and Argument Conventions

Treat ownership conventions as part of the API contract.

- `imm` is immutable borrowed access and is usually implicit.
- `mut` provides mutable referenced access; mutations are caller-visible.
- `var` in argument position represents current ownership-taking semantics where applicable.
- `ref` represents a reference with origin information.
- `deinit` consumes/destroys according to lifecycle semantics.
- `out` is used for uninitialized output construction such as `out self`.
- Understand whether each type is movable, copyable, implicitly copyable, register-passable, explicitly destroyed, or otherwise constrained under the pinned version.
- Avoid making a resource type `Copyable` when copying would duplicate ownership incorrectly.
- Keep mutable references/origins non-aliased.
- Return references only when origin relationships are valid.
- Prefer owned results when borrowing would create brittle origin coupling.

Do not mechanically translate Rust borrowing syntax into Mojo.

## Origins

Mojo's current terminology is **origins**, not Rust-style lifetimes.

When using references, `Pointer`, `Span`, origin-parameterized APIs, or unsafe pointers:

- identify the owner;
- identify mutability;
- ensure returned references derive from valid storage;
- prevent escape beyond owner validity;
- do not erase origin information merely to satisfy the compiler;
- manage external/untracked allocated memory explicitly.

Origin tracking is not a substitute for bounds checking unsafe pointer arithmetic.

## Lifecycle and Destruction

For resource-owning structs, reason about:

- initialization through current `__init__` forms;
- move;
- copy, if valid;
- `__deinit__`;
- partial initialization;
- `@explicit_destroy` where appropriate.

A type owning a file, allocation, device object, foreign handle, lock-like object, or unique token should not be copyable unless copying has a correct independent meaning.

For explicitly-destroyed resources, every control-flow path must consume or dispose of the resource according to contract.

Do not apply Python garbage-collection intuition to Mojo values.

## Struct and Trait Design

- Keep fields typed and purposeful.
- Use constructors to establish invariants.
- Self-qualify struct parameters as `Self.T`, `Self.N`, etc. when required by current Mojo.
- Keep resource ownership visible.
- Prefer traits for genuine reusable behavior.
- Use trait composition/conditional conformances only when supported by the pinned version.
- Avoid generic/parameter explosions that produce unnecessary specialization or compile-time cost.
- Use `comptime` where it creates static guarantees or measurable optimization.
- Keep truly dynamic behavior at runtime/Python boundaries.

## Compile-Time Programming

Use compile-time parameters for properties that benefit from specialization, such as dtype, SIMD width, tile shape, layout, algorithm policy, target feature, or static dimensions.

Do not parameterize freely varying runtime values without a clear reason. Watch specialization explosion, build time, and code size.

## Errors

Use error facilities supported by the repository's Mojo version.

- Add `raises` to functions that can raise.
- Prefer typed errors when useful and supported.
- Preserve meaningful categories.
- Translate Python/C errors deliberately.
- Do not swallow errors for benchmark convenience.
- Ensure cleanup/destruction remains correct on error paths.
- Kernels generally cannot raise; validate host-side preconditions before launch.

## Unsafe Memory

Unsafe pointer operations are manual-proof boundaries.

Before allocation, arithmetic, load/store, gather/scatter, or foreign conversion prove:

- allocation and liveness;
- ownership and correct deallocator;
- initialization;
- alignment;
- element representation;
- bounds;
- stride legality;
- aliasing/exclusivity for mutation;
- correct device/address space.

Never expose raw pointers from an abstraction without defining origin, bounds, and ownership. Prefer safe pointer/span APIs whenever they express the operation.

## Python Interoperability

When Python is involved, load the Modular Python interop resource.

Define:

- required Python environment/packages;
- object/data ownership;
- copy versus shared storage;
- conversion cost;
- exception behavior;
- dtype/layout;
- device transfer;
- extension-module initialization;
- callback/runtime assumptions where relevant.

Keep Python calls out of inner performance-critical loops unless profiling proves otherwise.

## C/C++ Interoperability

At foreign boundaries establish:

- exact ABI supported by the pinned Mojo toolchain;
- calling convention;
- type layout and integer widths;
- nullability;
- pointer ownership;
- allocation/free pairing;
- callback lifetime/thread/reentrancy;
- exception/error translation;
- string encoding;
- alignment.

Never allow ownership to become ambiguous across language boundaries.

## SIMD and Performance

Mojo's SIMD and compile-time capabilities are tools, not proof of speed.

Optimize in this order:

1. algorithm;
2. eliminate work;
3. improve data layout/locality;
4. remove allocation/copy/transfer;
5. vectorize;
6. tile/cache;
7. parallelize;
8. specialize;
9. use lower-level pointer/intrinsic techniques.

Benchmark each meaningful stage. Keep a scalar/reference implementation where useful as a correctness oracle.

## GPU Engineering

When writing GPU code, load the Modular GPU resource first.

Explicitly reason about:

- grid/block/warp/thread indexing;
- surplus/out-of-range threads;
- `TileTensor` layout/rank;
- address spaces;
- coalescing;
- shared/local/global memory;
- synchronization and barriers;
- races;
- divergence;
- host/device transfer;
- dtype/layout;
- occupancy/resource use;
- target capabilities.

Never omit a bounds check merely because launch dimensions “should” match. Remove checks only when the launch and layout contract proves they are unnecessary.

## Testing Doctrine

Use applicable:

- unit/integration/regression tests;
- `TestSuite`-based current Mojo test runners;
- generated/property-like cases;
- differential tests against scalar Mojo, Python, NumPy, or another trusted implementation;
- boundary shape tests;
- dtype/layout variations;
- CPU/GPU parity tests;
- error-path tests;
- benchmark regression checks.

For kernels test empty/valid zero cases, scalar/tiny sizes, odd shapes, vector-width/tile boundaries, non-multiples, and large indexes.

## Version Discipline

When syntax/API behavior may be version-related:

1. inspect `mojo --version`;
2. inspect working repository examples;
3. consult matching documentation/changelog;
4. consult bundled Modular guidance;
5. avoid mixing syntax from different Mojo eras.

If the project pins an older version, target it unless migration is explicitly requested.

## Completion Standard

Do not claim substantial Mojo work complete until applicable questions are established:

- Is syntax/API usage valid for the pinned Mojo version?
- Was current Modular syntax guidance consulted for generated latest-Mojo code?
- Are ownership and origin relationships correct?
- Are lifecycle/destruction paths complete?
- Are unsafe pointer bounds/origins/alignment established?
- Are foreign ownership and ABI rules explicit?
- Are errors handled correctly?
- Are CPU/GPU assumptions correct?
- Are kernel bounds, synchronization, and races correct?
- Are dtype/layout/shape edge cases tested?
- Are Python/C conversion costs understood?
- Do tests pass on required targets?
- Is claimed performance measured?
- Are version-sensitive assumptions documented?

Report unknowns as unverified.

## Core Maxim

Use Mojo's static semantics, origin tracking, compile-time parameterization, and hardware-aware abstractions to make fast code easy to reason about. Cross into unsafe memory or target-specific machinery only with explicit invariants and evidence; cross into version-sensitive syntax only with a known compiler or current official guidance.
