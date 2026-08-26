# Modular Official Guidance — Unified Closure Migration

> Integrated from Modular's official `closure_migration` skill, Apache-2.0. Pair with `mojo-syntax.md`; for GPU call sites also pair with `mojo-gpu-fundamentals.md`.

## Goal

Migrate legacy parametric/comptime closure APIs toward current **value-taking unified closures**.

Typical legacy shape:

```text
api[fn](args)
```

Preferred shape:

```text
api(args, fn)
```

Migrate callers before deleting old overloads.

## Hard Ban

Do not introduce or reintroduce `@__parameter` / `@parameter` on nested closures as:

- a bridge;
- an imm-borrow workaround;
- a fix for a capturing-thin error;
- a way to satisfy an unmigrated API.

If a callee still requires legacy `capturing[_]`, either migrate that API first or leave the caller on the old contract temporarily. Do not paper over it with deprecated decorators.

## Capture Lists

Unified closures use explicit capture lists.

Conceptual mapping:

| Intent | Current capture |
|---|---|
| read outer state | `{imm}` |
| mutate selected outer buffer plus read others | `{mut buf, imm}` |
| copy/own a named captured value | `{var name, ...}` |
| move ownership | `var` capture plus explicit transfer semantics where required |
| no runtime captures | `{}` |

Do not replace an old copy-capture with `{imm}`; that changes ownership/alias behavior.

Do not use capture-all `{mut}` when register-passable values such as indexes are also captured and cannot be mut-captured.

## Migration Sequence

1. inventory parametric calls and legacy decorators;
2. identify the value-taking overload/signature;
3. rewrite call order;
4. convert nested closure declaration to a unified closure;
5. translate copy captures to owned/copy captures;
6. mark only truly mutated origins as `mut`;
7. compile/typecheck;
8. resolve alias diagnostics structurally;
9. delete obsolete overloads only after callers compile;
10. verify no deprecated nested-closure decorators remain in touched code.

## Origin / Aliasing Errors

Never "fix" origin aliasing by:

- erasing the origin;
- unsafe-origin casting;
- wrapping the same pointer in a second DeviceBuffer merely to make the type checker stop complaining;
- restoring `@__parameter`.

Prefer:

1. capture/pass as immutable if it is actually read-only;
2. break a large captured object into smaller independent values;
3. pass the mutable origin as an explicit argument rather than storing multiple aliasing captures.

The compiler diagnostic often points to a real ambiguity in ownership representation even when the underlying algorithm is logically race-free.

## Buffers in Closures

A closure that creates a mutable tensor view or calls a helper that requires mutable pointer access may need a `mut` capture even if the closure source looks mostly read-only.

Do not add an unsafe mutable cast as the first response. Fix the capture/argument ownership model.

## NFC Discipline

A closure migration should be **no functional change** unless another behavior change is explicitly requested.

Do not accidentally change:

- allocation lifetime;
- buffer placement;
- compile-time versus runtime layout;
- timed benchmark work;
- target branch allocation;
- synchronization.

## Verification

Current official process recommends compiling/typechecking touched Mojo and searching for legacy decorators/call forms after migration.

For GPU benchmark paths, also verify that the timed region still contains the same work and that capture changes did not add allocation/copy/host work.
