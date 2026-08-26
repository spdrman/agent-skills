# Mojo Review and Completion Checklists

## Review Order

1. Mojo version compatibility.
2. Contract and invariants.
3. Ownership and argument conventions.
4. Origins/references/lifetimes.
5. Lifecycle/destruction.
6. Unsafe pointers.
7. Foreign interoperability.
8. Shape/layout/index correctness.
9. GPU synchronization/races.
10. Error paths.
11. Tests.
12. Performance.

## Version Checklist

- Exact version known?
- Stable or nightly?
- Syntax valid for it?
- Recent feature status verified?
- Existing project conventions preserved unless migration requested?

## Ownership Checklist

- Owner of every resource known?
- `imm` vs `mut` vs ownership-taking convention correct?
- Accidental copy?
- Consumed value needed later?
- Returned reference has valid origin?
- Mutable references/external pointers alias safely?
- Copyability semantically correct?

## Lifecycle Checklist

- Constructor establishes invariants?
- Move valid?
- Copy valid if provided?
- Destruction exactly once?
- Explicitly-destroyed values handled on every path?
- Partial initialization cleaned safely?

## Unsafe Pointer Checklist

- Allocation live?
- Correct deallocator?
- Bounds proven for entire access/vector?
- Alignment proven?
- Initialized?
- Stride legal?
- Aliasing safe?
- Foreign ownership clear?
- Device address space correct?
- Can a safe wrapper own the proof?

## GPU Checklist

- Index algebra correct?
- Surplus threads guarded?
- Integer width sufficient?
- Reads/writes in bounds?
- Race freedom?
- Barriers correct?
- Divergence around barriers safe?
- Tails handled?
- Reference parity tested?

## FFI Checklist

- ABI supported by pinned version?
- Width/layout exact?
- Nullability defined?
- Ownership/free pairing explicit?
- Encoding defined?
- Callback lifetime/thread/reentrancy defined?
- Python exception/C/C++ error translation deliberate?
- Copy/shared-memory cost understood?

## Performance Checklist

- Baseline exists?
- Correctness oracle exists?
- GPU benchmark synchronized?
- Transfer included/excluded explicitly?
- Representative shape/dtype/layout?
- Multiple runs?
- Generated behavior inspected if claim depends on it?

## Completion Gate

- Version-correct syntax/API?
- Ownership/origins correct?
- Destruction complete?
- Unsafe memory justified and bounded?
- Foreign ownership explicit?
- Kernel bounds/races/synchronization valid?
- Error paths tested?
- Boundary shapes/dtypes/layouts tested?
- Required targets tested?
- Performance measured if claimed?
- Unknown assumptions reported?

Compilation alone does not satisfy this gate.
