# Sutter + Stroustrup Engineering Principles

## Purpose

This reference distills recurring engineering principles from the C++ Core Guidelines and published work by Herb Sutter and Bjarne Stroustrup.

It is not a style imitation and is not a verbatim copy of their writing.

## 1. Express Intent Directly

Write code in the vocabulary of the problem.

Prefer:

```cpp
Deadline deadline;
ByteCount bytes;
AccountId account;
```

over primitive values plus comments.

A good abstraction should make the correct use obvious and misuse difficult.

## 2. Interfaces Are the Main Design Boundary

Spend disproportionate effort on interfaces.

A strong interface should reveal:

- ownership;
- mutability;
- valid states;
- failure;
- complexity where surprising;
- concurrency;
- lifetime.

Minimize the amount callers must remember.

Avoid APIs that require "call A, then set three flags, then maybe call B."

Use construction, types, and RAII to encode sequence/invariant where practical.

## 3. Strong Typing

Avoid:
- integer flags;
- stringly typed APIs;
- unrelated values using the same primitive type;
- ambiguous booleans.

Prefer enums, newtypes/value classes, concepts, and overloads that express meaning.

## 4. RAII Everywhere

Do not manually pair acquisition/release in normal control flow.

Acquisition should establish an owning object.

Destruction should release.

This applies beyond memory.

A resource leak is generally an abstraction failure.

## 5. Rule of Zero

Application/domain classes should normally need no custom destructor/copy/move members.

Push ownership details into RAII members.

If special members are required, inspect all five relevant operations and declare/delete/default intentionally.

## 6. Values Over Pointers

Use values when identity is not required.

Benefits:

- clear ownership;
- local lifetime;
- simple copying/moving;
- fewer allocation paths;
- better locality;
- easier testing.

Do not heap-allocate polymorphism-free objects by habit.

## 7. Unique Ownership by Default

If heap ownership is required, begin with `std::unique_ptr`.

Use `std::shared_ptr` only when the domain truly has shared lifetime.

Shared ownership is an architectural decision with:
- atomic/refcount cost;
- hidden lifetime extension;
- cycle risk;
- less deterministic destruction.

Never use `shared_ptr` as a substitute for deciding ownership.

## 8. Raw Pointers Are Views

Treat raw pointers/references as non-owning unless explicitly in a low-level ownership abstraction.

Prefer:
- `T&` for required object;
- `T*` for optional borrow;
- `span` for borrowed arrays;
- `string_view` for borrowed strings.

Do not use pointer arithmetic as a general application-level iteration mechanism.

## 9. Prefer Return Values

Prefer:

```cpp
Result compute();
```

over output parameters.

Return values:
- compose;
- express ownership;
- benefit from RVO/move;
- reduce aliasing;
- simplify exception safety.

Use output parameters only with a specific semantic or performance reason.

## 10. Move Semantics Should Mostly Be Invisible

Design movable RAII/value types.

Let return statements and standard containers use move automatically.

Use `std::move` when transferring from a named object that is no longer needed.

Do not sprinkle `std::move`:
- on return locals where it may inhibit optimization;
- on const objects;
- on values still needed.

## 11. Almost Always `auto` — With Judgment

Use `auto` to eliminate redundant type spelling.

Especially useful for:
- iterators;
- lambdas;
- reflection values;
- structured bindings;
- dependent/generic return types.

Use explicit type when it communicates:
- units;
- narrowing;
- ownership;
- ABI;
- signedness;
- important domain meaning.

Readability is the criterion.

## 12. `const` Is Interface Information

Make observers `const`.

Use `const` references for non-mutating borrows.

Do not return const-by-value.

Do not use const in ways that block useful moves without benefit.

## 13. Prefer Algorithms Over Hand-Written Loops

Use algorithms/ranges when they state intent better:

- transform;
- find;
- sort;
- partition;
- accumulate/fold;
- copy/filter.

A named algorithm communicates what rather than control mechanics.

Keep loops when the algorithm form is less clear.

## 14. Prefer Library Facilities Over Custom Mechanisms

The standard library should be the default toolbox.

Before writing:
- custom optional;
- custom variant;
- custom smart pointer;
- raw dynamic array;
- thread pool;
- homemade synchronization primitive;
- manual formatting;
- hand-written SIMD wrapper;

check whether the standard or established project library already solves it.

## 15. Generic Programming Is About Requirements

A template should express an algorithm over a family of types that meet meaningful requirements.

Concepts should describe semantics, not implementation trivia.

