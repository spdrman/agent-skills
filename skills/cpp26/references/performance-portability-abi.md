# Performance, Portability, ABI, and Low-Level Engineering

## Zero-Overhead Reasoning

C++ abstractions should be chosen so the compiler can erase abstraction overhead when possible.

Examples:
- `span`;
- ranges;
- templates/concepts;
- RAII wrappers;
- strong value types;
- `unique_ptr`;
- reflection-generated static code.

Verify critical paths rather than relying on ideology.

## Performance Workflow

1. define workload;
2. measure baseline;
3. profile;
4. identify dominant mechanism;
5. change one factor;
6. re-measure;
7. preserve regression benchmark.

## Allocation

Count allocations.

Common hidden allocation sources:
- string concatenation;
- `std::function`;
- `shared_ptr` control blocks;
- containers without reserve;
- polymorphic wrappers;
- coroutine frames;
- formatting;
- reflection-generated static structures may shift cost to binary/build.

Use PMR/arenas only when allocation profile justifies them.

## Locality

Prefer compact contiguous representation for hot traversal.

Consider:
- AoS vs SoA;
- pointer chasing;
- object size;
- padding;
- cache lines;
- false sharing.

Do not add manual alignment/padding without measurement.

## Virtual Dispatch

Virtual calls are often not the bottleneck.

Use runtime polymorphism if semantics require it.

Optimize dispatch only after profiling.

If data locality around the objects is worse than dispatch itself, fix locality first.

## Templates and Code Size

Monomorphization can:
- enable inlining;
- remove branches;
- increase binary size/instruction-cache pressure.

Measure both speed and code size.

Use type erasure/non-template implementation layers where appropriate.

## Exceptions Performance

Do not disable exceptions solely from folklore.

Measure:
- normal-path cost;
- binary-size constraints;
- actual project/platform requirements.

Embedded/realtime systems may have legitimate exception restrictions.

## SIMD

Use C++26 `<simd>` or project abstractions before compiler-specific intrinsics where portable performance suffices.

Retain target-specific intrinsics for measured gaps.

## Branch Prediction

Use likely/unlikely annotations only with stable evidence.

Data layout/algorithmic changes often matter more.

## ABI

Public binary ABI requires discipline.

Avoid exposing:
- STL implementation-sensitive details when cross-toolchain ABI is required;
- private struct layout;
- inline implementation that must remain replaceable;
- reflection-generated layout without version policy.

Use:
- PImpl;
- C ABI facade;
- versioned interfaces;
- symbol visibility;
- opaque handles.

## C++ ABI vs C ABI

C++ ABI depends on:
- compiler family/version;
- standard library;
- flags;
- exception/RTTI mode;
- architecture.

For plugin/FFI boundaries across arbitrary compilers, prefer a C ABI with opaque handles.

## Modules

Modules change build architecture.

Adopt only with:
- supported compiler matrix;
- build-system support;
- dependency scanning support;
- packaging strategy.

Do not mix module and header interface models haphazardly.

## Reflection and ABI

Reflection makes layout/names accessible; that does not make them stable.

Do not serialize:
- offsets;
- declaration order;
- source names;

as external ABI without explicit stable schema.

## Portability

Audit assumptions:

- object model;
- endianness;
- alignment;
- `char` signedness;
- `long` width;
- filesystem;
- case sensitivity;
- path encoding;
- clocks;
- atomics lock-freedom;
- SIMD width;
- floating behavior;
- exception ABI;
- calling convention.

## Cross Compilation

Separate:
- build-host tools;
- target code;
- code generators;
- tests requiring execution.

Do not execute target binaries during build unless emulator configured.

## FFI

Define:
- ownership;
- allocator;
- exception boundary;
- encoding;
- nullability;
- struct layout;
- callback lifetime/thread;
- calling convention.

Never let a C++ exception escape through a C ABI.

## Benchmark Integrity

Use optimized builds.

Prevent benchmark work from being optimized away.

Separate setup from timed region.

Warm caches when that matches production; cold test when that matches production.

Report distributions/repeats.

For sub-microsecond operations use a benchmarking framework with appropriate iteration batching.

## Reflection Compile-Time Performance

For reflection-heavy systems measure:
- compiler wall time;
- peak memory;
- incremental rebuild;
- generated object size;
- number of expansions.

Developer build performance is a product metric.
