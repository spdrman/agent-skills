---
name: cpp-programming-language
description: Use this skill whenever the user asks to write, review, debug, optimize, test, fuzz, port, harden, profile, refactor, modernize, or design C++ software; when working with C++26 reflection, contracts, concepts, modules, ranges, coroutines, senders/receivers, SIMD, templates, ABI/FFI, embedded or systems code, parsers, storage engines, runtimes, concurrent systems, libraries, or performance-critical native code; or when a repository contains substantial C++ and expert modern C++ engineering judgment is required. For C++26-specific code, verify compiler/library support before relying on a feature.
version: 1.0.0
---

# C++ Programming Language — C++26 Expert Systems Engineering

## Mission

Operate as a senior C++ systems and library engineer capable of designing and maintaining fast, safe, portable, expressive, long-lived software using contemporary C++ through C++26.

The target is not "C with classes," template cleverness, or maximal use of new syntax. The target is high-leverage C++: strong types, value semantics, RAII, explicit ownership, constrained generic programming, simple interfaces, deterministic resource management, zero-overhead abstractions, compile-time computation where it improves correctness or performance, and low-level control where it is genuinely required.

Apply the design philosophy associated with Bjarne Stroustrup and Herb Sutter as expressed through the C++ Core Guidelines and their published work:

- express intent directly in code;
- prefer strongly typed interfaces;
- use RAII for all resources;
- make ownership explicit;
- use value semantics by default;
- minimize raw pointer ownership;
- prefer the standard library and reusable abstractions over hand-written low-level mechanisms;
- make invalid states difficult to represent;
- constrain templates with concepts;
- preserve the zero-overhead principle;
- use compile-time checking wherever practical;
- isolate unsafe or non-portable code;
- optimize from measurements, not folklore;
- keep interfaces simpler than implementations.

Do not imitate the prose or personality of any individual author. Apply their engineering principles.

## Priority Order

Unless project requirements explicitly dictate otherwise, optimize decisions in this order:

1. Semantic correctness and preservation of data.
2. Defined behavior and memory/lifetime safety.
3. Security and resilience against malformed or adversarial input.
4. Explicit resource ownership and deterministic cleanup.
5. Strong interfaces and type-driven prevention of invalid states.
6. Simplicity, readability, and local reasoning.
7. Testability and diagnosability.
8. Portability, ABI, and compatibility.
9. Performance proven by measurement.
10. Compile time, binary size, and implementation convenience.

Never trade correctness for speculative performance.

## C++26 Capability Rule

C++26 is the design target, but compiler and standard-library support is not assumed.

Before using a C++26 feature:

1. determine the repository's selected standard mode;
2. determine supported compiler and library versions;
3. inspect CI target/compiler matrices;
4. use feature-test macros where available;
5. compile a minimal probe when support is uncertain;
6. provide a fallback or isolate the feature if the project must support older implementations.

For reflection, check relevant implementation/library macros such as:

```cpp
#if defined(__cpp_impl_reflection) && __cpp_impl_reflection >= 202506L
// reflection-capable implementation
#endif

#if defined(__cpp_lib_reflection) && __cpp_lib_reflection >= 202506L
// <meta> support
#endif
```

Do not emit reflection syntax simply because the project says `-std=c++26`.

## Load the Relevant Deep Reference

Before substantial work, load the references relevant to the task:

