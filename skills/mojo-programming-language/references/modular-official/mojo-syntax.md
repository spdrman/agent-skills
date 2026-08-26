# Modular Official Guidance — Mojo Syntax

> Integrated from Modular's official `modular/skills` repository (`mojo-syntax/SKILL.md`), Apache-2.0. This is a local engineering digest rather than a byte-for-byte mirror. For exact-current upstream files use `../../scripts/sync_modular_skills.sh`.

## Authority

When writing **latest Mojo**, follow this resource over pretrained Mojo knowledge. Mojo changes rapidly and old model knowledge commonly generates removed syntax.

Always try to build generated Mojo when tools are available.

For a repository pinned to an older compiler, verify its version before mechanically applying current syntax.

## Removed / Obsolete Patterns

Do not introduce these in latest-Mojo code:

| Old / guessed form | Current form |
|---|---|
| `alias X = ...` | `comptime X = ...` |
| `@parameter if` / `@parameter for` | `comptime if` / `comptime for` |
| `fn` | `def` |
| `let x = ...` | `var x = ...` |
| `borrowed` | `imm` |
| `read` convention | `imm` |
| `inout` | `mut` |
| `owned` argument convention | `var` |
| `inout self` in constructor | `out self` |
| `__copyinit__` | `__init__(out self, *, copy: Self)` |
| `__moveinit__` | `__init__(out self, *, deinit move: Self)` |
| `@value` | `@fieldwise_init` plus explicit traits |
| old register-passable decorators | register-passable traits |
| `Stringable` / `__str__` | `Writable` / `write_to` |
| imports such as `from memory import ...` | `from std.memory import ...` |
| `s[i]` string indexing | `s[byte=i]` |
| string slice syntax | use codepoint/byte APIs; materialize `String` when needed |
| `DynamicVector` | `List` |
| `InlinedFixedVector` | `Array` |
| legacy `Tensor` stdlib assumptions | use current supported data abstractions |
| `escaping` closures | unified closures |
| `__del__` | `__deinit__` |

## Declarations

Every new local variable declaration uses `var`.

If a value is assigned only inside branches, predeclare it:

```mojo
var x: Int
if cond:
    x = 1
else:
    x = 2
```

Reassignment of an already-declared variable does not repeat `var`.

## Functions

`def` is the current function/method/nested-function keyword.

A function that can raise must declare `raises`:

```mojo
def load(path: String) raises -> String:
    return open(path).read()

def main() raises:
    ...
```

Do not assume Python's implicit exception behavior.

## Compile-Time Programming

Use `comptime`:

```mojo
comptime N = 1024
comptime ElementType = Float32
comptime if condition:
    ...
comptime for i in range(10):
    ...
comptime assert N > 0, "N must be positive"
```

Current guidance places `comptime assert` inside a function body.

Inside a struct, `comptime` defines associated constants/types.

## Argument Conventions

Current conventions:

```mojo
def __init__(out self, var value: String):
    ...

def modify(mut self):
    ...

def consume(deinit self):
    ...

def view(ref self) -> ref[self] Self.T:
    ...
```

- `imm` is the immutable convention and is usually implicit.
- `mut` is mutable borrowing.
- `var` in argument position takes ownership where applicable.
- `ref` carries origin information.
- `out` initializes uninitialized output.
- `deinit` consumes/destroys.

Do not use `var` or `ref` as identifiers; they are hard keywords.

## Lifecycle

Current lifecycle shape:

```mojo
def __init__(out self, x: Int):
    self.x = x

def __init__(out self, *, copy: Self):
    self.data = copy.data

def __init__(out self, *, deinit move: Self):
    self.data = move.data^

def __deinit__(deinit self):
    self.ptr.free()
```

`Copyable` supplies `.copy()` when its requirements are met.

Do not make unique resources copyable without valid copy semantics.

## Structs and Traits

Use `@fieldwise_init` for generated fieldwise constructors where appropriate.

Traits are declared in the struct conformance list.

Trait composition uses `&`.

Inside parametric structs, current syntax requires self-qualification of struct parameters (`Self.T`, `Self.N`, etc.) throughout fields and methods.

Non-`ImplicitlyCopyable` values need explicit `.copy()` or transfer `^` when ownership changes.

## Imports

Explicit stdlib imports use `std.`:

```mojo
from std.testing import assert_equal, TestSuite
from std.algorithm import vectorize
from std.python import PythonObject
import std.random
```

Many fundamental types/functions are available from the prelude.

