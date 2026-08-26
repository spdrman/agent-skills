# c-programming-language

An Agent Skill that makes a coding agent treat C as a language where correctness
depends on proving facts the type system does not prove. Instead of writing
plausible C and moving on, the agent establishes the contract, writes down the
invariants, enumerates the failure modes, and only then implements. It refuses
to reach for undefined behaviour as a technique, and it will not call work
complete while material correctness is merely assumed.

## When it triggers

Writing, reviewing, debugging, optimising, testing, fuzzing, porting, hardening,
or profiling C. Also C APIs and ABI/FFI boundaries, embedded and systems code,
parsers, storage engines, runtimes, OS interfaces, and performance-critical
native libraries, or any repository with substantial C in it.

## Layout

`SKILL.md` (373 lines) carries the operating rules, the priority order, the
design-before-code procedure, and the review, bug-fix and new-code procedures.
It loads references on demand rather than up front, so only the relevant depth
enters context.

| Reference | Lines | Covers |
| --- | --- | --- |
| `references/c-correctness.md` | 602 | Memory safety, integers, pointers, allocation, strings, API design, state machines, concurrency, parsing untrusted input, persistence and durability, security, FFI |
| `references/verification.md` | 678 | Testing, assertions, fault injection, fuzzing, sanitizers, coverage, mutation testing, static analysis, release verification |
| `references/performance-portability.md` | 766 | Portability, ABI stability, build/target separation, compiler matrices, profiling, benchmarking, optimization |
| `references/review-checklists.md` | 356 | Code review, bug-fix, new-module, and completion gates |

Every reference delivers on what `SKILL.md` says it covers, section by section.

## What this is opinionated about

**Correctness is not tradeable against speed on intuition.** The priority order
is explicit and performance sits eighth of nine, below portability and API
stability. Optimisation happens after measurement or it does not happen.

**Undefined behaviour is rejected as a design technique, not merely avoided.**
The performance reference spells out the mechanism: dereferencing a pointer
lets the compiler delete the null check below it, and signed overflow being
undefined is why `x + 1 > x` folds to `true`. An optimisation result measured on
code that is UB-free only by accident means nothing.

**Assertions state programmer invariants and never validate hostile input.**
`assert(X)` means X is believed proven. Release builds must stay safe when
assertions compile out, which is a different question from whether the debug
build catches the bug.

**Failure paths get exercised, not just written.** For reliability-critical
code, deliberately fail the Nth allocation or I/O call and iterate N across the
operation, checking for leaks, corrupted state, double release and correct
propagation. The sweep terminates on "injection point not reached", not on
success, or it stops early and leaves sites untested.

**A later null check is not a fix for memory corruption** unless null is itself
a valid recoverable state. The bug-fix procedure asks whether the visible
failure is a symptom of earlier corruption before anything is changed, and
requires a regression test that fails on the old code.

**Boring, explicit C over clever C**, including `goto cleanup` where a single
cleanup path makes error handling more obviously correct than nesting or
duplication would.

## Install

Copy the directory into your agent's user skills directory:

```bash
cp -R skills/c-programming-language ~/.claude/skills/
```

Claude Code reads `~/.claude/skills` directly. Oh My Pi (`omp`) discovers the
same directory when `skills.enableClaudeUser` is set, so one copy serves both.
