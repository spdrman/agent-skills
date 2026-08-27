# C++26 Language and Library Engineering Reference

## Purpose

Use this reference when writing or reviewing code intended to take advantage of C++26.

The primary rule is: **standardized does not mean implemented everywhere**.

Always check the actual compiler and standard-library pair.

## C++26 Adoption Strategy

Classify each C++26 dependency:

### Tier A — Semantic improvement with low ecosystem risk

Examples:
- pack indexing;
- constexpr improvements;
- structured binding improvements;
- library additions implemented by target vendors.

Use directly if every supported toolchain implements them.

### Tier B — Library facility with fallback

Examples:
- `std::inplace_vector`;
- `std::hive`;
- `std::simd`;
- newer algorithms/utilities.

Prefer an adapter/compatibility layer when older toolchains remain supported.

### Tier C — Transformative feature with uneven support

Examples:
- reflection;
- contracts;
- C++26 execution control.

Isolate behind modules/components and gate using feature-test macros and compile probes.

## Feature-Test Discipline

Do not detect capabilities using compiler version alone when a standardized feature macro exists.

Examples include:

```cpp
#ifdef __cpp_pack_indexing
#endif

#ifdef __cpp_contracts
#endif

#if defined(__cpp_impl_reflection) && __cpp_impl_reflection >= 202506L
#endif

#if defined(__cpp_lib_reflection) && __cpp_lib_reflection >= 202506L
#endif
```

For library features include `<version>` where appropriate.

A feature macro proves claimed implementation support, not semantic correctness of your code. Still test each supported compiler.

## Reflection

C++26 reflection is covered in depth in `reflection-metaprogramming.md`.

Treat it as a major new metaprogramming substrate, not as RTTI.

It is compile-time reflection using:

- `^^`;
- `std::meta::info`;
- `<meta>`;
- splicing;
- compile-time expansion.

Avoid confusing it with old Reflection TS syntax (`reflexpr`, old metaobject concepts) or compiler extensions.

## Contracts

C++26 introduces language contracts.

Core forms:

```cpp
int divide(int a, int b)
    pre (b != 0)
{
    return a / b;
}
```

Postconditions and internal contract assertions are also supported in the language model.

Engineering rules:

- keep predicates side-effect free;
- express programmer/API conditions, not parsing logic for hostile data;
- do not duplicate expensive calculations solely for contract predicates;
- avoid predicates that depend on mutable global state;
- understand configured evaluation semantics;
- do not assume every build enforces every contract;
- use ordinary runtime error handling when enforcement is semantically required.

Contracts improve specification and diagnostics. They are not a magic replacement for defensive validation.

## Standard Library Hardening

C++26 adds standardized hardening concepts for selected library preconditions, especially important bounds and invalid-state operations.

Engineering policy:

- enable hardened library mode in security-sensitive production profiles when your standard library supports it and overhead is acceptable;
- test the actual implementation mode;
- do not depend on hardening as the only correctness mechanism;
- prefer APIs that naturally carry sizes and bounds (`span`, containers, ranges);
- retain sanitizers in test/CI builds.

Hardening is defense in depth.

## Erroneous Behavior for Uninitialized Automatic Values

C++26 changes many reads of uninitialized automatic-storage values from UB to **erroneous behavior** rather than making them correct.

Do not exploit this distinction.

Policy:

- initialize all variables before semantic use;
- use `[[indeterminate]]` only for carefully audited low-level needs;
- do not treat "no longer UB" as "safe";
- keep compiler warnings for uninitialized data enabled.

## Pack Indexing

C++26 pack indexing:

```cpp
template<class... Ts>
using last_t = Ts...[sizeof...(Ts) - 1];
```

Use it to simplify pack element access where it reduces recursive metaprogramming or index-sequence ceremony.

Rules:

- ensure index is a constant expression and in range;
- retain concepts/static assertions for empty-pack cases;
- prefer semantic named utilities over clever inline indexing repeated everywhere.

