# Rust Performance, Concurrency, Portability, and Build Reference

## Measure First

Define workload, release profile, hardware, target, inputs, concurrency, and warm/cold state. Measure repeated runs.

Track relevant latency, throughput, CPU time, allocations, bytes, RSS, syscalls, contention, queue depth, cache behavior, code size, and compile time.

## Allocation and Cloning

Count allocations before optimizing. Common sources: `clone`, `to_owned`, `format!`, intermediate `collect`, boxing, vector growth, and conversion among owned string/buffer forms.

Distinguish cheap refcount clones from deep clones. Never remove clones by introducing unsound aliasing.

## Data Layout

Consider struct size/alignment, enum niches, hot/cold fields, indirection, AoS vs SoA, and false sharing. Measure before adding layout complexity.

## Iterators and Bounds Checks

Choose the clearest implementation first. If a hot path depends on iterator lowering or bounds-check elimination, inspect generated code or benchmark it. Do not introduce `get_unchecked` for suspected bounds-check cost without proof and measurement.

## Concurrency Performance

Measure contention. Prefer less shared mutation, ownership transfer, sharding, batching, shorter lock duration, immutable snapshots, and per-thread structures where appropriate. Lock-free is not automatically faster or better.

## Async Performance

Watch blocking executor threads, tiny/excess tasks, unbounded queues, boxed futures, allocation per operation, wake storms, and shared-state contention. Preserve backpressure.

## SIMD

First establish scalar baseline and inspect auto-vectorization. For explicit SIMD/intrinsics, define feature detection/dispatch and a portable fallback. Never execute unsupported instructions.

## `no_std`

Distinguish `core`, `alloc`, and `std`. Keep allocator and panic assumptions explicit. Test the intended target and prevent accidental std-only dependency features.

## Cross Compilation

Build scripts and proc macros execute on the host. Keep host capability probes separate from target capability decisions. Do not attempt to run target artifacts during build without deliberate emulation/runtime support.

## `build.rs`

Keep build scripts deterministic, minimal, cross-compile aware, and precise about rerun triggers. Avoid network access during normal builds.

## Native Linking

Define static/dynamic linkage, search paths, target libs, symbol visibility, CRT/runtime expectations, and distribution/license implications.

## Stable ABI

Rust native layout/ABI is generally not a stable foreign contract. Use the required `extern` ABI, FFI-safe types, `repr(C)`/transparent where appropriate, opaque handles, explicit ownership, and versioned structs/protocols.

## Benchmark Integrity

Use optimized builds, ensure work is not eliminated, separate setup from timing, validate outputs, run repeatedly, and avoid claiming tiny noisy percentage wins.

## Optimization Report

State baseline, profile evidence, change, benchmark method, repeated results, correctness verification, and tradeoffs. No measured data means no performance claim.
