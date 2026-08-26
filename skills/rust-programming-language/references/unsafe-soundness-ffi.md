# Unsafe Rust, Soundness, FFI, and Low-Level Reference

## Prime Directive

A safe public function must be safe for every input constructible by safe Rust. Unsafe internals cannot shift undocumented obligations onto safe callers.

## Unsafe Proof Template

For each unsafe operation establish:

1. operation being performed;
2. its documented safety contract;
3. facts required by that contract;
4. source of each fact;
5. duration each fact remains true.

Record the relevant proof in a nearby `SAFETY:` comment.

## `unsafe fn`

Use only when the caller must uphold compiler-unchecked safety requirements. Document complete caller obligations under `# Safety`. Inside the function, keep explicit unsafe blocks for unsafe operations.

## Raw Pointers

Before dereference establish non-nullness where required, alignment, dereferenceable range, valid initialization, backing allocation lifetime, aliasing/exclusivity, provenance-relevant constraints, and legal pointer arithmetic.

Do not construct references from raw pointers until reference invariants hold. References have stronger invariants than pointers.

## Aliasing and `UnsafeCell`

Treat `&mut T` as exclusive access. Do not create overlapping mutable references or illegal shared/mutable combinations. `UnsafeCell` permits interior mutation through shared references; it does not waive validity, lifetime, or data-race rules.

## Initialization and Validity

Use `MaybeUninit<T>` for uninitialized storage. Never create invalid typed values. Be especially careful with references, `bool`, `char`, enums, nonzero types, and function pointers. Track partial initialization so only initialized elements are dropped.

## `zeroed`, `transmute`, and Casts

Treat as high risk. `zeroed` is invalid for many types. `transmute` requires size compatibility and target validity and often obscures intent. Prefer purpose-built conversions. Never assume `repr(Rust)` layout stability.

## Layout and ABI

Use `repr(C)` where C aggregate layout is required and `repr(transparent)` only when its guarantee matches the boundary. Layout compatibility is not automatically ABI compatibility. Never serialize raw native layout as a stable format unless ABI dependence is intentional.

## Manual `Send` / `Sync`

Before unsafe impl, prove internal invariants remain valid under cross-thread movement/sharing. Consider raw pointers, thread-affine handles, foreign restrictions, mutation, destructor thread, callbacks, and mapped/shared memory. Document the proof.

## Atomics

Choose ordering from a synchronization proof. Document publication, visibility, modification order, compare-exchange failure ordering, ABA/reclamation issues, and object lifetime. Use Loom for nontrivial algorithms where practical.

## Custom Collections

Track allocation, capacity, initialized length, growth overflow, alignment, ZST behavior, panic during construction, partial drop, iterator aliasing, and drain/splice panic paths. Safe APIs must remain sound under panics.

## FFI Boundary Checklist

Define ABI, exported symbols, integer widths, representation, nullability, pointer ownership, allocation/free pairing, strings/encoding, lengths, callback lifetime, threading, errors, and panic/exception behavior.

Never unwind a Rust panic across a foreign boundary not designed for it. Never free memory with a mismatched allocator/runtime.

## C Strings

Account for embedded NUL. NUL termination does not imply UTF-8. Borrowed foreign strings must remain live and unmodified as required for the borrow.

## Callbacks

Define state ownership, registration lifetime, concurrent invocation, deregistration races, reentrancy, callback thread, and panic handling. Never smuggle borrowed stack state into a callback that may outlive it.

## Memory-Mapped / Shared Memory

Do not create normal Rust references into storage that may be mutated externally in ways that violate Rust's aliasing/data-race model. Consider alignment, process-shared atomics, initialization, remapping, truncation, device/volatile semantics, and crash behavior.

## Validation

Use appropriate combinations of Miri, sanitizers, fuzzing, Loom, multiple optimizations, multiple targets, and focused human review. Tool success is evidence, not proof.
