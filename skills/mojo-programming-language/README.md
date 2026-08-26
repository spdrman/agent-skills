# mojo-programming-language

An agent skill for writing, reviewing, and migrating Mojo.

## What it changes

Without this skill, a model writing Mojo falls back on pretrained memory, and that memory is mostly
wrong now. It reaches for `fn`, `alias`, `@parameter if`, `let`, `inout`, `owned`, `__del__`, and
`mojo test`, all removed or renamed. This skill puts current Modular syntax guidance in front of
that reflex, then adds discipline on top: pin down the compiler version first, treat ownership and
origins as part of the API contract, treat unsafe pointers and foreign boundaries as places where
you owe a proof, and refuse to claim a speedup without a benchmark that was actually run. It also
stops the agent modernising a project pinned to an older compiler unless you asked for a migration.

## Reference files

Locally authored, general Mojo engineering judgement:

- `language-ownership-traits.md` (4 KB). Value semantics, `imm`/`mut`/`var`/`deinit`, references and
  origins, lifecycles, copyability, traits, parameterization, error and API design.
- `memory-unsafe-ffi.md` (4 KB). Proof obligations before any unsafe load, store, or pointer
  arithmetic, plus allocator pairing, C ABI, C++ exceptions, callbacks, and device pointers.
- `gpu-simd-performance.md` (4 KB). Optimisation ordering, SIMD tails, data layout, memory
  hierarchy, coalescing, barriers, races, atomics, benchmark hygiene.
- `testing-tooling-versioning.md` (3 KB). `TestSuite` runners, differential testing, boundary shapes
  and dtypes, error paths, debugging method, version migration procedure.
- `review-checklists.md` (3 KB). Review gates for version, ownership, lifecycle, unsafe memory, GPU,
  FFI, performance, and completion.

Under `references/modular-official/`, derived from Modular upstream (see Attribution):

- `mojo-syntax.md` (9 KB). Removed-syntax table and current forms for declarations, `comptime`,
  argument conventions, lifecycle, imports, strings, SIMD, closures. Mandatory read before any Mojo.
- `mojo-gpu-fundamentals.md` (6 KB). `DeviceContext`, `TileTensor`, layouts, launch specialisation,
  shared memory and barriers, warp ops, cross-vendor rules.
- `mojo-python-interop.md` (5 KB). Calling Python from Mojo, conversions, exceptions,
  `PythonModuleBuilder` extension modules, `mojo.importer`, ownership across the boundary.
- `closure-migration-process.md` (5 KB). Migrating off legacy parametric closures step by step, with
  a diagnosis table keyed by compiler error class.
- `closure-migration.md` (4 KB). Shorter companion: capture list semantics, the ban on reintroducing
  `@parameter` on nested closures, no-functional-change rules.
- `new-modular-project.md` (3 KB). Pixi, uv, pip, conda setup, stable versus nightly, MAX alignment.
- `UPSTREAM.md` (1 KB). Provenance, licence, and refresh policy.

`scripts/sync_modular_skills.sh` pulls an exact current snapshot of the six upstream files into
`references/modular-official/upstream/` when you want byte-for-byte upstream, not the digests.

## When it triggers

When you ask an agent to write, review, debug, optimise, test, port, benchmark, or migrate Mojo, or
when the work touches structs, traits, ownership and origins, explicit destruction,
`Pointer`/`UnsafePointer`, SIMD, CPU or GPU kernels, MAX tooling, Python interop, or C/C++ FFI. Also
when a repo simply contains a lot of Mojo and the task needs judgement about it.

## What this is opinionated about

- Version before syntax. A repo pinned to an older compiler outranks both the bundled guidance and
  the model's memory, and does not get modernised unless you asked for a migration.
- Bundled guidance outranks pretrained knowledge. For latest Mojo, `mojo-syntax.md` is authoritative
  and gets loaded before code is generated, not after.
- No measurement, no claim. "Do not claim zero-cost abstraction without measurement or
  generated-code evidence." Algorithm ranks first in the optimisation order, pointer tuning ninth.
- Ownership errors get fixed, not silenced. Do not add a copy to bypass an origin error, erase an
  origin to quiet an alias diagnostic, or make a resource type `Copyable` for convenience.
- Kernels are bounds-checked by default. Never drop a guard because launch dimensions "should"
  match, never import CUDA spellings, never assume warp size 32 across vendors.

## Attribution

`references/modular-official/` contains material derived from Modular's agent skills repository at
https://github.com/modular/skills (`main`, reviewed 2026-08-25), specifically its `mojo-syntax`,
`mojo-gpu-fundamentals`, `mojo-python-interop`, `new-modular-project`, `closure_migration` skills.

That repository is distributed under the Apache License, Version 2.0 with LLVM Exceptions. A copy of
the Apache 2.0 terms ships here as `LICENSE-Modular-Skills-Apache-2.0.txt`. That copy carries the
base Apache 2.0 text without the LLVM Exceptions addendum, so read it alongside the upstream
`LICENSE` if the exceptions matter to you. Upstream ships no `NOTICE` file.

The bundled files are condensed derivatives, not verbatim copies. Prose has been rewritten and
shortened (the syntax digest is roughly 40 percent the length of its upstream source), with only
short code snippets and API signatures held in common. Each carries a header naming its upstream
source and `UPSTREAM.md` records the adaptation. Nothing here is official or endorsed by Modular.
