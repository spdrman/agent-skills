# Sources and Provenance

This package is an original engineering synthesis informed by the following public sources. It does not reproduce their text wholesale.

## C++ Core Guidelines

Editors:
- Bjarne Stroustrup
- Herb Sutter

URL:
https://isocpp.github.io/CppCoreGuidelines/CppCoreGuidelines.html

Used for:
- interface design;
- RAII;
- ownership;
- resource safety;
- class design;
- generic programming;
- concurrency;
- safety and style principles.

## Bjarne Stroustrup — 21st Century C++

URL:
https://stroustrup.com/21st-Century-C%2B%2B.pdf

Used for:
- contemporary C++ direction;
- resource/lifetime management;
- type safety;
- modularity;
- generic programming;
- profiles/guidelines direction.

## Bjarne Stroustrup — Concept-Based Generic Programming

URL:
https://www.stroustrup.com/Concept-based-GP.pdf

Used for:
- concepts as semantic constraints;
- efficient generic abstractions;
- zero-overhead generic programming;
- relationship of C++26 reflection to generic programming.

## Herb Sutter — Sutter's Mill / C++26 reports

URL:
https://herbsutter.com/

Used for:
- reflection as a major C++26 metaprogramming transition;
- contracts usage perspective;
- safety/hardening direction;
- zero-overhead and adoptability principles.

## WG21 P2996R13 — Reflection for C++26

URL:
https://www9.open-std.org/JTC1/SC22/WG21/docs/papers/2025/p2996r13.html

Used for:
- C++26 static reflection design;
- reflection values;
- splicing;
- queries;
- generation.

## cppreference — Reflection Library

URL:
https://en.cppreference.com/cpp/meta/reflection

Used for:
- current `<meta>` facility inventory;
- `std::meta::info`;
- member/layout/annotation queries;
- feature-test macros.

## cppreference — Reflection Operator

URL:
https://en.cppreference.com/cpp/language/operator_reflection

Used for:
- `^^` syntax.

## cppreference — Splice Specifiers

URL:
https://en.cppreference.com/cpp/language/splice_specifiers

Used for:
- `[: ... :]` syntax and contexts.

## WG21 P1306R5 — Expansion Statements

URL:
https://www.open-std.org/jtc1/sc22/wg21/docs/papers/2025/p1306r5.html

Used for:
- `template for`;
- reflection-oriented compile-time expansion.

## cppreference — C++26 Compiler Support

URL:
https://en.cppreference.com/cpp/compiler_support/26

Used for:
- requirement to verify actual compiler support;
- contracts/reflection implementation status.

## cppreference — C++26 Contracts

URLs:
https://en.cppreference.com/cpp/language/contracts
https://en.cppreference.com/cpp/contract.html

Used for:
- `pre`, `post`, `contract_assert`;
- contract support library;
- evaluation/violation concepts.

## WG21 P3471 — Standard Library Hardening

URL:
https://www.open-std.org/jtc1/sc22/wg21/docs/papers/2025/p3471r4.html

Used for:
- hardened preconditions;
- bounds-safety defense in depth.

## cppreference — Default Initialization / Erroneous Values

URL:
https://en.cppreference.com/cpp/language/default_initialization

Used for:
- C++26 erroneous behavior treatment of many uninitialized automatic values.

## cppreference — Pack Indexing

URL:
https://en.cppreference.com/cpp/language/pack_indexing

Used for:
- C++26 `Ts...[I]` syntax.

## cppreference — C++26 Library Features

URLs:
https://en.cppreference.com/cpp/26
https://en.cppreference.com/cpp/container/inplace_vector
https://en.cppreference.com/cpp/container/hive
https://en.cppreference.com/cpp/header/simd
https://en.cppreference.com/cpp/execution

Used for:
- `inplace_vector`;
- `hive`;
- SIMD;
- execution control;
- current C++26 library map.

## Maintenance Rule

C++26 was still moving through implementation and late standardization/defect-resolution work when this package was produced.

Before relying on a version-sensitive feature, check:
- current WG21 paper/working draft status;
- cppreference feature status;
- actual compiler/library implementation;
- feature-test macros.
