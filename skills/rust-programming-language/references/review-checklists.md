# Rust Review and Completion Checklists

## Review Order

1. Contract and invariants.
2. Safe API soundness.
3. Ownership and lifetimes.
4. Integer/index/allocation safety.
5. Error and panic behavior.
6. Unsafe proof.
7. Concurrency and cancellation.
8. Hostile input.
9. API/semver/features.
10. Portability/MSRV.
11. Tests.
12. Performance.

## Unsafe Review

For every unsafe block:

- Which operation is unsafe?
- What are its requirements?
- Where is each requirement established?
- Does each fact remain true long enough?
- Can a safe caller, panic, callback, or reentrancy invalidate it?
- Can the unsafe scope be smaller?
- Is there a meaningful `SAFETY:` explanation?
- Should Miri/fuzz/Loom/sanitizers be applied?

## API Review

- Invalid states representable?
- Ownership clear?
- Panics documented?
- Errors actionable?
- Dependency types leaked?
- Features additive?
- Semver hazards?
- Trait impl addition hazards?
- `non_exhaustive` useful?
- MSRV accidentally raised?

## Concurrency Review

- Shared mutable state identified?
- `Send`/`Sync` justified?
- Lock ordering?
- Lock across `.await`?
- Callback under lock?
- Atomic ordering proof?
- Shutdown race?
- Cancellation leaves valid state?
- Queue bounded?

## Bug-Fix Checklist

- Reproduced original bug.
- Identified root invariant violation.
- Added regression test.
- Applied smallest complete fix.
- Ran focused/relevant tests.
- Ran unsafe validation if applicable.
- Searched sibling bug patterns.
- Checked semver/features/MSRV.
- Explained root cause.

## Completion Gate

- Safe APIs sound?
- Unsafe obligations documented and established?
- Ownership/lifetimes clear?
- Error/panic behavior correct?
- Hostile input bounded?
- Concurrency/cancellation correct?
- MSRV/features valid?
- Public API/file/protocol compatibility preserved?
- Relevant tests and tools run?
- Performance measured if claimed?
- Unknown items explicitly reported?

Compiler acceptance alone does not satisfy this gate.
