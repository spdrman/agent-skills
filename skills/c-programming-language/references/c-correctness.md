# C Correctness Reference

Rules and failure modes for writing C that does not silently corrupt state or hand an attacker a primitive.
Consult mid-task; sections follow the topic order in `SKILL.md`. Testing, sanitizers, performance, portability, ABI, and review checklists live in the sibling references.

## Behavior Categories

Conflating these three changes what you are allowed to rely on. Establish which one applies before writing "it works on our compiler."

| Category | Standard's requirement | What you may rely on | Representative examples |
| --- | --- | --- | --- |
| **Undefined** | None whatsoever. The compiler may assume it never happens and optimize on that assumption, including backwards past the offending statement. | Nothing. Not even "it crashes." | Signed overflow; out-of-bounds access; use-after-free; data race; strict-aliasing violation; unsequenced modification; misaligned access; shifting by >= width; `realloc(p,0)` (C23); reading an object through the wrong effective type |
| **Implementation-defined** | The implementation must choose and **document** a behavior. | The documented choice, once you have read the documentation for every target in your matrix. | `char` signedness; `sizeof(int)`, `sizeof(long)`; right shift of a negative value (pre-C23); pointer↔integer conversion; whether `malloc(0)` returns `NULL`; bit-field allocation order and straddling; number of bits in a byte (`CHAR_BIT`) |
| **Unspecified** | Two or more behaviors are permitted; no documentation is required and the choice may differ per occurrence, per optimization level, per call site. | Only that *some* listed alternative happens. Never a particular one. | Order of evaluation of function arguments and of most subexpressions; values of padding bytes; whether identical string literals are distinct objects; whether a one-past-the-end pointer compares equal to a pointer to a different object |

Consequences that surprise people:

- UB propagates backwards. `int x = *p; if (p) {...}` licenses deleting the null check, because the dereference already asserted `p != NULL`.
- UB propagates forwards. `for (int i = 0; i <= n; i++)` lets the compiler assume `i` never overflows and therefore that the loop terminates — the loop bound can be strength-reduced or the trip count computed in a wider type.
- Optimization level changes symptoms, not correctness. Strict-aliasing and signed-overflow violations very often behave "fine" at `-O0` and miscompile at `-O2`.
- `-fwrapv`, `-fno-strict-aliasing`, `-fno-delete-null-pointer-checks` (GCC/Clang) do not fix UB; they change the dialect you are writing. If a codebase depends on them, that dependency belongs in the build files *and* in a comment, and portable code must not assume them.

C11 6.8.5p6 (unchanged in C17/C23): an iteration statement whose controlling expression is **not a constant expression**, and which performs no I/O, no `volatile` access, and no synchronization or atomic operation, may be assumed to terminate. `while (1) { }` is a constant expression and is therefore explicitly permitted; `while (x) { }` with a non-`volatile` `x` is not.

Reading an object with an indeterminate value: DR 451 makes it clear the value may be "wobbly" — two reads of the same uninitialized object may yield different values. If the object could have been declared `register` (its address is never taken), the read is plainly UB. Treat every read of an uninitialized object as UB.

## Memory Safety

### Object lifetime

Every pointer has three attributes you must be able to name: the object it points into, the bounds of that object, and the end of that object's lifetime.

- Automatic objects die at the end of their block. Returning `&local`, or storing it in a longer-lived structure, is UB — including a compound literal, whose lifetime is the enclosing block, not the enclosing expression.
- After `free(p)`, the *value* of `p` is indeterminate. Reading it, comparing it, or printing it is UB, not just dereferencing it. Null it out or let it go out of scope immediately.
- Same for the old pointer after a successful `realloc` that moved the block, and for any interior pointers into it.
- Modifying a string literal is UB. Declare them `const char *`.
- Casting away `const` and writing is UB **if the object was defined `const`**; if it merely arrived through a `const`-qualified pointer to a non-`const` object, the write is defined but almost always a design error.

### Bounds and one-past-the-end

- Forming `p + n` is defined only if the result points into the same array object or exactly one past its end. Overflow past that is UB even if you never dereference. A single object counts as an array of one for this purpose.
- Dereferencing the one-past-the-end pointer is UB.
- Relational comparison (`<`, `>`, `<=`, `>=`) of pointers that do not point into the same array object (or one past its end) is UB (C11 6.5.8p5). Equality comparison of unrelated pointers is defined, but whether a one-past-the-end pointer equals a pointer to a distinct adjacent object is unspecified.

Because of the first rule, "check the pointer after advancing it" is broken:

```c
/* WRONG: p + n is already UB when n exceeds the remaining bytes. */
if (p + n > end) return E_TRUNC;

/* RIGHT: subtract inside the object, compare in size_t.
   Requires the invariant p <= end, which the caller must establish. */
if (n > (size_t)(end - p)) return E_TRUNC;
```

Pointer subtraction yields `ptrdiff_t`. If the difference is not representable in `ptrdiff_t`, the result is UB — reachable on 32-bit targets with a single allocation larger than `PTRDIFF_MAX` bytes, which is why glibc's `malloc` refuses such requests.

### Alignment

- Accessing an object through a pointer that is not correctly aligned for its type is UB (C11 6.3.2.3p7). On x86 you usually get away with it; on strict-alignment targets you get a bus error, and on any target the compiler may vectorize on the assumption of alignment.
- `_Alignof` / `_Alignas` (C11; spelled `alignof` / `alignas` via `<stdalign.h>` in C11, and as keywords in C23).
- `max_align_t` is the alignment `malloc` guarantees. `malloc` returns memory suitably aligned for *any* object type whose size does not exceed the request.
- Over-aligned allocation: `aligned_alloc` (C11), `posix_memalign` (POSIX; returns an errno value, does **not** set `errno`, returns 0 on success), `_aligned_malloc` (MSVC — must be released with `_aligned_free`, never `free`; MSVC does not provide `aligned_alloc`). C11's `aligned_alloc` requires `size` to be an integral multiple of `alignment`; mainstream libcs do not enforce it, but portable code should satisfy it.

