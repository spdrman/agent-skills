# Modular Official Guidance — New Mojo / MAX Project

> Integrated from Modular's official `new-modular-project` skill, Apache-2.0. Commands and release numbers are version-sensitive; verify current upstream/docs before relying on a snapshot.

## Gather Only Missing Choices

Infer what the user already specified.

Determine only the missing items:

- project name;
- Mojo versus MAX project;
- environment manager (`pixi` recommended by current Modular guidance, or `uv`);
- if `uv`, full project versus quick environment;
- stable versus nightly.

Do not ask again for information already stated or strongly implied.

Current upstream defaults new Mojo projects toward stable and MAX projects toward nightly when no channel preference is given. Re-check if upstream behavior changes.

## Tooling Direction

Current Modular guidance recommends **Pixi** and says not to use old `magic` workflows.

Mojo requires a C linker.

Current guidance says Windows users run Mojo through WSL2 rather than native Windows.

Verify platform support because this can change.

## Pixi

Current pattern for a stable Mojo project:

```bash
pixi init PROJECT \
  -c https://conda.modular.com/max/ -c conda-forge
cd PROJECT
pixi add mojo
pixi shell
```

Nightly uses Modular's nightly channel.

For Python dependencies, add Python and packages through Pixi/conda-forge or PyPI integration as appropriate.

## uv

Current nightly project pattern uses Modular's nightly Python index with prereleases enabled.

Stable MAX installs may use the `max[all]` extra, which pulls a compatible Mojo stack.

Do not blindly copy install commands from an old blog post; verify current official project guidance.

## pip

For nightly builds, current upstream guidance emphasizes using `--extra-index-url` rather than replacing PyPI entirely, because third-party dependencies may not exist on Modular's nightly index.

Stable MAX uses its current PyPI package/extras.

## Conda / Mamba

Current guidance supports Modular stable/nightly conda channels in addition to conda-forge.

## MAX / Mojo Version Alignment

When MAX uses custom Mojo kernels, install MAX and Mojo from the **same release channel**.

Do not assume their numeric version strings match; Modular numbers MAX and Mojo releases independently.

Prefer bundled/all dependency sets where Modular recommends them, because they keep compatible pairs aligned.

Mixing incompatible MAX and Mojo builds can produce kernel compilation failures.

## Reproducible Project Setup

After setup:

- record channel;
- record environment manager;
- capture lockfile;
- run `mojo --version`;
- if MAX is involved, record MAX package/version too;
- compile/run a minimal program;
- add project-specific test and format/build commands to README/CI.

## Version-Snapshot Warning

Official upstream project guidance contains concrete release numbers that become stale quickly. Treat numbers in any bundled snapshot as historical context unless current upstream/docs confirm them.
