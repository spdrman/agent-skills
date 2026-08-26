# Mojo SIMD, GPU, Layout, and Performance Engineering

## Optimization Order

1. Correct reference implementation.
2. Better algorithm.
3. Remove work.
4. Improve representation/layout.
5. Remove copies/transfers.
6. Vectorize.
7. Tile/cache.
8. Parallelize.
9. Specialize compile-time parameters.
10. Low-level pointer/intrinsic tuning.

Measure each stage.

## Reference Implementation

For numerical/kernels, keep a simple scalar Mojo or trusted Python/NumPy implementation where practical. Use it as a differential oracle.

## SIMD

Choose width by element type, target, and workload. Test 0/valid-empty, 1, width-1, width, width+1, non-multiples, and large cases.

Do not issue a full-width out-of-bounds memory access merely because unused lanes are discarded later unless the specific masked API guarantees the memory behavior.

## Data Layout

Evaluate contiguity, strides, row/column major order, AoS vs SoA, tile shape, alignment, padding, reuse, and vector access. Layout often dominates instruction-level tuning.

## Specialization

Good static parameters: dtype, SIMD width, tile dimensions, layout, algorithm policy, target features. Watch specialization explosion, build time, and code size.

## GPU Indexing

Derive thread/block-to-element mapping explicitly. Prove bounds for every index and guard surplus threads. Use sufficiently wide integers for large tensors.

## Memory Hierarchy

Reason about registers, local/spill memory, shared memory, global memory, caches, and reuse. Optimize based on actual access patterns.

## Coalescing

Where architecture benefits, arrange adjacent threads for efficient adjacent accesses. Do not add expensive transposes/repacking without end-to-end measurement.

## Shared Memory and Barriers

Establish writer/reader ownership of each location. Synchronize before dependent reads. Ensure barrier control flow obeys target semantics and avoid divergence that makes required barriers invalid.

## Race Freedom

Concurrent writes require deliberate reduction/atomic/synchronization semantics. Never assume a race is benign because outputs usually look stable.

## Atomics

Consider supported type, contention, ordering/scope, and hierarchical reduction alternatives.

## Divergence

Preserve correctness first. Optimize branch divergence only after measurement.

## Occupancy

Register/shared-memory usage can constrain occupancy, but occupancy percentage is not the objective—kernel throughput/latency is. Measure.

## Host/Device Transfer

Include transfer in end-to-end performance when application latency includes it. Avoid repeated transfer and keep data resident where beneficial.

## CPU Parallelism

Avoid oversubscription, partition contiguous work, minimize shared writes/false sharing, and choose useful grain size.

## Benchmarking

Record Mojo version, CPU/GPU model, target, shapes, dtype/layout, warmup, iterations, synchronization, transfer inclusion, and compiler settings.

GPU launches are commonly asynchronous; synchronize appropriately before timing completed work.

## Generated Code

When a claim depends on vectorization/specialization, inspect available compiler IR/assembly/diagnostics. Verify expected vector width, tail strategy, and absence of unwanted copies/allocations.

## Numerical Correctness

Define tolerances appropriate to algorithm and dtype. Test NaN, infinity, signed zero where relevant, extreme magnitudes, and cancellation-sensitive inputs. Never loosen tolerance merely to hide a wrong kernel.

## Performance Report

State baseline, change, environment, repeated measurements, correctness comparison, transfer assumptions, and portability tradeoffs. No benchmark means no speedup claim.