### Effective type and strict aliasing

C11 6.5p7: an object's stored value may be accessed only through an lvalue of a compatible type, a qualified or signed/unsigned variant of it, an aggregate or union containing such a type, or **a character type**. Everything else is UB.

```c
/* WRONG: the object's effective type is float; reading it as uint32_t is UB. */
uint32_t bits = *(uint32_t *)&f;

/* RIGHT: memcpy is the portable pun. Compilers lower this to a register move. */
uint32_t bits;
memcpy(&bits, &f, sizeof bits);
```

Three legitimate ways to reinterpret bytes, in decreasing portability:

1. `memcpy` between typed objects. Always defined provided sizes match and neither object has trap representations you then read.
2. **Union punning.** Reading a union member other than the last one written is explicitly permitted in C (C11 6.5.2.3 footnote 95; C99 TC3 added the same footnote). This is a real difference from C++, where it is formally UB. The bytes are reinterpreted; you can still read a trap representation.
3. `unsigned char` access. `unsigned char` is guaranteed to have no padding bits and no trap representations, which is why it is the byte type. Plain `char` and `signed char` are permitted for aliasing too but `char` signedness is implementation-defined.

Effective type of allocated storage (C11 6.5p6): storage from `malloc` has no declared type. It acquires the effective type of the lvalue used to store into it. Crucially, **if a value is copied in with `memcpy`/`memmove` or as an array of character type, the destination inherits the effective type of the source object**, if the source had one. So `memcpy(buf, &some_struct, sizeof some_struct)` makes `buf` hold an object of that struct type; a later access as an unrelated type is still UB.

`restrict` (C99, 6.7.3.1) is a promise you make to the compiler, not a check it performs. For an object accessed through a `restrict`-qualified pointer `P` in a block, if the object is *modified* anywhere in that block, then every access to that object in that block must be through a pointer based on `P`. Violation is UB with no diagnostic. Only add `restrict` where you can state why no other pointer reaches the same bytes; the classic violation is a "copy" routine given overlapping ranges by one caller in a thousand.

### Sequence points and unsequenced modification

C11 replaced the sequence-point wording with sequenced-before / indeterminately-sequenced / unsequenced, but the rule is unchanged in effect: if a scalar object is modified twice, or modified and independently read, with no sequencing between the operations, the behavior is undefined.

```c
i = i++;            /* UB */
a[i] = i++;         /* UB */
f(i++, i++);        /* UB: argument evaluations are unsequenced */
x = f() + g();      /* NOT UB even if f and g touch the same global:
                       function calls are indeterminately sequenced, i.e.
                       one runs entirely before the other. The ORDER is
                       unspecified, so the result may still be either value. */
```

`&&`, `||`, `?:`, and `,` introduce sequencing. Assignment in C11 sequences the value computations of both operands before the store, but does *not* sequence the store relative to other unsequenced side effects.

### Flexible array members

```c
struct msg {
    uint32_t      len;
    unsigned char data[];    /* C99 6.7.2.1p18 */
};
```

- `sizeof(struct msg)` ignores `data` but may include trailing padding. Allocate `sizeof(struct msg) + len` (conservative, always correctly sized) or `offsetof(struct msg, data) + len` (exact, and still correctly aligned). Check the addition for overflow.
- A struct with a flexible array member must not be a member of another struct or an element of an array (C11 6.7.2.1p3). Nesting it as a trailing member is a GCC extension, not standard C.
- Do not use the pre-C99 `data[1]` idiom in new code; it lies to the compiler about the bound and to sanitizers about the object size.
- `offsetof` is in `<stddef.h>` and is not defined for bit-field members.

## Integers

### Promotion and the usual arithmetic conversions

1. **Integer promotion.** Any operand of a type with rank lower than `int` (`char`, `signed char`, `unsigned char`, `short`, `unsigned short`, `_Bool`, bit-fields narrower than `int`) is converted to `int` if `int` can represent all its values, otherwise to `unsigned int`. This happens in every arithmetic expression and in variadic argument passing.
2. **Usual arithmetic conversions**, after promotion: same signedness → convert to the higher rank. Otherwise, if the unsigned operand's rank is >= the signed operand's rank → the signed operand converts to unsigned. Otherwise, if the signed type can represent every value of the unsigned type → the unsigned operand converts to signed. Otherwise both convert to the unsigned counterpart of the signed type.

The trap this creates:

```c
uint16_t a = 0xFFFF, b = 0xFFFF;
uint32_t c = a * b;          /* WRONG on 32-bit int: a and b promote to int,
                                0xFFFF*0xFFFF == 4294836225 > INT_MAX,
                                signed overflow, UB. */
uint32_t c = (uint32_t)a * b;   /* RIGHT: force the wide unsigned type first. */
```

And the signed/unsigned comparison trap:

```c
int i = -1;
if (i < sizeof(buf)) { ... }    /* i converts to size_t: 0xFFFF...FF. Never taken. */
if (i >= 0 && (size_t)i < sizeof(buf)) { ... }   /* RIGHT */
```

Compile with `-Wsign-compare` / `-Wconversion` and treat the hits as findings, not noise. Prefer to keep sizes, lengths, indices, and counts in one unsigned type (`size_t`) throughout a module, and convert once at the edges with an explicit range check.

### Overflow, wraparound, and conversion

