# Errors, Contracts, Hardening, and Safety

## Error Taxonomy

Distinguish:

1. programmer invariant violation;
2. invalid external input;
3. expected operational failure;
4. exceptional inability to fulfill operation;
5. resource exhaustion;
6. cancellation;
7. process-fatal corruption.

Do not route all categories through one mechanism.

## Exceptions

Use exceptions when:
- project policy supports them;
- failure prevents normal return;
- stack unwinding/RAII is beneficial;
- callers may handle at a meaningful boundary.

Do not catch only to rethrow without adding value.

Catch by reference.

Preserve nested/source error context where useful.

## `expected`

Use `std::expected<T,E>` for explicit, expected, recoverable failures where callers naturally branch/compose.

Good examples:
- parse result;
- protocol decode;
- configuration validation;
- lookup where failure reason matters.

Avoid giant error enums spanning unrelated subsystems.

## `optional`

Use for absence that is not itself an error.

Do not use optional when the missing case needs diagnostic information.

## Exceptions vs `expected`

Choose based on API semantics, not ideology.

Exceptions:
- implicit propagation;
- strong RAII integration;
- good for exceptional failure across many frames.

Expected:
- explicit in type;
- good for local/domain error composition;
- suitable where exception-free codebase policy applies.

Do not duplicate both channels.

## Exception Guarantees

Consider:

- no-throw guarantee;
- strong guarantee (failure leaves original state);
- basic guarantee (invariants preserved, no leaks);
- no guarantee only in narrow documented cases.

Prefer transaction-like mutation patterns that naturally give strong guarantee.

## `noexcept`

Use when operation is semantically non-throwing.

Especially important for:
- destructors;
- many move operations;
- swap;
- low-level callbacks where unwinding forbidden.

Do not mark throwing code `noexcept` merely for optimization.

## Contracts

C++26 contracts expose preconditions/postconditions/internal assertions.

Use them to document semantic contracts at the point callers see them.

Keep predicates:
- pure;
- cheap enough for intended checking mode;
- stable;
- independent of side effects.

## Contracts Are Not Hostile-Input Validation

External input must be validated through normal control flow.

Why:
- invalid external data is expected;
- callers need error information;
- contract evaluation may not be guaranteed in every build/semantic mode;
- continuing after contract violation can be problematic.

Example:

```cpp
std::expected<Request, ParseError>
parse(std::span<const std::byte> bytes);
```

The parser should not use a precondition to claim attacker-controlled bytes are valid.

## Contract Conditions and UB

If a function body would execute UB when a condition fails, do not assume a `pre` clause will always prevent entry unless the configured semantics guarantee it.

When mandatory enforcement is required, perform a normal guard or use an API whose type prevents invalid input.

## Assertions

Use `assert` for debug programmer invariants in codebases that do not use contracts or where contracts are unavailable.

Never use assert for required security validation.

## Standard Library Hardening

Enable hardened standard library mode where appropriate.

Hardening should:
- catch selected precondition violations;
- improve production defense;
- complement safe APIs.

Do not assume it validates iterators/pointers beyond specified hardened conditions.

## Initialization

Initialize variables.

C++26 erroneous behavior is not a license to use uninitialized data.

Compiler warnings remain mandatory.

## Integer Safety

Audit:
- signed overflow;
- unsigned wrap;
- narrowing;
- signed/unsigned comparisons;
- multiplication before allocation;
- shift width;
- enum conversions;
- pointer difference.

Use:
- `std::cmp_*`;
- `std::in_range`;
- checked arithmetic facilities/project helpers;
- saturation arithmetic where semantics call for saturation.

Avoid C-style casts that obscure narrowing.

## Bounds Safety

Prefer:
- spans;
- containers;
- ranges;
- sized abstractions.

Raw pointer + integer length APIs should be isolated at C/OS/ABI boundaries.

## `operator[]`

Use unchecked indexing only when the bound is established by nearby logic/invariant.

For hostile or uncertain indexes use checked access or explicit guards.

Hardened libraries add defense but do not eliminate reasoning.

## Null Safety

Prefer references for required objects.

Use pointers only when null is a meaningful state.

Avoid functions taking `T*` that immediately assert non-null; use `T&` instead unless ABI constraints prevent it.

## Type Punning

Prefer:
- `std::bit_cast` for value representation copying;
- `std::memcpy` where appropriate;
- `std::byte` storage.

Avoid union/reinterpret tricks unless low-level invariants are proven.

## Lifetime Safety

Audit:
- dangling views;
- callbacks;
- async;
- coroutines;
- vector invalidation;
- captured `this`;
- returned references;
- temporary ranges;
- manual storage.

Use ASan and static lifetime tools where available.

## Cast Policy

- `static_cast`: explicit value/conversion relationship.
- `dynamic_cast`: checked polymorphic cast when dynamic hierarchy warrants it.
- `const_cast`: exceptional boundary; ask why const model is wrong.
- `reinterpret_cast`: low-level representation/ABI boundary only.

C-style casts are prohibited in new code except where external coding standard explicitly requires them.

## Unsafe Boundary

Mark low-level code clearly.

A function/module that performs:
- raw allocation;
- pointer arithmetic;
- manual object lifetime;
- unaligned access;
- intrinsics;
- inline assembly;
- FFI;

must document its safety invariants and expose a safer interface upward.

## Security Review

Audit:
- lengths;
- indexes;
- integer conversions;
- format strings;
- paths;
- temp files;
- TOCTOU;
- deserialization;
- decompression bombs;
- recursion depth;
- allocation limits;
- concurrency resource exhaustion;
- error-message disclosure.

Use standard cryptographic libraries; never invent cryptography.
