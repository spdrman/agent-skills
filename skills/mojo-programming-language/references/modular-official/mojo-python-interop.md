# Modular Official Guidance — Mojo / Python Interoperability

> Integrated from Modular's official `mojo-python-interop` skill, Apache-2.0. Use together with `mojo-syntax.md`.

## Calling Python from Mojo

Current guidance uses:

```mojo
from std.python import Python, PythonObject

var np = Python.import_module("numpy")
var arr = np.array([1, 2, 3])
```

Treat `PythonObject` as a dynamic Python value. Attribute access, indexing, arithmetic, iteration, and method calls generally remain Python operations and return `PythonObject`.

Do not prematurely convert every intermediate value to a Mojo type.

## Conversions

Use explicit current conversions such as `String(py=obj)` or numeric constructors with `py=` when materializing Python values into Mojo values.

Conversion is a semantic and performance boundary. Determine whether it copies.

## Python Exceptions

Python exceptions propagate into Mojo error handling. Functions that call raising Python operations must be marked `raises`.

Catch only when the Mojo layer can add context, translate, or recover.

Do not silently convert every Python exception into a generic success/fallback.

## Python Evaluation

Current APIs can evaluate Python expressions/code and adjust the Python import path.

Use this deliberately. Prefer native Mojo/stdlib functionality when it exists instead of invoking Python for simple operations.

Example principle from official guidance: use Mojo's native environment-variable facilities rather than importing Python `os` merely to read environment variables.

## Lambdas

Mojo does not have Python lambda syntax.

If a Python API needs a Python callable, a Python callable can be created/evaluated on the Python side.

Do not invent Mojo `lambda`.

## Performance Boundary

Keep Python out of inner hot loops unless profiling proves acceptable.

Batch:

- calls;
- conversions;
- boxing/unboxing;
- host/device transitions.

Avoid repeated per-element cross-language traffic.

## Building Python Extension Modules

Current official guidance uses `PythonModuleBuilder` and a C-ABI `PyInit_<module>` export.

The module initializer must match Python extension naming rules.

The initializer should contain failure handling appropriate for a C ABI boundary; do not allow uncontrolled Mojo error propagation across the initialization ABI.

Functions exposed to Python generally accept/return `PythonObject` or use supported binding conversions.

## Bound Mojo Types

Current bindings can expose Mojo structs as Python types.

Define:

- Python constructor behavior;
- method registration;
- storage/ownership;
- conversion;
- destruction.

Two current method-binding patterns include:

1. manual PythonObject downcast to a Mojo value pointer;
2. supported auto-downcast pointer forms.

Use only signatures supported by the pinned toolchain.

## Keyword Arguments

Current binding facilities support Python kwargs using compatible string-keyed dictionary types.

Validate/convert user values explicitly.

## Importing Mojo from Python

Current official guidance supports `mojo.importer`:

```python
import mojo.importer
import my_module
```

It compiles/caches `.mojo` modules for Python import.

Current guidance notes:

- cache artifacts live under a Mojo cache directory;
- the `PyInit_<name>` module name must match the module filename;
- a Mojo source built as a shared library/importable module must not also contain a CLI `main()`.

Keep CLI/test entry points in separate source files.

## Returning Owned Mojo Values to Python

When Python becomes the owner of a Mojo allocation/value, use the supported ownership-transfer APIs deliberately.

Do not leave both sides believing they own the same allocation.

When later recovering a Mojo value from a bound Python object, verify the exact downcast/value-pointer contract.

## GIL / Runtime Assumptions

Do not invent CPython GIL semantics for Mojo bindings. Verify current binding/runtime documentation when threading matters.

Treat callback threads and Python runtime state as explicit integration constraints.

## Interop Review Gate

Verify:

- Python dependency/environment known;
- functions using Python are `raises`;
- conversions are explicit where needed;
- copy/share semantics understood;
- Python exceptions are intentionally propagated/translated;
- hot loops do not bounce across the boundary unnecessarily;
- `PyInit_` name matches module;
- no `main()` in a shared-library module;
- Mojo values transferred to Python have one clear owner;
- bound type method signatures match the pinned Mojo version.