Do not create a module-level identifier named `std`.

## Writable

Current textual-output protocol is `Writable` / `Writer`.

Use `String(value)` to materialize a `String`, not Python-style `str(value)` assumptions.

T-strings provide interpolation for writer-style output.

## Iterators

Current iterator protocol uses `raises StopIteration`.

For mutable element access, current for-loop syntax may use `for ref item in collection`.

Verify exact trait signatures against the pinned compiler because iterator APIs remain version-sensitive.

## Memory / Pointer Types

Current syntax guidance distinguishes:

- `Pointer[T, mut=M, origin=O]`: safe non-nullable pointer/reference abstraction.
- `Span(...)`: non-owning contiguous view.
- `OwnedPointer[T]`: unique ownership.
- `ArcPointer[T]`: reference-counted shared ownership.
- `alloc[T](count)` returning an unsafe pointer requiring `.free()`.

Unsafe pointer fields require explicit origins. Current guidance uses untracked origins for owned heap storage where appropriate.

Unsafe pointers are non-null by design in current guidance. For nullable storage use `Optional[...]` rather than a null-value pointer convention.

## Origins

Mojo tracks reference provenance through **origins**, not Rust lifetime syntax.

Important concepts include mutable/immutable, any/untracked/static origins and `origin_of(value)`.

Origins constrain provenance/mutability. They do **not** prove buffer bounds.

## Testing

Current official guidance says the old `mojo test` CLI subcommand is removed.

Use a test runner such as:

```mojo
from std.testing import assert_equal, TestSuite

def test_feature() raises:
    assert_equal(compute(2), 4)

def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
```

Run the test file with `mojo run`.

For older pinned projects, use their canonical runner.

## Collections

Use bracket literals for `List`, not guessed variadic constructors.

Dict iteration exposes entries directly; do not assume an extra pointer dereference layer.

Negative indexing support is type/API-specific; current `List` guidance rejects `lst[-1]`.

## Variant Access

With non-implicitly-copyable variant arms, avoid operations that accidentally copy the whole variant. Prefer typed-arm reference access and explicit copy/transfer when needed.

## Common Decorators

Current relevant decorators include:

- `@fieldwise_init`
- `@implicit`
- `@always_inline`
- `@no_inline`
- `@staticmethod`
- `@deprecated`
- `@doc_hidden`
- `@explicit_destroy`

Use them only when their semantic contract is justified.

## Numeric Conversions

Numeric **variables** require explicit conversions between numeric types.

Numeric literals are polymorphic and adapt to context.

Do not litter code with unnecessary literal casts merely because variable conversions are explicit.

## SIMD

Current `SIMD` supports lane access, casts, reductions, clamps, mask selection, etc.

Do not guess method names from NumPy/CUDA. For example, current guidance treats `min`/`max` as free functions.

## Strings

Mojo strings are UTF-8.

- `byte_length()` measures bytes.
- `count_codepoints()` counts code points.
- byte indexing uses `s[byte=i]`.
- many slicing/splitting operations yield `StringSlice` views.
- wrap with `String(...)` when ownership/materialization is required.
- iterate codepoint slices/codepoints rather than relying on deprecated direct character iteration.

Never equate byte length with Unicode character count.

## Errors

`raises` may name a type. `try`/`except` is supported.

Do not generate a `match` statement based on Rust/Python expectations unless current Mojo introduces one and the pinned compiler supports it.

## Async

Current Modular guidance considers Mojo async support unfinished even though some async syntax parses. Do not write async Mojo production code unless the pinned toolchain/project explicitly supports the required public APIs.

## Closures

Mojo has no Python lambda syntax.

Prefer unified closure values with explicit capture lists:

```mojo
def closure(i: Int) {mut count, imm ptr, var x}:
    ...
```

Capture intent matters:

- `imm`: borrowed/read-only capture.
- `mut name`: mutable captured origin.
- `var name`: owned/copy capture where supported.
- transfer from owned capture uses `^` at the use site.

Do not add `@__parameter` / `@parameter` to nested closures. If an old API still requires a parametric capturing closure, use the form that the pinned API actually requires or migrate the API; do not reintroduce deprecated decorators as a workaround.

## Type Semantics

Know whether a type is:

- deinitializable;
- movable;
- copyable;
- implicitly copyable;
- register-passable;
- trivial/register-passable.

These traits affect transfer, closure capture, ABI, and generated code. Never add conformance merely to bypass a compiler diagnostic.
