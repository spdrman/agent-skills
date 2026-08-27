# Generic Programming, Concepts, Ranges, and Compile-Time Design

## Generic Programming Goal

Abstract common semantics without losing efficiency.

A generic abstraction should be:
- more general than one concrete type;
- no less clear than specialized versions;
- constrained by meaningful requirements;
- efficient for intended use.

## Concepts

Use concepts to describe requirements at the interface.

Prefer standard concepts.

Create custom concepts when they capture domain semantics.

Bad:

```cpp
template<class T>
requires requires(T x) { x.foo(); }
void use(T);
```

if `foo()` is merely an implementation detail.

Better: define a concept around the actual behavior expected.

## Constraint Placement

Use:
- abbreviated function syntax for simple requirements;
- named concepts for reusable semantics;
- `requires` clauses for compound relationships.

Do not hide important constraints deep in helper templates.

## Concepts Are Not Validation

A concept proves compile-time structural/semantic properties expressible in constraints.

It does not validate runtime values.

Use runtime checks/contracts for value-dependent conditions.

## `auto` Parameters

Abbreviated templates improve readability when requirements are obvious.

Add named concepts when unconstrained `auto` would make API requirements vague.

## Ranges

Prefer range-based interfaces to iterator pairs where practical.

Use views for lazy composition.

Be conscious of:
- borrowed ranges;
- dangling;
- view lifetime;
- single-pass vs forward;
- contiguous vs random-access;
- size availability;
- complexity.

Do not call `.size()` or multi-pass algorithms on ranges that do not guarantee it.

## Algorithms

Prefer algorithms where they communicate intent.

Avoid converting simple readable loops into unreadable 12-stage pipelines.

## Projections

Use range projections to avoid temporary transformations.

Keep projections pure where possible.

## Customization

Prefer established customization mechanisms:
- member where representation/state naturally belongs;
- free function plus ADL when appropriate;
- customization point object pattern for libraries;
- concepts to constrain.

Avoid unconstrained ADL hooks with surprising lookup.

## Templates and ABI

Templates move implementation into headers/modules and instantiate per type.

Costs:
- compile time;
- code size;
- diagnostics;
- ABI exposure.

Hide templates behind non-template implementation where it reduces bloat without sacrificing performance.

## Modules

Use modules when toolchain/build ecosystem supports them.

Benefits can include:
- clearer interfaces;
- compile isolation;
- reduced macro leakage.

Do not force modules into a cross-platform project whose supported build systems/compilers cannot consume them reliably.

## `constexpr` / `consteval`

Use `constexpr` to support both compile-time and runtime evaluation.

Use `consteval` when compile-time evaluation is semantically mandatory.

Examples:
- format/schema validation;
- reflection metadata generation;
- compile-time lookup construction;
- type-level configuration.

Do not use `consteval` merely to move CPU cost from runtime to every build.

## Reflection + Concepts

Use reflection for structural introspection.

Use concepts for semantic contracts.

Example strategy:
- reflect members;
- filter based on annotations/type properties;
- require semantic concepts on reflected member types;
- generate adapters.

## Variadic Templates

Prefer:
- fold expressions;
- pack indexing in C++26;
- expansion statements where appropriate.

Avoid recursive template machinery when modern direct syntax is clearer.

## Pack Indexing

Use named utilities for repeated patterns:

```cpp
template<std::size_t I, class... Ts>
using pack_element_t = Ts...[I];
```

Add bounds/empty-pack constraints where relevant.

## Metafunction Hygiene

Prefer aliases and constexpr values over `::type`/`::value` boilerplate when standard facilities exist.

Prefer normal functions evaluated at compile time over elaborate type-level encodings when values suffice.

## Reflection as the New Metaprogramming Substrate

Before writing:
- X-macros;
- tuple-of-member-pointers;
- manual registration;
- giant type-trait switchboard;

check whether C++26 reflection expresses the problem directly.

But preserve compatibility fallback when toolchain support requires it.

## Template Diagnostics

Improve errors with:
- concepts;
- early `static_assert`;
- named helper concepts;
- small instantiation layers.

Do not expose users to 100-frame SFINAE traces if a direct concept can reject them.

## Compile-Time Performance

Measure:
- clean build time;
- incremental build time;
- peak compiler memory;
- instantiation count;
- binary size.

Metaprogramming cost is real engineering cost.