| Operation | C99 / C11 / C17 | C23 |
| --- | --- | --- |
| Signed arithmetic overflow | **Undefined** | **Undefined** (unchanged) |
| Unsigned arithmetic overflow | Defined: modulo 2^N | Same |
| Converting an out-of-range value to a signed type | Implementation-defined; may raise an implementation-defined signal (6.3.1.3p3) | Two's complement mandated; conversion is modular reduction |
| `E1 << E2`, `E2 >= width(E1)` or `E2 < 0` | **Undefined** | **Undefined** |
| `E1 << E2`, `E1` signed and result not representable | **Undefined** | Defined as the two's-complement bit shift |
| `E1 >> E2`, `E1` signed and negative | Implementation-defined (every mainstream target: arithmetic shift) | Arithmetic shift |
| `INT_MIN / -1`, `INT_MIN % -1` | **Undefined** (overflow) | **Undefined** |
| Division or `%` by zero | **Undefined** | **Undefined** |

Note that C23's two's-complement mandate fixes *conversion* and *shifts*, not *arithmetic overflow*. `INT_MAX + 1` is still UB in C23.

Shift width is the width of the **promoted left operand**, so `1 << 40` is UB on a 32-bit `int` regardless of the destination type. Write `UINT64_C(1) << 40` or `1ull << 40`.

### Checked arithmetic

```c
/* Portable. Works for any unsigned type; specialize per type or use a macro. */
static bool size_mul(size_t a, size_t b, size_t *out) {
    if (a != 0 && b > SIZE_MAX / a) return false;
    *out = a * b;
    return true;
}
static bool size_add(size_t a, size_t b, size_t *out) {
    if (a > SIZE_MAX - b) return false;
    *out = a + b;
    return true;
}
```

- GCC/Clang: `__builtin_mul_overflow(a, b, &out)` / `_add_` / `_sub_` — type-generic, returns `true` on overflow, works for signed types where the portable trick does not.
- C23: `<stdckdint.h>` gives `ckd_mul`, `ckd_add`, `ckd_sub` with the same convention.
- Never detect signed overflow by performing it (`if (a + b < a)` on `int` is itself UB). Check before, or compute in a wider type, or use the builtins.

### Type choices

