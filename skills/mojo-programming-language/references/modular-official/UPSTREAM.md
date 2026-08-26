# Upstream Modular Skills Provenance

This directory incorporates and adapts the Mojo-facing agent guidance from:

- Repository: https://github.com/modular/skills
- Publisher: Modular
- Branch reviewed: `main`
- Review date: 2026-08-25
- License: Apache License 2.0

Upstream skills incorporated:

1. `mojo-syntax/SKILL.md`
2. `mojo-gpu-fundamentals/SKILL.md`
3. `mojo-python-interop/SKILL.md`
4. `new-modular-project/SKILL.md`
5. `closure_migration/SKILL.md`
6. `closure_migration/process.md`

These bundled Markdown files are integrated engineering digests so they can coexist under one broader Mojo expert skill without creating six independently-triggered skill roots.

They are **not guaranteed byte-for-byte mirrors** of upstream. Mojo changes quickly.

For an exact current snapshot, run:

```bash
./scripts/sync_modular_skills.sh
```

The script downloads the upstream files into:

```text
references/modular-official/upstream/
```

When exact upstream files exist there, prefer them for latest syntax/API corrections. Preserve the broader engineering/review requirements of the top-level `SKILL.md`.

## License

The upstream Modular repository is Apache-2.0 licensed. A copy of the Apache 2.0 license is included as:

`LICENSE-Modular-Skills-Apache-2.0.txt`

Modifications/adaptations in this package are not represented as official Modular content.
