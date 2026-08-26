# agent-skills

Three Agent Skills for systems programming languages: C, Mojo, and Rust.

Each is a self-contained package in the standard `SKILL.md` + `references/`
format, so the top-level file always loads and the deep material is pulled in
only when the work actually calls for it.

| Skill | SKILL.md | References | Code blocks | Shape |
| --- | --- | --- | --- | --- |
| [`c-programming-language`](skills/c-programming-language) | 373 lines | 4 files, 2,402 lines, 184 KB | 112 | Worked examples and real tool invocations |
| [`mojo-programming-language`](skills/mojo-programming-language) | 399 lines | 12 files, 1,519 lines, 48 KB | 40 | Current-syntax guidance plus Modular-derived material |
| [`rust-programming-language`](skills/rust-programming-language) | 279 lines | 5 files, 372 lines, 16 KB | 0 | Dense decision checklists |

The three are not the same size or the same kind of thing, and each README says
so plainly. The C package is a reference you can read; the Rust package is a
review checklist for a model that already knows Rust; the Mojo package exists
mostly because pretrained knowledge of Mojo is now wrong, so it puts current
syntax in front of the model's reflex.

## Install

Copy the skills you want into your agent's user skills directory:

```bash
git clone https://github.com/spdrman/agent-skills.git
cp -R agent-skills/skills/c-programming-language ~/.claude/skills/
```

**Claude Code** reads `~/.claude/skills/` directly and picks them up on the next
session.

**Oh My Pi (`omp`)** discovers the same directory. Check that it is enabled:

```bash
omp config get skills.enabled           # true
omp config get skills.enableClaudeUser  # true
```

One copy in `~/.claude/skills/` therefore serves both, and a second copy is only
drift waiting to happen. `omp` also reads Codex and Pi skill directories, and
`skills.customDirectories` takes additional paths if you keep them elsewhere.

For a project-local skill rather than a user-level one, put the directory under
`.claude/skills/` in the repository instead.

## What these are for

They change what an agent does around the code more than they change the code
itself: establish the dialect and toolchain before writing anything, state the
contract and invariants first, enumerate failure modes rather than discovering
them, and refuse to report a test, sanitizer, or benchmark as passing unless it
actually ran. Each package carries its own priority order, and in all three
performance sits well below correctness.

## Licence

MIT for the original work here, see [LICENSE](LICENSE).

`skills/mojo-programming-language/references/modular-official/` contains
condensed derivatives of material from
[modular/skills](https://github.com/modular/skills), which is distributed under
the Apache License 2.0 with LLVM Exceptions. The Apache terms travel with those
files and the MIT grant above does not override them. See that skill's
[README](skills/mojo-programming-language/README.md) for the full attribution.
Nothing here is official Modular content or endorsed by Modular.
