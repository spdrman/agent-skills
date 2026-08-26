# Modular Official Guidance — Mojo GPU Fundamentals

> Integrated from Modular's official `mojo-gpu-fundamentals` skill, Apache-2.0. Use together with `mojo-syntax.md`.

## Prime Rule: Mojo GPU Is Not CUDA Syntax

Do not generate:

- `__global__`
- `__device__`
- `__shared__`
- `<<<...>>>`

Mojo kernels are ordinary `def` functions compiled/launched through Mojo/MAX GPU facilities.

Kernel functions generally cannot raise.

## Primary Abstractions

Current official guidance centers GPU work around:

- `DeviceContext` for host-side allocation, copy, launch, synchronization.
- `TileTensor` for typed/layout-aware device data.
- layout constructors such as `row_major`.
- GPU indexing functions such as `global_idx`, `block_idx`, `thread_idx`.
- shared-memory stack allocation.
- explicit barriers and warp primitives.

Verify exact import paths against the pinned toolchain because MAX/Mojo modules evolve.

## Layouts

Static layouts should use compile-time dimensions:

```mojo
comptime layout_1d = row_major[1024]()
comptime layout_2d = row_major[64, 64]()
```

Runtime-known dimensions use current dynamic index/layout constructors such as `Idx`.

Layout rank matters. Derived tensors created by tiling/vectorization/distribution may have a new layout/rank; re-establish any rank assertion needed before multidimensional indexing.

## TileTensor

Use `TileTensor` as the main GPU data abstraction when working with MAX GPU buffers/layouts.

Construct it from a buffer and a layout, letting current constructors infer what they can.

Index according to the tensor's proven rank.

When compile-time type expressions are semantically identical but expressed differently, current guidance uses `rebind[...]` rather than unsafe casting.

## Memory Management

Host-side flow:

1. create `DeviceContext`;
2. allocate device/host buffers;
3. initialize/fill;
4. enqueue copies;
5. wrap buffers as typed/layout-aware tensors where appropriate;
6. launch kernels;
7. map/copy results to host;
8. synchronize where required.

Do not assume launch or copy completion is synchronous.

## Kernel Launch

Use `DeviceContext.enqueue_function[...]` with explicit `grid_dim` and `block_dim`.

When the kernel itself has compile-time parameters, bind the specialized kernel first and pass the bound function to the launch API. Passing an unspecialized parametric name can produce misleading template/DevicePassable errors.

## Indexing

For simple global indexing current guidance uses:

```mojo
var tid = global_idx.x
```

GPU index values are `Int` in current guidance, so bounds comparisons generally need no CUDA-style cast.

Always guard surplus threads unless the static launch contract proves exact coverage.

## Shared Memory

Use current shared-memory stack allocation APIs with the proper shared address space.

After cooperative writes to shared memory, call the appropriate block barrier before dependent reads.

A barrier is a correctness primitive, not a performance hint.

## Warp Operations

Current APIs provide warp reductions, broadcasts, shuffles, and atomics.

Do not guess CUDA intrinsic spellings.

Pay attention to exact argument types; current guidance notes shuffle offsets use `UInt32`.

## GPU Availability and Target Dispatch

Host-side availability checks and device-side architecture dispatch are different concerns.

Use host-side accelerator availability to decide whether GPU code can run.

Use compile-time/device target predicates only inside code that is actually being compiled for the GPU.

Do not make host execution depend on a GPU-only target query.

## Compile-Time Dimensions

Prefer `comptime` for static GPU dimensions, tile sizes, layouts, and block sizes when they truly are static.

This enables specialization and makes bounds/layout invariants inspectable.

Avoid turning runtime shape diversity into an uncontrolled specialization explosion.

## Pointer Use in Kernels

Current GPU guidance favors explicit unsafe-offset operations and modern mutable pointer forms for raw access.

Do not import old `.load()` or bare `ptr[i]` habits when the current API expects explicit unsafe operations.

Use `TileTensor`/safe layout abstractions where they suffice.

## Reductions

For block reductions:

- use compile-time block sizes when required by compile-time loops;
- use shared memory/barriers correctly;
- use warp primitives according to target warp width;
- do not hard-code NVIDIA warp assumptions for AMD/Apple targets.

## Benchmarking

Current official guidance uses standard benchmark types plus MAX's GPU-specific helper for context-aware kernel timing.

GPU launches are asynchronous. A valid benchmark must ensure the measurement corresponds to completed GPU work, not just host enqueue latency.

Record:

- Mojo/MAX version;
- target GPU;
- dtype/layout/shape;
- block/grid size;
- warmup;
- synchronization semantics;
- transfer inclusion/exclusion.

## Cross-Vendor Discipline

Mojo targets NVIDIA, AMD, Apple silicon, and potentially other accelerators.

Do not assume:

- warp size is always 32;
- CUDA address-space rules;
- NVIDIA-only tensor instructions;
- NVIDIA-specific resource limits.

Use target checks and portable abstractions, then specialize only where measured benefit justifies it.

## Kernel Review Gate

Before accepting a kernel, verify:

- every thread index is legal or guarded;
- rank/layout assumptions are proven;
- vector/tile tail access is legal;
- no race exists;
- every shared-memory read happens after required synchronization;
- barriers are reached safely;
- device/host pointers are not confused;
- target-specific code is properly dispatched;
- kernel cannot raise;
- launch specialization matches compile-time parameters;
- results match a trusted CPU/scalar oracle.
