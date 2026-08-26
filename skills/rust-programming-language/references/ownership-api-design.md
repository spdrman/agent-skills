# Ownership, API Design, Async, and Type-System Reference

## Ownership Strategy

Choose ownership before signatures. Ask who creates the value, who owns it after the call, whether sharing is temporary or persistent, whether mutation is exclusive, whether data crosses threads, and whether heap allocation is necessary.

Prefer roughly: local ownership → borrowing → ownership transfer → `Box` → `Rc` → `Arc` → interior mutability only when semantics require it.

Do not default to `Arc<Mutex<T>>`.

## Borrowing and Lifetimes

- `&T` is a shared reference with Rust aliasing invariants, not merely a const pointer.
- `&mut T` represents exclusive mutable access for the borrow duration.
- Keep mutable borrows narrow.
- Reborrow rather than clone.
- Prefer safe split-borrow APIs over raw pointer workarounds.
- A lifetime parameter should encode a relationship, not decorate every reference.
- Avoid tying unrelated arguments to one lifetime.
- Reconsider whether a long-lived struct should own data rather than store references.

## Newtypes and Validated Types

Use newtypes for units, semantic identities, validated strings, domain indexes, capabilities, and secret wrappers. Keep fields private when construction requires validation.

## Enums, State, and Typestate

Prefer enums over multiple booleans with invalid combinations. Use typestate when illegal sequencing is central and compile-time enforcement materially improves correctness. Avoid typestate when it causes unusable generic complexity for cheap runtime checks.

## Trait Design

- Keep traits cohesive.
- Document semantic laws implementations must obey.
- Use supertraits only when logically required.
- Seal traits when external implementation would make evolution unsafe/impossible.
- Prefer associated types when one implementation has one natural related type.
- Prefer generic parameters when callers choose among alternatives.
- Consider object safety before committing to `dyn Trait`.
- Avoid bounds unrelated to implementation needs.

## Generics vs Dynamic Dispatch

Generics provide static dispatch but can increase code size and compile time. Dynamic dispatch is reasonable for heterogeneous runtime composition, implementation hiding, plugin architecture, or when monomorphization cost outweighs indirect-call cost.

Choose based on API semantics and measurement, not ideology.

## Errors

Library errors should preserve actionable categories and source chains. Avoid exposing dependency errors as permanent API unless intentional. Applications may use ergonomic catch-all wrappers at top-level boundaries.

## Panics

Public operations should document caller-triggerable panics. Do not panic for ordinary parsing, missing files, user input, or network failure. Avoid panic in `Drop`.

## RAII and Drop

Use RAII for files, locks, mappings, temporary state restoration, transactions, registrations, and memory. If cleanup can meaningfully fail, provide explicit `close`/`finish`/`commit` and use Drop as fallback.

## Pinning

Use `Pin` only when address stability is a real invariant. Understand `Unpin`, structural pinning, projection, and destruction guarantees. Prefer established projection abstractions to handwritten unsafe projection.

## Async API Design

Define executor assumptions, `Send` requirements, cancellation safety, backpressure, boundedness, timeouts, shutdown, and cleanup. An async operation may be dropped at any suspension point.

Do not hold synchronous lock guards across `.await`. Use runtime-approved blocking facilities for blocking CPU/I/O/FFI work.

## Channels

Unbounded channels can convert load spikes into OOM. Prefer bounded queues when producers can outrun consumers. Define behavior when full, closed, cancelled, or shutting down.

## Public Crates and Features

- Minimize public surface.
- Keep fields private.
- Keep features additive where possible.
- Test no-default, default, and important feature combinations.
- Avoid leaking dependency types.
- Consider `#[non_exhaustive]`.
- Preserve documented MSRV.

## Iterators

Avoid gratuitous intermediate `collect`. Preserve correct ownership semantics among `iter`, `iter_mut`, and `into_iter`. Implement specialized iterator traits only when their contracts truly hold.

## Macros

Prefer functions/traits when sufficient. For macros, preserve hygiene and spans, test compile failures, keep generated unsafe code auditable, and avoid surprising evaluation/capture behavior.

## Documentation

Document invariants, errors, panics, safety, cancellation, feature requirements, and non-obvious complexity. Prefer executable rustdoc examples.