- `size_t` — object sizes, byte counts, array indices, anything returned by `sizeof`. Unsigned; `SIZE_MAX` in `<stdint.h>`.
- `ptrdiff_t` — the type of a pointer difference. Signed. Use it for signed offsets and for loop variables that must go negative; do not use it as a size.
- `uintptr_t` / `intptr_t` — optional types (`<stdint.h>`) large enough to round-trip a `void *`. The round trip `void* → uintptr_t → void*` is defined; arithmetic on the integer and converting back is not guaranteed to give a usable pointer.
- `intmax_t` / `uintmax_t` — widest standard integer types; note that C23 deprecates growing them and that extended types may exceed them.
- Fixed-width `intN_t` are optional (present only if the implementation has such a type with no padding and two's complement); `int_leastN_t` and `int_fastN_t` are mandatory. For file and wire formats require the exact-width types and `#error` if absent.
- Print with `<inttypes.h>` macros: `printf("%" PRIu64, v)`. Never assume `%lu` matches `uint64_t`.
- Plain `char` signedness is implementation-defined. For bytes use `unsigned char`. For `<ctype.h>` always cast: `isspace((unsigned char)c)` — passing a negative value other than `EOF` is UB.
- `_Bool` holds only 0 or 1. Writing any other bit pattern into it (via `memcpy`, a union, or FFI) produces an object whose value is neither, and compilers generate code assuming 0/1. Normalize at the boundary: `b = (raw != 0);`

## Pointers

- A null pointer constant is `0` or `(void*)0`; the null pointer *representation* need not be all-bits-zero. `calloc`'d memory is therefore not guaranteed by the standard to contain null pointers or `0.0` floating values, even though every mainstream target makes it so. If you rely on it, say so in a comment.
- Converting a `void *` to and from an object pointer is defined and requires no cast in C. Converting between incompatible object pointer types is defined only if alignment is adequate; *dereferencing* is then governed by strict aliasing.
- Function pointers and object pointers are not interconvertible in ISO C. `dlsym` returning `void *` is a POSIX-blessed wart; POSIX requires the conversion to work, ISO C does not.
- Calling a function through a pointer of incompatible type is UB. In particular, calling a variadic function through a non-variadic pointer (or vice versa) is UB even when the ABI happens to match — a real problem on WebAssembly and with CFI.
- `const` and `volatile` qualification is part of the type. Dropping qualifiers silently through a `void *` is a common source of writes to read-only data.
- `volatile` means "this access may have effects the compiler cannot see" — MMIO, `sig_atomic_t` set from a signal handler, `setjmp`-surviving locals. It provides no atomicity, no ordering with respect to non-volatile accesses, and no visibility guarantee between threads. It is not a concurrency tool.
- Pointer provenance: a pointer carries not just an address but the object it was derived from. Two pointers that compare equal are not interchangeable if they have different provenance; round-tripping through `uintptr_t` to "launder" a pointer is not sanctioned by the standard and is actively exploited by alias analysis.

## Allocation

### Ownership conventions

Pick one convention per module and document it in the public header:

- **Caller allocates, callee fills.** `int foo_render(foo *f, char *buf, size_t cap, size_t *out_len);` No allocator coupling, easiest to test, best for hot paths.
- **Callee allocates, caller frees with a matching function.** Every `foo_new` needs a `foo_free`. Never document "call `free()` on it" across a library boundary — see the FFI section.
- **Borrow.** The returned pointer is valid only until the next call on the same object, or until the object is destroyed. Say exactly which.

For every resource record: creator, owner on success, owner on failure, whether ownership transfers, borrow lifetime, release function, and the allocator/domain required to release it.

### Failure paths

```c
int thing_new(thing **out) {
    thing *t = calloc(1, sizeof *t);       /* sizeof *t, not sizeof(thing) */
    if (!t) return E_NOMEM;

    t->buf = malloc(INITIAL_CAP);
    if (!t->buf) goto fail_buf;
    t->cap = INITIAL_CAP;

    if (mtx_init(&t->lock, mtx_plain) != thrd_success) goto fail_lock;

    *out = t;
    return 0;

fail_lock:
    free(t->buf);
fail_buf:
    free(t);
    return E_NOMEM;
}
```

- `sizeof *ptr` instead of `sizeof(Type)` makes the allocation follow the declaration when the type changes.
- Release in reverse order of acquisition. `calloc` (or explicit zeroing) makes a single `goto cleanup` label safe, because every handle is in a known-releasable state.
- `free(NULL)` is a defined no-op. Design release functions to accept `NULL` for the same reason; document it.
- A failed constructor must leave nothing allocated and must not have mutated caller-visible state.

### `realloc`

```c
/* WRONG: on failure the original block leaks and v->items is now NULL. */
v->items = realloc(v->items, new_cap * sizeof *v->items);

/* RIGHT */
size_t bytes;
if (!size_mul(new_cap, sizeof *v->items, &bytes)) return E_OVERFLOW;
T *tmp = realloc(v->items, bytes);
if (!tmp) return E_NOMEM;            /* v->items still valid, still owned */
v->items = tmp;
v->cap   = new_cap;
```

- On success, the old pointer value is indeterminate — even reading it is UB. Every cached interior pointer, iterator, and index-turned-pointer into the block is dead. This is the aliasing hazard that bites: a caller holding `&v->items[i]` across a growth.
- `realloc(NULL, n)` == `malloc(n)`.
- `realloc(p, 0)`: never call it. C89–C17 left it murky (DR 400 made it implementation-defined — glibc frees and returns `NULL`, other implementations return a unique non-null pointer, so you cannot distinguish success from failure); C23 removes the guarantee entirely. Branch on `n == 0` yourself.
- Shrinking `realloc` can also fail and return `NULL` — the standard does not promise otherwise.

### Size arithmetic

- Every `n * sizeof(T)` is an overflow site. `malloc` receives a `size_t`; a wrapped product allocates a small block and every subsequent write is a heap overflow. This is the single most common route from "integer bug" to "remote code execution."
- `calloc(nmemb, size)` is the one allocation call where mainstream libcs (glibc, musl, the Windows CRT, macOS) detect the product overflow and return `NULL`. The C standard does not spell out that requirement, so if a target's libc is unknown, check the product yourself.
- Struct + trailing data: `size_add(sizeof(struct msg), len, &need)`, then allocate `need`.
- On 32-bit targets, keep allocations under `PTRDIFF_MAX`; larger blocks make pointer subtraction within them UB.

### Zero-size and other edge cases

- `malloc(0)` may return `NULL` or a unique pointer that must still be freed; the choice is implementation-defined. `NULL` from `malloc` is therefore not proof of failure unless the size was nonzero. Normalize: `p = malloc(n ? n : 1);`
- `free` on a pointer not obtained from the `malloc` family, on an already-freed pointer, or on an interior pointer is UB.
- Do not mix allocator domains: `malloc`/`free`, `_aligned_malloc`/`_aligned_free`, `CoTaskMemAlloc`/`CoTaskMemFree`, arena/pool allocators. A pointer's allocator is part of its type in the human sense; encode it in the release function's name.
- Arena / bump allocators eliminate per-object frees and whole classes of leak, at the cost of an all-or-nothing lifetime. They are the right answer for a parse tree and the wrong answer for long-lived caches.
- Custom allocator hooks in a public API must be per-instance, set at construction, and used for every allocation *and* free of that instance's memory.

## Strings

C strings are a length-plus-terminator convention enforced by nothing. Prefer an explicit `{ const char *p; size_t len; }` slice internally and produce a NUL-terminated form only at the boundary where a C API demands it.

### `str*` failure modes

| Function | Failure mode |
| --- | --- |
| `strcpy`, `strcat`, `sprintf`, `gets` | Unbounded write. `gets` was removed in C11. |
| `strncpy` | Does **not** NUL-terminate when `strlen(src) >= n`. Pads the remainder with NUL when shorter (an O(n) cost on large buffers). It is a fixed-width-field primitive, not a bounded `strcpy`. |
| `strncat` | `n` is the maximum number of characters **appended**, not the destination size. Always writes a NUL, so the buffer must hold `strlen(dst) + n + 1`. |
| `strtok` | Mutates the input and holds static state; not reentrant. Use `strtok_r` (POSIX) / `strtok_s` (MSVC), or hand-roll. |
| `atoi`, `atol` | UB on overflow, no error channel. Never use. |
| `strlen` on unterminated data | Reads out of bounds. Use `memchr(p, '\0', avail)` or POSIX `strnlen`. |
| `memcpy` with overlapping ranges | UB. Use `memmove`. |

`memcpy`/`memmove`/`memcmp` require valid pointers even when `n == 0` (C17 7.24.1p2), so `memcpy(NULL, NULL, 0)` is UB and GCC/Clang do exploit the implied non-nullness to delete later null checks. C23 relaxes this for zero-length operations; write the `n == 0` guard anyway if you support older revisions.

### `snprintf`

```c
int n = snprintf(buf, sizeof buf, "%s/%s", dir, name);
if (n < 0)                     return E_ENCODING;   /* output error */
if ((size_t)n >= sizeof buf)   return E_TRUNC;      /* would-be length, truncated */
size_t len = (size_t)n;
```

- Returns the number of characters that **would** have been written, excluding the terminator. It is not the number written. Using it as a running offset without the truncation check walks the cursor past the end of the buffer — the classic "append in a loop" heap overflow.
- Always NUL-terminates when `size > 0`. Writes nothing when `size == 0`, which makes `snprintf(NULL, 0, fmt, ...)` the standard way to size a buffer (C99).
- MSVC's `_snprintf` (leading underscore, pre-2015) returns `-1` on truncation and does not NUL-terminate. `snprintf` in MSVC 2015+ is C99-conforming.
- `vsnprintf` consumes the `va_list`; use `va_copy` if you must format twice (size, then write).

### Bounded alternatives

- `strlcpy` / `strlcat` (BSD; glibc 2.38+) return the length the operation *wanted*; truncation is `ret >= dstsize`. Not ISO C.
- Annex K `strcpy_s` etc. are optional, implemented essentially only by MSVC, and have a constraint-handler model that is easy to get wrong. Do not build a portable codebase on them.
- C23 adopted `strdup`, `strndup`, and `memccpy` into ISO C; before that they are POSIX.
- The general answer is an explicit-length interface of your own: pass `(buf, cap)` and return either a length or a truncation error, never a truncated result that looks successful.

### NUL discipline

- When accepting data from a network, file, or FFI caller, treat it as bytes plus a length. Validate that no embedded NUL exists *before* handing it to any `str*` function, or the consumer sees a silently shortened string — the root of many filename and authentication bypasses.
- When producing a C string from a length-delimited buffer, allocate `len + 1` and set the terminator explicitly; check `len != SIZE_MAX` first.
- `fgets` keeps the newline if it fits and gives no way to distinguish "line exactly filled the buffer" from "line was truncated" other than inspecting the last byte. `getline` (POSIX) is easier to use correctly.
- Never pass caller-controlled data as a format string. `printf(user)` is a read/write primitive via `%n` and `%s`. Always `printf("%s", user)`.

## API Design

- Minimize the public surface. Everything exported is a compatibility obligation.
- Prefer opaque handles: declare `typedef struct foo foo;` in the header, define the struct in the `.c`. Callers cannot depend on layout, and you can grow the struct without an ABI break.
- Make invalid states unrepresentable where cheap: a length that cannot exceed capacity because both live behind an accessor; a tagged union whose tag is only set by the constructor for that arm.
- **Ownership and lifetime in the header, next to the declaration.** Who frees the return value, with what function, and how long a returned borrow stays valid.
- **Errors.** Return a meaningful category, not a boolean, whenever the caller can act differently on different failures. Pick one convention: negative `errno`-style codes, a project `enum`, or `0`/`-1` with a per-object error accessor. Do not mix. If your API returns `errno` values, say so; do not silently rely on the global `errno` unless documented, because any intervening library call may clobber it.
- **`errno` capture.** Read `errno` immediately after the failing call and before anything else (including `close`, logging, or a destructor). `errno` is thread-local on all supported platforms but is not preserved across unrelated calls.
- **Out-parameters** are written only on success unless documented otherwise; that rule makes caller cleanup code obviously correct.
- **`const`-correctness** on every pointer parameter you do not modify. It is API documentation the compiler checks.
- **Thread safety** must be stated for every object: not thread-safe; safe if externally synchronized; safe for concurrent readers; fully thread-safe. Anything unstated will be assumed wrong by someone.
- **Reentrancy from callbacks**: state whether a callback may call back into the API on the same object, what happens if it does, and whether the callback may free the object.
- **Versioned option structs** beat adding parameters: `typedef struct { size_t struct_size; ... } foo_opts;` The callee checks `struct_size` and only reads fields the caller's version contained. This is the standard technique for extending an ABI-stable interface.
- **Reserved identifiers.** Identifiers beginning with an underscore followed by an uppercase letter or another underscore are reserved for any use; file-scope identifiers beginning with an underscore are reserved. `str`, `mem`, `wcs`, `is`/`to` + lowercase, `E` + digit or uppercase, and `LC_` + uppercase are reserved for future library directions. Prefix your public symbols with a project namespace and keep everything else `static`.
- Headers must be self-contained (include what they use) and idempotent (include guard). Never rely on transitive includes.
- Avoid function-like macros in public headers when an `inline` function will do; macros evaluate arguments multiple times and do not respect scope.

## State Machines

- Represent state as an explicit `enum`, one variable, never as a combination of "is this pointer NULL" tests scattered across the file.
- Funnel transitions through one function. It asserts the source state is legal, performs the effect, then assigns the destination state. A transition table (`static const uint8_t next[N_STATES][N_EVENTS]`) makes the legal set auditable and testable in isolation.
- **Every failure must land in a defined state.** For each operation, decide in advance: does a failure leave the object exactly as it was (strong guarantee), or move it to an explicit terminal `FAILED` state from which only teardown is legal? "Somewhere in between" is how half-initialized objects escape.
- No partially constructed object may become visible. Build it fully, then publish the pointer — this matters even single-threaded, because a callback or an error path may observe it.
- Teardown must be valid from **every** state, including `FAILED` and including states reached by aborting construction.
- A poisoned/terminal state is usually better than trying to resume after an unexpected internal error: subsequent calls return the sticky error, nothing is corrupted further, and the first error is what the user reports.
- **Reentrancy guard.** If a callback can re-enter, either document it as supported and make the state machine tolerate it, or set an `in_callback` flag and reject re-entry with a defined error. Choose one; do not leave it to chance.
- Stale-handle detection: pair an index with a generation counter that increments on free. A stale handle fails the generation check instead of aliasing a recycled slot.
- Assert the state invariant at entry and exit of each public function while debugging, and keep a defensive `default:` in every state `switch` that returns an internal-error code in release builds. Assertions vanish under `NDEBUG`; the defensive branch must not.

## Concurrency

### The C11 memory model

A **data race** — two conflicting accesses to the same memory location from different threads, at least one a write, at least one non-atomic, with no happens-before between them — is undefined behavior (C11 5.1.2.4p25). Not "a torn value": UB, with the full backwards-inference consequences. There is no benign data race in standard C.

A "memory location" is an object or a maximal sequence of adjacent bit-fields; distinct non-bit-field members of a struct are distinct locations, so concurrent writes to `s.a` and `s.b` are fine. Adjacent bit-fields not separated by a zero-width field are the same location and racing on them is UB.

Atomics (`<stdatomic.h>`, C11) are optional — guard with `__STDC_NO_ATOMICS__`. Threads (`<threads.h>`) are optional too — `__STDC_NO_THREADS__` — and are absent from glibc before 2.28 and from MSVC's C runtime for a long time; pthreads or a platform abstraction layer is usually the portable choice, with `<stdatomic.h>` for the lock-free parts.

### `_Atomic` and memory orders

```c
_Atomic int          ready;      /* or atomic_int */
_Atomic(struct s *)  head;
```

Plain operators on an `_Atomic` object are sequentially consistent. Use the `_explicit` forms when you have argued for a weaker order.

| Order | Guarantee | Use for |
| --- | --- | --- |
| `memory_order_relaxed` | Atomicity only. No ordering with other accesses. | Statistics counters where only the eventual total matters; reference-count *increments* made while already holding a reference; a flag whose only consumer re-checks under a lock |
| `memory_order_acquire` (load) | Nothing later in program order moves before it; sees everything ordered before the matching release | Reading a published pointer or flag |
| `memory_order_release` (store) | Nothing earlier in program order moves after it | Publishing an initialized object |
| `memory_order_acq_rel` | Both, for read-modify-write | CAS in a lock-free structure |
| `memory_order_seq_cst` | Adds a single total order across all `seq_cst` operations | The default; required when correctness depends on multiple variables being observed in a consistent order (Dekker-style) |
| `memory_order_consume` | Data-dependency ordering | Nothing. No production compiler implements it; all promote it to acquire. Do not use. |

The release/acquire pairing is the workhorse:

```c
/* Producer */
obj->field = 42;                                          /* plain write */
atomic_store_explicit(&published, obj, memory_order_release);

/* Consumer */
T *p = atomic_load_explicit(&published, memory_order_acquire);
if (p) use(p->field);      /* guaranteed to see 42 */
```

Reference counting, the canonical justified use of relaxed and of a fence:

```c
static void ref(obj *o) {
    atomic_fetch_add_explicit(&o->rc, 1, memory_order_relaxed);
}
static void unref(obj *o) {
    if (atomic_fetch_sub_explicit(&o->rc, 1, memory_order_release) == 1) {
        atomic_thread_fence(memory_order_acquire);   /* see other threads' writes */
        destroy(o);
    }
}
```

The increment is relaxed because the caller already holds a reference, so the object cannot die underneath it. The decrement is release so that this thread's writes are visible to whoever destroys the object, and the acquire fence on the last decrement makes the destroying thread see everyone else's.

Compare-exchange:

```c
int old = atomic_load_explicit(&v, memory_order_relaxed);
int neu;
do {
    neu = transform(old);
} while (!atomic_compare_exchange_weak_explicit(
             &v, &old, neu, memory_order_acq_rel, memory_order_relaxed));
```

`_weak` may fail spuriously and is cheaper inside a loop; `_strong` fails only on a genuine mismatch and is right when there is no loop. On failure the expected argument is **updated in place** with the observed value — that is what makes the loop above correct, and what makes copying `old` into the loop body a bug.

Other rules:

- `_Atomic` types may be lock-free or not; check `ATOMIC_INT_LOCK_FREE` etc. Only `atomic_flag` is guaranteed lock-free. A non-lock-free atomic uses a lock internally and is not usable from a signal handler.
- Atomicity does not compose. Two atomic operations are not an atomic pair. `if (atomic_load(&x)) atomic_store(&x, 0);` is a race condition, correctly compiled.
- `volatile` is not a substitute for `_Atomic`. It gives neither atomicity nor inter-thread ordering. `volatile sig_atomic_t` is for signal handlers, not threads.
- Signal handlers may only access objects of type `volatile sig_atomic_t` and lock-free atomics, and may only call async-signal-safe functions (the list is POSIX; `malloc`, `printf`, and most of libc are not on it).
- Initialize atomics with `ATOMIC_VAR_INIT` (C11; deprecated in C17, removed in C23 — plain initialization works) or `atomic_init`. A non-atomic object is not made atomic by casting.
- Condition-variable waits must be in a loop re-testing the predicate: spurious wakeups are permitted.
- Locks have an order. Document it, acquire in that order everywhere, and never call a user callback while holding a lock unless you have documented that the callback may not re-enter.
- Thread-safe initialization: `call_once` (C11) / `pthread_once`. Hand-rolled double-checked locking is only correct with acquire/release atomics on the flag *and* the pointer.
- **TOCTOU**: any check whose result you use after releasing the synchronization that made it true is stale. Validate and act under the same lock, or use an atomic RMW that does both. The same reasoning applies to the filesystem (see Security) and to shared memory written by another process — re-read a value into a local *once* and validate that local, because a hostile mapper can change the shared copy between your bounds check and your use.

## Parsing Untrusted Input

The parser is the attack surface. Everything past it should be able to assume validated structure.

- Carry an explicit `(cursor, end)` pair or `(base, len, offset)` and check every read against the remaining bytes *before* advancing. `need > (size_t)(end - p)` — never `p + need > end`.
- Validate length prefixes against the bytes actually remaining, before allocating and before arithmetic. A 4 GiB declared length in a 40-byte message must be rejected at the length check, not at the copy.
- A length that fits in `uint64_t` need not fit in `size_t`. On 32-bit targets, range-check into `size_t` explicitly.
- Impose limits: maximum message size, maximum element count, maximum nesting depth, maximum total allocation per message. Recursive-descent parsers need an explicit depth counter — stack exhaustion from nested containers is a trivially reachable crash and is not caught by bounds checks.
- Never advance the cursor by a value derived from input before validating it, and never compute an offset before validating both operands.
- Reject rather than repair. Silent normalization of malformed input creates parser-differential bugs between your implementation and the next one.
- Do not decode with unaligned casts:

```c
/* WRONG: alignment UB plus strict-aliasing UB. */
uint32_t v = *(const uint32_t *)p;

/* RIGHT: explicit big-endian decode, no alignment or endianness assumption. */
static uint32_t rd_be32(const unsigned char *p) {
    return (uint32_t)p[0] << 24 | (uint32_t)p[1] << 16 |
           (uint32_t)p[2] <<  8 | (uint32_t)p[3];
}
```

Compilers recognize the shift-and-or pattern and emit a single load (plus a byte swap where needed), so there is no performance argument for the cast.

- Never `memcpy` a wire buffer over a struct. Padding, alignment, `enum` size, `_Bool` representation, and bit-field layout are implementation-defined; `#pragma pack` fixes only some of that and creates misaligned members whose addresses you must never take. Decode field by field.
- Numeric text: `strtol`/`strtoull`, never `atoi`.

```c
errno = 0;
char *end;
long v = strtol(s, &end, 10);
if (end == s)            return E_NOTNUM;    /* no conversion */
if (*end != '\0')        return E_TRAILING;  /* junk after the number */
if (errno == ERANGE)     return E_RANGE;
if (v < MIN || v > MAX)  return E_RANGE;
```

`errno` must be zeroed first: `strtol` sets `ERANGE` on overflow but never clears `errno`. Note that `strtol` skips leading whitespace and accepts a sign, which is often not what a wire format wants.

- Signedness of length fields: a field declared `int32_t` on the wire can be negative. Convert to unsigned only after rejecting negatives, or the conversion produces a huge length.
- Distrust the trailing NUL. Text extracted from a binary container has an explicit length; do not hand it to `str*` without checking for embedded NULs and appending your own terminator.
- Fail closed: on any error, free everything allocated for that message, leave the connection/stream state well-defined, and do not leak partially parsed data to the consumer.

## Persistence and Durability

### Formats

- **In-memory struct layout is not a file format.** Serialize explicitly, field by field, with fixed-width types and a declared byte order.
- Every format gets a header: magic bytes, format version, and enough length information to skip what you do not understand. Decide up front whether unknown-version files are rejected or read in compatibility mode; both are defensible, silence is not.
- Checksum records (CRC32C for corruption detection, a MAC if the data is untrusted). Verify before interpreting, not after.
- Reserved/padding fields must be written as zero and validated as zero, or they can never be used later.
- Floating point in a persistent format needs a stated representation (IEEE-754 binary64) and a decision about NaN payloads; `long double` must never appear (its size and format vary: 80-bit x87, 64-bit on ARM/MSVC, 128-bit quad).

### Writing durably

`write(2)` may return a short count. `fwrite` may too. Loop:

```c
static int write_all(int fd, const void *buf, size_t len) {
    const unsigned char *p = buf;
    while (len > 0) {
        ssize_t n = write(fd, p, len);
        if (n < 0) { if (errno == EINTR) continue; return -1; }
        p += (size_t)n; len -= (size_t)n;
    }
    return 0;
}
```

Atomic replacement of a file, on POSIX:

```
1. open(tmp, O_WRONLY|O_CREAT|O_EXCL, 0600)   /* tmp in the SAME directory */
2. write_all(...)                              /* check every write        */
3. fsync(tmp_fd)                               /* check the return value   */
4. close(tmp_fd)                               /* check the return value   */
5. rename(tmp, final)                          /* atomic on POSIX          */
6. fsync(dirfd of the containing directory)    /* makes the rename durable */
7. close(dirfd)
```

- Step 6 is the one people skip. Without it, a crash can leave the directory entry unwritten even though the file contents are on disk.
- `fflush` pushes stdio buffers to the OS; it does **not** make anything durable. `fclose` does not `fsync`. If you use `FILE *`, `fflush` then `fsync(fileno(f))` then `fclose`, checking all three.
- Check the return of `fsync` **and** of `close`. A deferred write error can be reported by either. On Linux, a failed `fsync` may report the error only once and dirty pages may already have been dropped — an `fsync` failure is not retryable, and the correct response is to treat the file as lost, not to loop.
- Never `open(final, O_TRUNC)` and rewrite in place: between truncate and completion there is no valid file on disk.
- Windows: `FlushFileBuffers` for `fsync`; `MoveFileEx(tmp, final, MOVEFILE_REPLACE_EXISTING | MOVEFILE_WRITE_THROUGH)` or `ReplaceFile` for the atomic swap. There is no directory-fsync equivalent and none is needed.

### Crash and torn-state recovery

- State the invariant: after any interruption, the persistent state is either the complete old form or the complete new form, never a mixture. Then design backwards from it.
- Sector-level atomicity is not something to rely on. Assume any single write can be torn; that is what per-record checksums are for.
- Append-only log / WAL: append `[len][payload][crc]`, `fsync`, and only then apply the change to the main structure. On recovery, replay from the last checkpoint and stop at the first record whose length is impossible or whose CRC fails — that record and everything after it never happened.
- Make replay idempotent, because a crash during replay is normal.
- Double-buffered headers (two header slots plus a sequence number and a checksum, written alternately) give a torn-free superblock update without a log.
- Test this by injecting failure at every write and `fsync` in the sequence and verifying that recovery yields one of the two legal states. A durability claim that has not been crash-tested is a hope.

## Security

- Every UB in code reachable from untrusted input is a candidate exploit primitive, not a theoretical concern. Prioritize accordingly.
- **`assert` is not input validation.** It compiles to nothing under `NDEBUG`, which is how release builds are usually configured. Assertions state invariants you have proven; input checks are ordinary code with ordinary error returns. Where both apply, assert in debug *and* keep the defensive check in release.
- Integer overflow in a size computation is the standard path to a heap overflow. Audit every allocation size, every `memcpy` length, and every index computed from input.
- Off-by-one: `<=` in a bounds check, `sizeof buf` vs `sizeof buf - 1` for the terminator, and reading `n + 1` bytes to include a NUL.
- Format strings: never attacker-controlled. `-Wformat -Wformat-security` catches the common cases.
- `system`, `popen`, and shell-interpolated commands with any external data are command injection. Use `posix_spawn`/`fork`+`execve` with an explicit argument vector.
- Path handling: reject `..` components and absolute paths after normalization, resolve relative to a directory fd with `openat`, and use `O_NOFOLLOW` where symlinks are not intended.
- Filesystem TOCTOU: `stat` then `open` is exploitable. `open` first, then `fstat` the descriptor; operate on descriptors, not names. Create temporary files with `mkstemp` (mode 0600, `O_EXCL`) or `O_CREAT|O_EXCL`, never with a predictable name.
- **Erasing secrets.** `memset` on a buffer that is dead afterwards is a legal dead-store elimination target. Use `explicit_bzero` (glibc 2.25+, BSD), `SecureZeroMemory` (Windows), or `memset_s` (C11 Annex K, optional). A portable fallback is a `volatile`-qualified function pointer to `memset`. Note that a secret in a `realloc`'d buffer may leave a copy in the old block, and one on the stack may leave copies in caller frames and registers.
- **Constant-time comparison** for MACs, tokens, and password hashes — `memcmp` returns early:

```c
static int ct_eq(const void *a, const void *b, size_t n) {
    const unsigned char *x = a, *y = b;
    unsigned char d = 0;
    for (size_t i = 0; i < n; i++) d |= (unsigned char)(x[i] ^ y[i]);
    return d == 0;
}
```

- Randomness for security comes from `getrandom`/`/dev/urandom` (Linux), `arc4random_buf` (BSD/macOS), or `BCryptGenRandom` (Windows). `rand`, `random`, and anything seeded from the clock are not.
- `alloca` and VLAs sized from input are a stack-clash primitive and have no failure path. Cap the size at a small constant or heap-allocate. VLAs are optional since C11 (`__STDC_NO_VLA__`).
- Do not leak addresses (pointers in log messages or error strings) or uninitialized padding bytes (zero whole structs before serializing) to untrusted parties.
- Privilege dropping order: supplementary groups, then `setgid`, then `setuid` — and check every return value; `setuid` can fail.
- Sanitize at the boundary once, then let the interior code rely on the validated invariant. Re-validating everywhere hides which layer is responsible.

## FFI and Cross-Boundary Code

### What crosses safely

Safe: fixed-width integers, `float`/`double`, pointers, opaque handles, C-callable function pointers, arrays passed as pointer + length, and structs whose layout you have pinned deliberately.

Unsafe or requiring an explicit agreement: `long` (32-bit on LLP64 Windows, 64-bit on LP64 Unix), `long double`, `bool`/`_Bool` in older bindings, plain `char` (signedness), `enum` (underlying type is implementation-defined; C23 permits explicit underlying types), bit-fields (allocation order, straddling, and padding are all implementation-defined), packed structs, and anything whose size depends on a compile-time flag both sides do not share.

- Header must compile as C and as C++ on both sides: wrap declarations in `#ifdef __cplusplus extern "C" {`.
- Use `-fvisibility=hidden` plus explicit export attributes (or a linker version script / `.def` file) so the shared object exports only its intended API.
- On Windows, calling convention is part of the signature (`__cdecl` vs `__stdcall`); mismatches corrupt the stack. Declare it explicitly in the public header via a macro.
- Never assume the other side computed the same `sizeof` or offsets. If a struct must cross, either fix its layout by construction (fixed-width members ordered largest-first, explicit padding fields, a static assertion on `sizeof` and on each `offsetof`) or pass an opaque handle and accessors instead.

### Ownership across the boundary

- **Allocate and free on the same side.** A shared library must export `foo_free`; telling the caller to use `free` binds you to the caller's CRT. On Windows this is not a style point — a DLL and its caller can link different C runtimes with different heaps, and freeing across them corrupts the heap.
- Say explicitly whether a pointer passed *in* is borrowed for the duration of the call or retained. If retained, say when it is released and whether the callee copies.
- Strings crossing a boundary: pass pointer plus length, define the encoding (UTF-8 unless stated), and define whether a terminator is present.
- Returned buffers: either the callee owns and the caller must call a release function, or the caller supplies the buffer and a capacity and gets back a required-size on truncation. Do not invent a third convention per function.

### Callbacks

```c
typedef int (*foo_cb)(void *user, const unsigned char *data, size_t len);
int foo_scan(foo *f, foo_cb cb, void *user);
```

Document, in the header, all of:

- which thread the callback runs on, and whether it may run concurrently with itself;
- how long `data` is valid (almost always: only for the duration of the call — say so, because the natural assumption is otherwise);
- whether the callback may call back into the API on the same object, and which calls are legal if so;
- whether the callback may destroy the object it was invoked from;
- what a nonzero return does (abort the scan? propagate as the function's return?);
- whether the callback may be invoked zero times, and whether it is invoked after an error.

Never let an exception or a `longjmp` cross an FFI frame. A C++ exception escaping into C frames, or a `longjmp` past frames belonging to a managed runtime, skips destructors and unwind bookkeeping — UB in practice and often a leak or a corrupted runtime. Catch at the boundary and convert to an error code. `longjmp` into a function whose invocation has already terminated is UB, and locals not declared `volatile` have indeterminate values after `longjmp` if they were modified since `setjmp`.

### Errors across the boundary

- Do not export `errno` as your error channel. `errno` is thread-local but not preserved across arbitrary calls, and a foreign runtime may clobber it before the caller reads it. Return an explicit code, and if the underlying cause was an `errno` value, capture it immediately and expose it as a field.
- Provide a thread-safe way to get an error message: either a pure `const char *foo_strerror(int)` for static codes, or a per-object last-error buffer. Never a shared `static char[]`.
- Foreign runtimes may install signal handlers, move memory (GC), or run your callback on a thread the runtime owns. If you can be called on an arbitrary thread, you need explicit thread attach/detach semantics or full thread-safety, and neither can be inferred by the caller — document which one you provide.