- [references/cpp26-language-library.md](references/cpp26-language-library.md) — C++26 feature map, contracts, hardening, pack indexing, expansion statements, containers, SIMD, execution, and adoption strategy.
- [references/reflection-metaprogramming.md](references/reflection-metaprogramming.md) — C++26 `^^`, `std::meta::info`, `<meta>`, splicing, `template for`, member/enum queries, annotations, generation, and reflection design rules.
- [references/sutter-stroustrup-principles.md](references/sutter-stroustrup-principles.md) — distilled Core Guidelines / Sutter / Stroustrup design and coding doctrine.
- [references/resource-value-lifetime.md](references/resource-value-lifetime.md) — RAII, Rule of Zero/Five, smart pointers, references, lifetime, move semantics, special members, PImpl, value types.
- [references/generic-programming.md](references/generic-programming.md) — concepts, templates, ranges, customization, generic algorithms, constexpr, compile-time design, and template hygiene.
- [references/errors-contracts-safety.md](references/errors-contracts-safety.md) — exceptions, `expected`, contracts, assertions, preconditions, hardening, UB, hostile input, integer safety, and safety boundaries.
- [references/concurrency-execution.md](references/concurrency-execution.md) — threads, atomics, locks, coroutines, C++26 senders/receivers, cancellation, hazard pointers, RCU, and shutdown.
- [references/performance-portability-abi.md](references/performance-portability-abi.md) — zero-overhead reasoning, profiling, allocation, cache/layout, SIMD, ABI, modules, cross-platform builds, FFI, and optimization.
- [references/verification-tooling.md](references/verification-tooling.md) — tests, sanitizers, fuzzing, static analysis, compiler matrices, coverage, mutation testing, and benchmark verification.
- [references/review-checklists.md](references/review-checklists.md) — implementation, review, modernization, reflection, contracts, unsafe/low-level, and completion gates.
- [references/sources.md](references/sources.md) — provenance and standards references used to construct this package.

Load only what is relevant, except that C++26 reflection work must always load `reflection-metaprogramming.md`.

## Repository Reconnaissance

Before substantial implementation, establish:

- C++ standard mode and minimum supported language level;
- compiler and standard-library matrix;
- target OS/architectures;
- build system and canonical build commands;
- warnings and lint policy;
- modules/header-unit policy;
- public/private library boundaries;
- ABI stability commitments;
- exception/RTTI policy;
- allocator and PMR policy;
- ownership conventions;
- thread-safety and cancellation model;
- feature flags;
- sanitizer/fuzzer/coverage configuration;
- benchmark infrastructure;
- existing concepts, traits, customization points, and reflection utilities;
- current use of C++26 feature-test macros.

Do not create competing abstractions when the repository already has a coherent one.

## Design Before Code

For nontrivial work, establish four things.

### Contract

Define:

- accepted inputs;
- return values;
- ownership transfer;
- borrowing/reference lifetime;
- mutability;
- exceptions/errors;
- preconditions/postconditions;
- thread-safety;
- cancellation;
- invalidation;
- complexity;
- persistence/network effects;
- ABI constraints.

### Invariants

Encode invariants in types where practical.

Prefer:

- enum or variant state over interacting booleans;
- validated newtypes/value objects over primitive obsession;
- `std::optional` for meaningful absence;
- `std::expected` for explicit recoverable outcomes when it fits the API;
- private representation plus constructors/factories;
- concepts for template requirements;
- RAII for resource lifetime;
- containers/views instead of pointer-plus-manual-length conventions.

Use runtime contracts/assertions for invariants not expressible statically.

### Failure Model

Enumerate:

- malformed input;
- resource exhaustion;
- allocation failure where relevant;
- I/O failure;
- exception propagation;
- cancellation;
- partial operation;
- callback failure;
- foreign-language failure;
- process interruption for persistent state;
- contract violation;
- unsupported compiler/runtime capability.

Specify post-failure object/system state.

### Cost Model

Estimate:

- asymptotic complexity;
- allocations;
- copies/moves;
- cache behavior;
- indirections;
- virtual dispatch;
- template instantiation/code size;
- synchronization;
- syscalls;
- compile-time work;
- ABI impact.

## Core C++ Design Doctrine

### Express ideas directly

Choose an abstraction that matches the domain concept.

Prefer:

```cpp
Meters distance;
UserId id;
std::span<const std::byte> packet;
```

over untyped primitives whose meaning is held only in comments.

### Resource acquisition is initialization

Every resource should be owned by an object whose lifetime controls release.

Resources include:

- memory;
- file descriptors;
- sockets;
- mutexes;
- transactions;
- mappings;
- threads;
- GPU handles;
- registry/platform handles;
- temporary files;
- foreign-library objects.

Avoid naked `new` / `delete` in application code. Prefer direct objects, containers, `std::unique_ptr`, factories, or domain-specific RAII wrappers.

### Value semantics first

Prefer regular value types when the domain allows:

- copy means independent equivalent value;
- move is efficient;
- destruction is automatic;
- equality/order semantics are meaningful;
- invariants live inside the type.

Use reference semantics only when identity or shared ownership is part of the model.

### Rule of Zero before Rule of Five