## Expansion Statements

C++26 `template for` supports compile-time expansion over suitable structures/ranges and pairs naturally with reflection.

Conceptual use:

```cpp
template for (constexpr auto member : members) {
    // one instantiated copy per element
}
```

Treat it as code generation, not a runtime loop.

Review:

- compile-time complexity;
- generated code volume;
- capture/use semantics;
- whether all expanded statements should really be distinct instantiations;
- diagnostics across large reflected sets.

## `constexpr` Expansion

C++26 continues the trend of moving more language/library behavior into constant evaluation.

Use `constexpr` when:

- values truly can be known at compile time;
- it creates an invariant or removes runtime setup;
- the same implementation usefully supports runtime inputs too.

Avoid turning normal runtime logic into forced compile-time work merely for novelty.

Watch build-time and memory cost.

## `std::inplace_vector`

`std::inplace_vector<T,N>` is a fixed-capacity, dynamically sized, contiguous container with storage inside the object.

Use when:

- capacity has a meaningful static upper bound;
- allocation avoidance matters;
- contiguous storage matters;
- stack/object-size impact is acceptable.

Review:

- object size (`N * sizeof(T)` scale);
- copy/move cost;
- stack usage;
- failure behavior when capacity is exceeded;
- whether a small-vector optimization or `std::vector` is actually better.

Do not choose it solely to "avoid heap" without measuring.

## `std::hive`

`std::hive` is designed for stable element locations and efficient insertion/erasure through block-based storage/reuse.

Use when:

- erase/insert churn is high;
- stable references/iterators are valuable according to its guarantees;
- contiguous iteration is not required.

Do not use when vector-like locality or random indexing dominates.

## `<simd>`

C++26 standard SIMD facilities provide portable data-parallel vector/mask abstractions.

Use explicit SIMD only after:

1. algorithm is correct;
2. scalar implementation is measured;
3. compiler auto-vectorization is inspected;
4. data layout is suitable.

Keep:
- tail handling correct;
- alignment assumptions explicit;
- a portable fallback when target coverage requires it.

## Execution Control Library

C++26 execution control introduces sender/receiver-style asynchronous composition.

Use when:

- the system genuinely needs composable async execution;
- the implementation/toolchain supports required facilities;
- cancellation and execution-resource abstraction matter.

Do not wrap trivial synchronous APIs in sender machinery.

Define:
- scheduler/executor ownership;
- stop/cancellation propagation;
- completion channels;
- lifetime of captured state;
- exception/error mapping;
- shutdown.

## Hazard Pointers and RCU

C++26 includes standard facilities for advanced reclamation patterns.

Use only when:
- lock-free/read-mostly architecture is justified;
- ordinary locks/shared ownership are insufficient;
- reclamation invariants are understood;
- stress/model tests exist.

A standard hazard-pointer type does not make a flawed lock-free algorithm correct.

## `<linalg>`

Use standardized linear algebra facilities where they fit, especially to express mathematical intent separately from storage implementation.

Still reason about:
- layouts;
- aliasing;
- execution policy/backend;
- numerical stability;
- allocation and temporaries.

## `<text_encoding>`

When text encoding is relevant, distinguish:
- bytes;
- code units;
- Unicode scalar values;
- grapheme clusters;
- external encodings.

Do not treat `std::string` as "Unicode characters."

## Freestanding Evolution

C++26 expands freestanding support.

For embedded/kernel/runtime work:
- know exactly which library components are available for target;
- do not assume hosted I/O, filesystem, locale, exceptions, or threading;
- separate freestanding core from hosted adapters.

## C++26 Code Review Questions

- Is the feature actually implemented on all required toolchains?
- Is a feature-test macro used where appropriate?
- Is this new facility simpler than the C++20/23 alternative?
- Does it increase compile time/code size materially?
- Does it affect ABI?
- Does it require a fallback?
- Is it isolated enough to remove/work around if vendor support is incomplete?
