# rust-programming-language

This skill changes what an agent does before and after it writes Rust more than it changes the Rust
itself. Before code, it forces four things into the open: the contract (ownership, lifetimes,
thread safety, panic behavior, cancellation), the invariants and which of them the type system can
carry, the failure model, and the expected cost. After code, it grades the result against a
completion gate rather than a green build. The sharpest change is around claims, since it forbids
reporting a test, Miri run, sanitizer, fuzzer, or benchmark as passing unless it actually ran.

## When it triggers

It fires on requests to write, review, debug, optimize, test, fuzz, port, harden, profile,
refactor, or design Rust. It also fires on the shape of the work rather than the verb: Cargo
workspaces, async runtimes, embedded or `no_std` targets, FFI, `unsafe`, proc macros, parsers,
storage engines, concurrent systems, and performance-critical native code. And it fires on context,
when a repository already holds substantial Rust and the task needs judgement, not a snippet.

## What is in the package

`SKILL.md` (~13 KB) always loads. It carries the priority order, operating rules, reconnaissance
list, and the per-topic policy on ownership, API design, errors and panics, unsafe, concurrency,
async, semver, hostile input, dependencies, testing, and performance.

The five references load on demand:

- `ownership-api-design.md` (~4.6 KB, 16 sections): ownership strategy, lifetimes, newtypes,
  typestate, trait design, generics against dynamic dispatch, errors, panics, Drop, `Pin`, async
  API shape, channels, public crate surface, iterators, macros.
- `unsafe-soundness-ffi.md` (~4.2 KB, 16 sections): the five-step unsafe proof template, raw
  pointers, aliasing, `MaybeUninit`, `transmute`, layout and ABI, manual `Send`/`Sync`, atomics,
  custom collections, the FFI boundary checklist, C strings, callbacks, shared memory.
- `verification-tooling.md` (~2.9 KB, 14 sections): which test layer fits which risk, property
  testing, fuzzing, Miri, sanitizers, Loom, compile-fail tests, lint policy, coverage, mutation
  testing, CI matrix.
- `performance-concurrency-portability.md` (~3.1 KB, 14 sections): measurement discipline,
  allocation sources, data layout, contention, async performance traps, SIMD dispatch, `no_std`,
  cross compilation, `build.rs`, native linking, ABI stability, benchmark integrity.
- `review-checklists.md` (~2.0 KB, 6 sections): review order, plus question lists for unsafe, API,
  concurrency, bug fixes, and a final completion gate.

## What this is opinionated about

- **Performance ranks eighth.** The skill publishes an explicit priority order: correctness,
  soundness, security, auditability, API clarity, deterministic failure, portability, then
  performance. Compile time, binary size, and implementation convenience come last.
- **A clean compile proves nothing.** "Do not treat 'the borrow checker accepts it' as proof that
  the program is correct" sits in the mission statement, and the completion gate repeats it.
- **Unsafe is a proof obligation, not a tool.** Eight questions must be answered before an
  `unsafe` block exists, every block gets a `SAFETY:` comment, every `unsafe fn` documents caller
  obligations under `# Safety`, and unsafe may never be used to quiet the borrow checker or chase
  speculative speed.
- **No unverified claims, ever.** Tools are only reported as passing if they ran. No measured data
  means no performance claim is allowed at all.
- **Reaching for `Arc<Mutex<T>>` is a smell.** Clones, allocations, boxing, `Arc`, locks, and
  dynamic dispatch are forbidden as ways to make code compile, and plain locks are preferred over
  lock-free structures unless a profile justifies the extra proof burden.

## Scope and depth

Be clear on what the references are. All five together come to about 17 KB against a 13 KB
`SKILL.md`, so the on-demand material is only marginally larger than the part that always loads.
They are dense decision checklists, not tutorials. The package contains no code examples and
exactly one shell command (`cargo metadata`), so nothing here teaches Rust or shows you how to
invoke a tool. You get a topic-by-topic list of the questions a careful reviewer would ask, useful
as a checklist and thin as a reference. For worked examples and real invocations, the
`c-programming-language` skill in this repo goes the other way at ten times the size per reference.

## Install

Copy this directory into wherever your agent loads skills from. No scripts, no dependencies.