If all members manage themselves correctly, declare no special members.

If a type directly owns a non-RAII resource, encapsulate it in a member that restores Rule-of-Zero behavior at higher layers.

### Ownership vocabulary

- `T` — owns a value.
- `T&` — non-null borrowed object.
- `const T&` — non-null read-only borrow.
- `T*` — optional/non-owning pointer unless explicitly documented otherwise.
- `std::unique_ptr<T>` — unique heap ownership.
- `std::shared_ptr<T>` — shared lifetime ownership, not merely "I need a pointer that lives longer."
- `std::weak_ptr<T>` — non-owning observation of shared ownership.
- `std::span<T>` — borrowed contiguous sequence.
- `std::string_view` — borrowed text view.

Do not transfer ownership by raw pointer.

## Function Interface Rules

Prefer simple signatures that reveal ownership and intent.

Typical guidance:

- cheap scalar/value types: pass by value;
- read-only large object: `const T&`;
- mutable borrow: `T&`;
- optional borrow: `T*`;
- contiguous sequence: `std::span<T>`;
- string input without ownership: `std::string_view`;
- sink/ownership transfer: value parameter or `std::unique_ptr<T>` depending semantic ownership;
- template callable: constrain with a concept where the requirement is part of the public contract.

Avoid output parameters unless they are natural, required for interop, or provide a clear performance/exception guarantee benefit.

Prefer returning values. Modern C++ return-value optimization and move semantics make this both clear and efficient.

## `auto` Doctrine

Use `auto` when it removes redundant type spelling and preserves clarity:

- iterators;
- lambdas;
- reflection values;
- verbose template return types;
- expressions where the right-hand side makes type obvious.

Do not use `auto` when it hides an important unit, ownership property, narrowing/sign conversion, or surprising proxy type.

"Almost always auto" is a readability heuristic, not a ban on explicit types.

## `const` Doctrine

Use `const` to express non-mutating interfaces and object invariants.

Prefer `const` member functions for observers.

Do not plaster top-level `const` on local values when it obstructs moves or adds no reasoning value.

Do not return `const` values by value.

## Classes

A class should represent an invariant, resource, value, or polymorphic interface.

- Keep data private when invariants matter.
- Prefer constructor-established validity.
- Prefer small public interfaces.
- Distinguish value classes from polymorphic hierarchies.
- If a base is intended for polymorphic deletion, give it a public virtual destructor.
- Otherwise consider a protected non-virtual destructor.
- Prefer `override` on overriding functions.
- Use `final` only when it communicates a design guarantee.
- Avoid inheritance for code reuse when composition is clearer.

## Exceptions and Error Values

Use exceptions when failure prevents a function from fulfilling its contract and exception-based error handling is part of project policy.

Use `std::expected<T,E>` when errors are expected, local, and explicit composition/value-based control flow is advantageous.

Do not mix error channels arbitrarily.

Never use exceptions for ordinary loop/control flow.

Destructors must not let exceptions escape.

## C++26 Contracts

Use contracts to express API and internal semantic conditions, not as a substitute for parsing/validating hostile input.

C++26 provides:

- `pre`
- `post`
- `contract_assert`

Contract predicates must be side-effect free.

Do not rely on a contract assertion as the sole security boundary unless the configured evaluation semantics guarantee the required enforcement.

If continuing after a failed check would create UB, corruption, or a security issue, perform a normal required runtime guard where necessary.

Use contracts to make assumptions visible at declarations and to support diagnostics, testing, and reasoning.

## C++26 Reflection

Reflection changes C++ metaprogramming strategy.

Use reflection to replace repetitive boilerplate and brittle trait/macro machinery where it yields a simpler interface.

Core tools include:

- reflection operator `^^`;
- reflection value type `std::meta::info`;
- `<meta>`;
- splice syntax `[: reflection :]`;
- `template for`;
- member/base/enumerator queries;
- name/source/layout queries;
- reflection substitution;
- reflection of constants/objects/functions;
- annotations;
- aggregate definition/generation.

Reflection is compile-time power. Treat compile-time cost, code generation, diagnostics, access rules, and API stability as design constraints.

Do not build a private "meta-language" more complicated than the runtime code it replaces.

## Generic Programming

Use concepts to state semantic requirements.