Bad:
- "has method named x"

Better:
- "behaves as sortable range / contiguous buffer / serializer"

## 16. Zero-Overhead Principle

Use high-level abstractions that compile to efficient code.

But "zero overhead" must be verified when performance matters.

Inspect:
- assembly/IR;
- allocations;
- code size;
- branch count;
- benchmark output.

Do not assume either:
- abstraction is free, or
- abstraction is slow.

## 17. Type Safety Before Casts

Prefer conversions and type design that make casts unnecessary.

If casting is unavoidable:
- use the narrowest cast;
- isolate it;
- explain invariant;
- test it.

Treat `reinterpret_cast` as a low-level boundary marker.

Avoid C-style casts.

## 18. Prefer Initialization

Initialize objects when created.

Prefer braces when they prevent narrowing and remain unambiguous.

Avoid "construct invalid, then call init."

If an object cannot be valid yet, represent that state explicitly.

## 19. Error Handling Is Part of the Interface

Use:
- exceptions for failure to fulfill a required operation when project policy is exception-oriented;
- `expected` for explicit recoverable outcome APIs;
- `optional` for absence that is not an error.

Do not encode errors in magic values.

## 20. Destructors Do Not Fail Publicly

Destructors must not throw.

If cleanup can fail meaningfully:
- provide explicit `close`, `commit`, `flush`, or similar;
- let destructor perform best-effort fallback.

## 21. Prefer Nonmember Functions When Representation Is Not Needed

A function that does not require private representation access need not be a member.

This reduces class coupling and public member surface.

Use free functions, algorithms, and customization points when they fit naturally.

## 22. Polymorphism Is a Semantic Choice

Use dynamic polymorphism when runtime substitutability and identity are required.

Use templates/concepts for compile-time polymorphism when:
- types are known;
- performance/inlining matters;
- semantic genericity is natural.

Do not make every hierarchy virtual.

## 23. Base-Class Destruction Must Be Intentional

For polymorphic deletion:
- public virtual destructor.

For non-deletable-through-base interfaces:
- protected non-virtual destructor can express that contract.

Avoid ambiguous ownership of polymorphic objects.

## 24. Keep Inheritance Shallow

Prefer composition to inheritance for code reuse.

Use inheritance for true substitutability or implementation mechanisms with clear invariants.

Avoid fragile deep hierarchies.

## 25. Encapsulate Messy Code

Hardware access, ABI tricks, pointer arithmetic, OS APIs, and legacy C interfaces may be necessary.

Put them behind narrow typed wrappers.

The rest of the program should not need to know the trick.

## 26. Prefer Compile-Time Checking

Use:
- strong types;
- concepts;
- `constexpr`;
- reflection;
- static assertions;
- compiler warnings;
- modules/interface boundaries.

If something cannot be proven at compile time, check it early at runtime.

## 27. Do Not Optimize Prematurely

First:
- correct algorithm;
- clear design;
- measured workload.

Then optimize the bottleneck.

Retain the simplest interface even if the implementation becomes sophisticated.

## 28. Compatibility Is a Feature

For libraries:
- respect ABI;
- respect API;
- version serialized formats;
- avoid exposing private representation;
- use PImpl/modules/opaque handles when appropriate.

A cleaner implementation is not automatically worth breaking users.

## 29. Avoid Global Mutable State

Global mutable state damages:
- testability;
- concurrency;
- initialization order;
- lifetime reasoning.

Prefer dependency injection, explicit owners, immutable global constants, or localized state.

## 30. Keep Unsafe Code Greppable

Low-level escape hatches should stand out:

- raw owning allocation;
- `reinterpret_cast`;
- `const_cast`;
- manual lifetime;
- atomics;
- inline assembly;
- FFI;
- unchecked indexing.

Centralize and document them.

## 31. Profiles and Safety Direction

Modern C++ safety work follows a "safer subset over compatible superset" direction:

- strengthen the library;
- restrict known-dangerous idioms;
- make opt-outs explicit;
- preserve performance/control for low-level code.

Even where standardized profiles are not available on a toolchain, emulate the spirit:
- safe defaults;
- explicit suppressions;
- narrow unsafe regions;
- automated enforcement.

## 32. Contemporary C++ Is Not 1990s C++

Do not write new C++ as:
- pervasive raw arrays;
- owning raw pointers;
- macro metaprogramming;
- manual resource cleanup;
- deep inheritance;
- unconstrained templates;
- C-style casts;
- global mutable singletons.

Use the language/library generation actually available to the project.
