# Mojo Language, Ownership, Lifecycles, Traits, and API Design

## Version First

Mojo syntax and semantics evolve quickly. Verify the repository/compiler version before using recent features. Prefer syntax already proven in the repository.

## Value Semantics

A variable owns its value and a struct owns its fields. For every call, determine whether the operation borrows immutably, borrows mutably, consumes/moves, copies, or constructs a new value.

Do not introduce copies just to make lifetime errors disappear.

## Argument Conventions

### `imm`

Use for immutable referenced access when ownership stays with the caller. `imm` is the current convention and is usually implicit. Do not introduce deprecated `read` in latest-Mojo code.

### `mut`

Use when the callee mutates caller-owned state. Treat mutable access as exclusive under Mojo's alias/exclusivity rules.

### `var`, `deinit`, and transfer

Use current ownership-taking/consuming conventions deliberately. `var` is used for ownership-taking arguments where applicable; `deinit` represents consuming/destruction contexts; `^` performs explicit transfer where required. Do not consume merely for speculative performance if callers need the original value.

## References and Origins

For returned or stored references identify owner, origin, lifetime, and mutability. Avoid references into temporaries. Preserve origin information when APIs need it.

Origins encode lifetime/source/mutability information but do not provide bounds checking for unsafe memory.

## Lifecycle

For resource-owning types define constructor, move behavior, copy semantics if valid, destruction, and partial-initialization behavior.

Use synthesized fieldwise lifecycle behavior only when field semantics make it correct.

## Copyability

Do not conform unique resources to `Copyable` unless copying has a correct independent meaning. Files, ownership pointers, device resources, transactions, lock tokens, and foreign handles often should be move-only or explicitly destroyed.

## Explicitly Destroyed Types

When supported by the pinned version, use explicit destruction where resource release must be visible and statically enforced. Audit every branch, early return, and error path.

## Struct Design

- Keep fields typed and purposeful.
- Use construction to establish invariants.
- Keep ownership visible.
- Avoid unrestricted mutation that can violate invariants.
- Place state transitions near representation.

## Traits

Traits should express coherent behavioral contracts. Document laws when conformers must preserve semantics. Use constraints and conditional conformances only when supported by the pinned version.

Do not add traits merely to avoid a few duplicated lines.

## Parameterization

Good compile-time parameters include dtype, vector width, layout, tile size, address space, static dimensions, and algorithm policy. Avoid unnecessary parameter proliferation and specialization explosion.

## Compile-Time vs Runtime

Know whether each expression is compile-time or runtime. Do not assume arbitrary runtime data can populate a compile-time parameter. Use current materialization/reflection facilities only according to the installed version.

## Reflection

Reflection can remove boilerplate but increases abstraction complexity. Use it for clear cases such as serialization metadata, field enumeration, static adaptation, or diagnostics. Test generated behavior on representative types.

## Error Design

Use `raises` according to current syntax. Typed errors, when supported, are useful when callers need static categories. Define cleanup and foreign exception/error translation explicitly.

## API Design

Prefer APIs that make the correct path obvious. State ownership, mutation, returned-reference origin, errors, target restrictions, layouts/dtypes, and meaningful copy costs.

Avoid returning an unsafe pointer when a safe span/pointer or owned value suffices.

## State Machines

Prefer explicit state representation to loosely coupled flags. For resources with mandatory ordering, consider types that encode valid states/sequences.

## Naming

Reveal units and layout semantics: `len_bytes`, `element_count`, `stride_elems`, `tile_rows`, `device_ptr`. Make compile-time/runtime distinction obvious when it matters.
