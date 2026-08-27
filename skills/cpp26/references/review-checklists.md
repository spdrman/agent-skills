# C++26 Review and Completion Checklists

## General Review

### Interface
- Intent explicit?
- Strongly typed?
- Ownership visible?
- Mutability visible?
- Error model clear?
- Preconditions/postconditions clear?
- Complexity surprising?

### Lifetime
- Any dangling reference/view?
- Reallocation invalidation?
- Escaping lambda captures?
- Async/coroutine lifetime?
- Raw owner?

### Resource
- RAII?
- Rule of Zero possible?
- Destructor noexcept?
- Ownership transfers exactly once?
- Shared ownership truly required?

### Type Safety
- C-style casts?
- narrowing?
- signed/unsigned bugs?
- primitive obsession?
- invalid states representable?

### Error Safety
- exception guarantee?
- expected/exception channel consistent?
- partial mutation?
- cleanup during exceptions?

### Concurrency
- shared state?
- synchronization?
- lock order?
- callback under lock?
- atomic ordering proof?
- shutdown/cancellation?

### Generic Code
- concepts?
- semantic constraints?
- template bloat?
- range lifetime?
- diagnostics?

### ABI
- public layout?
- inline/template leakage?
- C++ ABI assumption?
- PImpl/opaque facade needed?

### Tests
- regression?
- boundaries?
- failure paths?
- sanitizers?
- fuzzing?
- compiler matrix?

## C++26 Feature Review

- Supported compiler/library?
- feature-test macro?
- fallback required?
- new feature simpler than old approach?
- compile-time impact?
- ABI impact?
- vendor-specific workaround isolated?

## Reflection Review

- `__cpp_impl_reflection` / `__cpp_lib_reflection` verified?
- uses current `^^` / `[: :]` syntax, not Reflection TS?
- access context correct?
- reflection simpler than macros/traits?
- compile-time expansion bounded?
- source name/layout accidentally used as stable protocol?
- annotation policy explicit?
- generated code behavior tested?
- public ABI generated?
- fallback strategy?

## Contracts Review

- predicate side-effect free?
- programmer/API condition rather than hostile-input validation?
- enforcement semantics understood?
- would ignored/observed contract permit UB/corruption?
- ordinary guard needed?
- postcondition evaluation safe?
- violation-handler assumptions tested?

## RAII Review

- every resource has owner?
- destructor exactly once?
- move semantics correct?
- copy semantics correct/disabled?
- `shared_ptr` justified?
- manual new/delete removable?

## Class Review

- class has invariant?
- constructor establishes it?
- data private where needed?
- Rule of Zero?
- destructor policy correct?
- inheritance semantic?
- `override` used?
- composition preferable?

## Generic Review

- template genuinely needs to be generic?
- concepts state requirements?
- standard concepts usable?
- reflection structural query being misused as semantic concept?
- compile time acceptable?

## Low-Level Review

- raw pointers isolated?
- bounds proven?
- alignment?
- object lifetime?
- aliasing?
- endianness?
- unaligned access?
- cast rationale?
- sanitizers/fuzzing?

## Performance Review

- baseline?
- profile?
- allocation count?
- locality?
- code size?
- assembly/IR inspected where claim depends on it?
- repeated benchmark?
- build-time impact for reflection/templates?

## Modernization Checklist

1. freeze behavior with tests;
2. replace raw ownership with RAII;
3. replace arrays/pointer-length with containers/span;
4. remove C casts;
5. strengthen value/domain types;
6. replace magic values with optional/expected/enum;
7. Rule of Zero;
8. constrain templates;
9. use ranges/algorithms where clearer;
10. enable hardening/sanitizers;
11. adopt C++26 features selectively;
12. measure.

## Bug-Fix Checklist

- reproduced?
- invariant identified?
- root cause vs symptom?
- regression added?
- smallest repair?
- related occurrences searched?
- sanitizer/static checks?
- ABI/API unchanged?
- performance unaffected or measured?

## Completion Gate

Applicable answers must be established:

- defined behavior?
- no resource leaks?
- ownership explicit?
- no dangling views/references?
- errors/exceptions correct?
- contracts not misused?
- reflection capability verified?
- thread/cancellation model correct?
- public API/ABI preserved?
- toolchain matrix builds?
- tests pass?
- sanitizers/static/fuzz checks done when relevant?
- performance measured if claimed?
- compile-time cost acceptable?
- unknowns reported?