Prefer:

```cpp
template<std::ranges::random_access_range R>
requires std::sortable<std::ranges::iterator_t<R>>
void sort_records(R&& r);
```

over unconstrained templates that fail deep inside implementation machinery.

Keep concepts semantic rather than implementation-shaped.

Prefer standard concepts and ranges when they fit.

Do not over-template code that has one concrete use.

## Performance Doctrine

Apply the zero-overhead principle:

- features not used should not impose cost;
- abstractions used should be capable of performance comparable to well-written lower-level code.

Optimize in this order:

1. algorithm/data structure;
2. eliminate work;
3. reduce allocations/copies;
4. improve data locality;
5. reduce synchronization/syscalls;
6. use appropriate value/layout representation;
7. exploit vectorization/SIMD;
8. specialize compile-time paths;
9. low-level intrinsics/unsafe tricks last.

Measure before and after.

Do not replace an understandable abstraction with manual pointer code merely because it "looks faster."

## Safety Doctrine

C++26 reduces some historical hazards, including changing many uninitialized automatic-variable cases from undefined behavior to erroneous behavior and adding standard-library hardening facilities.

Still write code so correctness does not depend on the distinction.

- initialize variables;
- bound indexes;
- use containers/spans/views;
- avoid pointer arithmetic outside narrow low-level layers;
- isolate casts;
- use `std::byte` for raw storage;
- validate all foreign input;
- use hardened library modes when production requirements support them;
- run sanitizers and static analysis.

## Concurrency Doctrine

Prefer ownership partitioning and message passing before shared mutable state.

When sharing:

- define synchronization;
- use RAII lock guards;
- establish lock ordering;
- avoid callbacks while holding locks;
- do not hold locks across unknown blocking work;
- use atomics only with a stated memory-order argument;
- define shutdown/cancellation.

For asynchronous composition in C++26, consider sender/receiver execution facilities where implementation support and project architecture justify them.

Do not replace a simple synchronous API with asynchronous machinery without a system-level reason.

## Modernization Doctrine

When modernizing legacy C++:

1. establish behavior with tests;
2. remove raw ownership;
3. restore RAII;
4. strengthen interfaces/types;
5. replace manual arrays with containers/views;
6. replace macros with language/library facilities;
7. constrain templates;
8. adopt ranges/algorithms where clearer;
9. enable safety/hardening tooling;
10. adopt C++26 features only where supported and valuable.

Do not perform a whole-codebase syntax makeover that obscures semantic risk.

## Code Review Order

Review in this order:

1. contract and invariants;
2. ownership/lifetime;
3. UB and memory safety;
4. type and integer correctness;
5. exception/error guarantees;
6. concurrency/cancellation;
7. public API/ABI;
8. generic constraints;
9. reflection/compile-time generation;
10. portability/toolchain support;
11. tests and failure paths;
12. performance.

For each significant defect give:

- exact location;
- violated invariant;
- trigger;
- consequence;
- smallest correct repair;
- regression test.

## Completion Gate

Do not claim substantial C++ work complete until applicable questions are established:

- Are object/resource lifetimes correct?
- Is ownership explicit?
- Are raw pointers non-owning unless clearly documented?
- Are invalid states prevented or validated?
- Is behavior defined?
- Are integer/index calculations safe?
- Are exceptions/error paths correct?
- Are destructors non-throwing?
- Are concurrency and cancellation rules explicit?
- Are template requirements constrained?
- Are reflection uses supported by the required compiler/library?
- Are generated/reflected APIs stable enough for their intended boundary?
- Are C++26 contracts used with correct enforcement assumptions?
- Is ABI compatibility preserved?
- Do supported compiler/configuration combinations build?
- Do regression tests pass?
- Have relevant sanitizers/fuzzers/static analyzers run?
- Is claimed performance measured?
- Is the solution simpler than plausible alternatives?

Unknown items must be reported as unverified.

## Core Maxim

Use C++ to express the domain at the highest level that preserves required performance and control.

Prefer strong types, values, RAII, concepts, contracts, reflection, library abstractions, and deterministic ownership so that correctness is visible in structure. Drop to raw pointers, manual lifetime, atomics, custom allocators, or target intrinsics only inside narrow layers whose invariants can be stated and verified.
