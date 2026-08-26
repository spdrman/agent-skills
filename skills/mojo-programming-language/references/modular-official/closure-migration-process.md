# Unified Closure Migration — Detailed Process

> Local integrated playbook derived from Modular's `closure_migration/process.md`, Apache-2.0.

## 1. Inventory

Search all relevant Mojo code for:

```bash
rg 'api_name\[' --glob '*.mojo'
rg 'api_name\(' --glob '*.mojo'
rg '@__parameter|@parameter|@__copy_capture' --glob '*.mojo'
```

Separate:

- parametric call sites;
- already value-taking call sites;
- API definitions;
- nested closures;
- copy-capture use.

Do not bulk-edit until each API's intended value-taking argument order is known.

## 2. Rewrite Calls

Transform only according to the actual overload:

```text
api[NAME](a, b) -> api(a, NAME, b)
```

The order is API-specific.

Do not assume the closure always becomes the final argument.

## 3. Rewrite Closure Declarations

For every migrated nested closure:

- remove `@__parameter` / `@parameter`;
- migrate `@__copy_capture`;
- keep legitimate unrelated decorators;
- add a unified capture list.

Capture examples:

```mojo
def f(...) {imm}:
    ...

def f(...) {mut output, imm}:
    ...

def f(...) {var index, imm}:
    ...
```

Copy-captured runtime names should become `var` captures rather than borrowed `imm` captures.

Comptime parameters do not need runtime capture entries.

## 4. Diagnose by Error Class

### Capturing-thin cannot convert to unified FuncType

Cause: the closure is still legacy parametric.

Fix: remove legacy parameter decorator and give it the correct unified capture list.

### Could not infer capture convention

Cause: free runtime variables exist without a capture list.

Fix: choose `imm`, named `mut`, named `var`, or an empty list if no captures exist.

### Expression must be mutable

Cause: closure borrowed a value as immutable but mutates it.

Fix: mark the specific origin `mut` or move the mutation to an explicit argument/local.

### Register-passable value cannot be mut captured

Cause: capture-all `mut` also captured an `Int`/similar scalar.

Fix: use named mutable captures plus trailing `imm`, not `{mut}`.

### Mutable pointer/tensor expects mutable origin

Cause: an `imm` capture froze a buffer used to build mutable output/view state.

Fix: capture the specific backing buffer as `mut` if ownership is genuinely exclusive.

### Aliasing origin diagnostic

Cause: closure representation would store both mutable and immutable/multiple mutable paths into the same origin.

Fix order:

1. make the use immutable if possible;
2. extract/disassemble independent fields;
3. pass the mutable buffer/origin as a function argument.

Do not erase origin information.

## 5. Preserve Benchmark Semantics

For benchmark migrations:

- construct layouts/buffers where they were before;
- do not move allocation into timed code;
- do not move compile-time branch allocations to common scope;
- do not introduce copies to satisfy captures;
- do not introduce DeviceBuffer wrappers to obscure aliasing.

Capture refactors must not contaminate the measurement.

## 6. GPU-Specific Closure Checks

When a captured buffer is used to:

- create a mutable `TileTensor`;
- obtain a mutable unsafe pointer;
- act as a kernel output;
- call a helper that internally requires mutable pointer access;

the capture may need to be named `mut`.

But if the same origin is also captured through another view, redesign capture/arguments instead of forcing unsafe casts.

## 7. Compile Early

After a coherent set of rewrites, compile/typecheck the smallest relevant target.

The official process uses LLVM emission as a useful typecheck path in environments where normal compilation produces unrelated backend noise.

Use the project's canonical commands when they differ.

## 8. Search After Migration

Re-run searches for:

- parametric call form;
- `@__parameter`;
- `@parameter`;
- obsolete copy-capture;
- unsafe-origin casts added during the migration.

Zero legacy decorators should remain on nested closures that were migrated.

## 9. Delete Old Overloads Last

Only remove parametric overloads after:

- migrated callers compile;
- tests pass;
- benchmark semantics remain unchanged.

This keeps failures attributable and allows staged migration.

## 10. Regression Tests

Add regression coverage for:

- closure invoked correctly;
- mutable captures change intended state;
- copied captures do not alias later mutation;
- GPU buffer captures launch without alias diagnostics;
- error paths preserve resource semantics.

## 11. Review Questions

- Did any `imm` capture replace a semantic copy?
- Did any `mut` capture include unrelated scalar values?
- Did any workaround erase origin information?
- Did allocation/copy placement change?
- Did a closure become compile-time again through a legacy decorator?
- Was a GPU output buffer captured through more than one alias?
- Is the new API value-taking end-to-end?
