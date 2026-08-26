# Performance and Portability

Deep reference for portability, ABI stability, build/target separation, compiler matrices, profiling, benchmarking, and optimization in C.

Consult mid-task. The value here is in the specifics that are routinely assumed wrong: what the standard actually guarantees, which change silently breaks already-compiled callers, and which measurement is measuring nothing.

## Portability

### Guaranteed versus assumed

The standard guarantees far less than most code assumes.

| Assumption | Reality |
| --- | --- |
| `char` is 8 bits | `CHAR_BIT >= 8`. POSIX requires exactly 8; some DSP toolchains (TI C2000/C55x) use 16. `sizeof(char) == 1` always, by definition — that says nothing about bit width. |
| `int` is 32 bits | `int` is at least 16 bits. It is 16 on AVR, MSP430, and most 16-bit embedded targets. |
| `long` is pointer-sized | False on Win64 (LLP64: `long` is 32 bits). Use `intptr_t`/`uintptr_t`/`size_t`. |
| `char` is signed | Implementation-defined. Signed on x86/x86-64 Linux, macOS, Windows; **unsigned** on ARM/AArch64 Linux, PowerPC, s390x. |
| Signed overflow wraps | Undefined behavior in every C standard, including C23 (C23 mandates two's-complement *representation*, not wrapping arithmetic). |
| `NULL` is all-zero bits | Not guaranteed. In practice it is everywhere you will ship, but `memset` of a pointer array is not a portable way to set null pointers. |
| Struct layout is predictable | Only: members are in increasing address order, no padding before the first member, and `&struct == &first_member` (converted). Everything else is implementation-defined. |
| `time_t` is 64-bit | Implementation-defined arithmetic type. Still 32-bit on 32-bit glibc unless built with `_TIME_BITS=64`. |
| Right shift of a negative value | Implementation-defined (arithmetic in practice). Shifting by `>= width` is UB regardless of sign. |

Minimum ranges guaranteed by `<limits.h>`: `short` and `int` at least 16 bits, `long` at least 32, `long long` at least 64.

### `<stdint.h>` and printing

- `int8_t`..`int64_t` and unsigned counterparts are **conditionally present**: only if the implementation has a type of exactly that width, no padding bits, two's complement. They are absent on a target with `CHAR_BIT == 16`. `int_least32_t` and `int_fast32_t` are always present; `intmax_t`/`uintmax_t` always; `intptr_t`/`uintptr_t` are optional but universal on hosted platforms.
- `size_t`, `ptrdiff_t`, `max_align_t` come from `<stddef.h>`. `ssize_t` is POSIX, not C.
- **`uint64_t` is not consistently one of `unsigned long` / `unsigned long long`.** It is `unsigned long` on LP64 Linux and `unsigned long long` on LLP64 Windows and on 32-bit Linux. `printf("%lu", x)` for a `uint64_t` is wrong on at least one of your targets and `-Wformat` will catch it only on the target where it is wrong. Use `<inttypes.h>`:

```c
#include <inttypes.h>
printf("%" PRIu64 " %" PRIx32 " %zu %td %jd\n",
       u64, u32, sz /*size_t*/, diff /*ptrdiff_t*/, (intmax_t)t /*time_t*/);
```

- `%zu` (size_t) and `%td` (ptrdiff_t) are C99. Modern MSVC (UCRT, VS2015+) supports them; older MSVC needed `%Iu`.
- `time_t` has no format specifier. Cast to `intmax_t` and use `%jd`, or to `long long` and use `%lld`.

### Data models

| Model | `int` | `long` | pointer | Where |
| --- | --- | --- | --- | --- |
| ILP32 | 32 | 32 | 32 | 32-bit Linux/Windows, armhf, i386 |
| LP64 | 32 | 64 | 64 | Linux, macOS, the BSDs, Solaris on 64-bit |
| LLP64 | 32 | 32 | 64 | 64-bit Windows |
| ILP64 | 64 | 64 | 64 | Rare (some Cray/SGI); mentioned because code that assumes `sizeof(int) == 4` is wrong there |

The LP64/LLP64 split is the single most common source of Windows porting bugs: `long` truncates pointers and sizes, `%ld` on a `size_t` prints garbage, and `sizeof(long)` differences change struct layout.

### `char` signedness

Plain `char`, `signed char`, and `unsigned char` are three *distinct* types even though plain `char` has the representation of one of the other two.

- Use `unsigned char` for bytes, buffers, and anything indexed or compared numerically.
- `<ctype.h>` functions require an argument representable as `unsigned char` or equal to `EOF`. `isspace(*p)` where `p` is `char *` is UB on any input byte >= 0x80 on a signed-`char` target:

```c
if (isspace((unsigned char)*p)) { ... }   /* always cast */
```

- `-fsigned-char` / `-funsigned-char` exist on GCC/Clang, but a program whose correctness depends on them is not portable — fix the source, don't pin the flag. (Setting the flag project-wide is legitimate as a *consistency* measure; it is not a fix.)

### Endianness

Do not detect endianness. Serialize explicitly; every mainstream compiler recognizes the pattern and emits a single load plus `bswap` where legal.

```c
static uint32_t rd_le32(const unsigned char *p) {
    return (uint32_t)p[0]        | (uint32_t)p[1] << 8 |
           (uint32_t)p[2] << 16  | (uint32_t)p[3] << 24;
}
static void wr_le32(unsigned char *p, uint32_t v) {
    p[0] = (unsigned char)(v);       p[1] = (unsigned char)(v >> 8);
    p[2] = (unsigned char)(v >> 16); p[3] = (unsigned char)(v >> 24);
}
```

The casts to `uint32_t` before shifting are load-bearing. `p[3] << 24` promotes `p[3]` to `int`; when `p[3] >= 0x80` the result is not representable in a 32-bit `int` and the shift is undefined. This is a live UBSan finding in a great deal of shipped serialization code.

If you must detect: GCC/Clang define `__BYTE_ORDER__`, `__ORDER_LITTLE_ENDIAN__`, `__ORDER_BIG_ENDIAN__`. There is no standard C macro and no MSVC equivalent (MSVC targets are all little-endian). Byte-swap helpers are platform-split: glibc `<endian.h>` (`htole32`, `be32toh`), BSD `<sys/endian.h>`, macOS `<libkern/OSByteOrder.h>`, MSVC `_byteswap_ulong` in `<stdlib.h>`. GCC/Clang have `__builtin_bswap16/32/64`.

Note that endianness is not one property: a few historical targets have mixed float and integer endianness, and bitfield allocation order within a storage unit is separately implementation-defined. Never put bitfields in a wire format.

### Alignment

- `_Alignof` / `alignof` (C11; `alignof` becomes a keyword spelling in C23 via `<stdalign.h>` in C11/C17) and `_Alignas` / `alignas`.
- `malloc`, `calloc`, `realloc` return memory suitably aligned for any object with *fundamental* alignment, i.e. up to `_Alignof(max_align_t)` (16 on most 64-bit ABIs). They do **not** guarantee over-alignment.
- Over-aligned allocation:
  - C11 `aligned_alloc(alignment, size)` — the standard requires `size` to be an integral multiple of `alignment`. Some libcs tolerate otherwise; do not rely on it. Free with `free`. MSVC does not provide `aligned_alloc`.
  - POSIX `posix_memalign(&p, alignment, size)` — no multiple-of requirement, alignment must be a power of two and a multiple of `sizeof(void *)`. Free with `free`.
  - Windows `_aligned_malloc` — **must** be released with `_aligned_free`, not `free`.
- Reading an unaligned `uint32_t` by casting `unsigned char *` to `uint32_t *` is UB twice over (alignment and effective type) even on x86 where the load itself works. Use `memcpy`; compilers fold a fixed-size `memcpy` into a single instruction:

```c
uint32_t v;
memcpy(&v, p, sizeof v);   /* compiles to one mov on x86-64 */
```

On strict-alignment targets (some ARMv5/v6 configurations, SPARC, and any target built with `-mno-unaligned-access`) the cast form faults at runtime. On AArch64 it usually works, which is worse — it hides until you hit an atomic or a NEON path that requires real alignment.

- `#pragma pack` and `__attribute__((packed))` are nonstandard and produce members whose *addresses* are under-aligned. Taking `&s.field` on a packed struct yields a pointer the compiler is entitled to assume is aligned; GCC warns with `-Waddress-of-packed-member`. Packed structs are a poor substitute for explicit serialization.

### Padding and struct layout

- Padding bytes have unspecified values. Consequences:
  - `memcmp` on two structs is not a valid equality test.
  - Hashing a struct by its bytes is not stable.
  - Writing a struct to disk or a socket exports your compiler's layout as a format. Do not do it. Serialize field by field with fixed-width types and explicit byte order.
- Struct assignment and `memcpy` of a struct *may* copy padding; whether padding is zeroed by `= {0}` is a subtle area (C11 leaves padding unspecified after initialization, though implementations commonly zero it). If padding must be zero — because you hash it, or pass it to a kernel — `memset` the whole object first, explicitly.
- `offsetof` (`<stddef.h>`) is the only portable way to ask about layout.
- Flexible array member (C99), last member only, not counted by `sizeof`:

```c
struct msg { uint32_t len; unsigned char data[]; };
struct msg *m = malloc(sizeof *m + len);   /* check len for overflow first */
```

- Unions: reading a member other than the one last written is *not* UB in C (unlike C++) — it is type punning with unspecified/trap-representation caveats, and it is the portable alternative to a pointer cast. `memcpy` is still cleaner and always correct.

### Files, paths, and stream modes

POSIX and Windows differ in ways that are not cosmetic.

- Paths on POSIX are byte strings; only `/` and NUL are special; they need not be valid UTF-8. Paths on Windows are UTF-16 at the syscall layer. The ANSI `fopen`/`CreateFileA` entry points cannot express names outside the active code page (Windows 10 1903+ can opt a process into UTF-8 ACP via manifest, which is not a safe assumption). Portable file handling on Windows means `_wfopen`/`CreateFileW` with your own UTF-8 to UTF-16 conversion.
- Windows path rules that catch people: both `\` and `/` separate; drive-relative paths (`C:foo`); UNC (`\\server\share`); case-insensitive but case-preserving; trailing dots and spaces silently stripped; reserved device names (`CON`, `PRN`, `AUX`, `NUL`, `COM1`–`COM9`, `LPT1`–`LPT9`) match *with any extension* (`con.txt` is the console); `MAX_PATH` of 260 unless the process is long-path aware (manifest + `LongPathsEnabled`) or the path uses the `\\?\` prefix (which also disables all normalization, so you must pass a fully-qualified, backslash-only path).
- Semantics: POSIX lets you `unlink` an open file and `rename` atomically over an existing file. Windows blocks deletion of a file open without `FILE_SHARE_DELETE`, and replacement needs `MoveFileEx(..., MOVEFILE_REPLACE_EXISTING)` or `ReplaceFile`. Atomic-rename durability patterns need a per-platform implementation, not an `#ifdef` inside the write path.
- **Text versus binary mode.** `fopen(path, "rb")` / `"wb"`. On Windows text mode translates `\n` to `\r\n` on write, collapses it on read, and historically treats `0x1A` (Ctrl-Z) as end-of-file on read. Omitting `b` corrupts binary data on Windows and is a no-op elsewhere, so the bug never reproduces for the author. For `stdin`/`stdout`, which you did not open:

```c
#ifdef _WIN32
#  include <io.h>
#  include <fcntl.h>
   _setmode(_fileno(stdout), _O_BINARY);
#endif
```

- On text streams, only values returned by `ftell` are valid arguments to `fseek`, and `ftell` values are not necessarily byte offsets. Arithmetic on text-stream offsets is not portable.

### `#ifdef` discipline and feature detection

Prefer feature detection to platform detection. `#ifdef __linux__` is a claim about which *kernel* you are on; what you actually need to know is whether `pipe2` exists, and that depends on the libc (glibc vs musl vs bionic vs uclibc) and its version. Platform lists rot and every new port re-edits every file.

Rules that hold up:

1. **Source asks a capability question; the build system answers it.** `#if HAVE_MEMMEM`, not `#if defined(__GLIBC__)`.
2. **Always define the macro to 0 or 1, and use `#if`, not `#ifdef`.** Then compile with `-Wundef`, which catches `#if HAVE_MEMEM` (typo) as an error instead of silently taking the else branch. `#ifdef` on a typo is silent.
3. **Confine conditionals to the top of a file or to separate translation units.** One `port_posix.c` and one `port_win32.c` behind an internal header beats fifty `#ifdef`s scattered through business logic. The conditional code becomes independently testable and readable.
4. **Every `#if` chain over platforms ends in `#else #error`.** A new target must fail loudly at compile time, not silently take a fallback that happens to compile.
5. Do not `#ifdef` around whole function bodies in a way that changes a function's signature or presence; keep the interface constant and vary the implementation.

Real, correct predefined macros:

| Macro | Meaning |
| --- | --- |
| `__STDC_VERSION__` | `199901L`, `201112L`, `201710L`, `202311L` (C23). Absent in C89. |
| `__GNUC__`, `__GNUC_MINOR__` | GCC — **also defined by Clang and ICC**, so it means "GNU-compatible", not "is GCC" |
| `__clang__`, `__clang_major__` | Clang; test this *before* `__GNUC__` when they differ |
| `_MSC_VER`, `_MSC_FULL_VER` | MSVC (`clang-cl` also defines it) |
| `_WIN32` | Any Windows, **including 64-bit**; `_WIN64` is the 64-bit-only one |
| `__APPLE__` + `<TargetConditionals.h>` | macOS vs iOS vs simulator via `TARGET_OS_*` |
| `__linux__`, `__FreeBSD__`, `__OpenBSD__`, `__NetBSD__` | kernels; `BSD` from `<sys/param.h>` |
| `__x86_64__`/`_M_X64`, `__i386__`/`_M_IX86`, `__aarch64__`/`_M_ARM64`, `__arm__`, `__riscv` | architecture |
| `__GLIBC__`/`__GLIBC_MINOR__` (from `<features.h>`) | glibc version. **musl deliberately defines nothing** — you cannot detect musl, which is the point: detect features. |
| `__has_include(<x.h>)`, `__has_attribute(x)`, `__has_builtin(x)` | C23; GCC 5+/Clang long before as extensions. Guard with `#if defined(__has_include)` if you support older compilers. |

### POSIX versus the C standard library

Know which layer a function belongs to before you use it.

- **C**: `<stdio.h>`, `<stdlib.h>`, `<string.h>`, `<time.h>`, `<math.h>`, `<errno.h>`, `<signal.h>` (a very small subset of real signal handling), `<stdatomic.h>` (C11, optional — `__STDC_NO_ATOMICS__`), `<threads.h>` (C11, optional — `__STDC_NO_THREADS__`).
- **POSIX**: `open`/`read`/`write`/`close`, `<unistd.h>`, `<fcntl.h>`, `<dirent.h>`, `<sys/stat.h>`, `<sys/mman.h>`, `<pthread.h>`, `<poll.h>`, `<sys/socket.h>`, `strdup`, `strndup`, `strtok_r`, `snprintf`-adjacent extensions, `fileno`, `ssize_t`, `off_t`.
- **Windows**: neither. `<io.h>` provides underscore-prefixed near-equivalents (`_open`, `_read`, `_close`, `_fileno`, `_strdup`); everything else is Win32 in `<windows.h>`. Threads are Win32 or, since VS 2022 toolsets, C11 `<threads.h>`.

`<threads.h>` availability is the practical trap: glibc has it since 2.28, musl has it, **macOS does not ship it at all**, and older MSVC lacks it. Portable C code that wants threads either uses pthreads with a Win32 shim, or ships its own thin abstraction. Do not assume C11 threads.

### Feature-test macros

Feature-test macros must be defined **before any header is included** — on the command line, or as the first lines of the file. glibc's `<features.h>` is pulled in by the first standard header and latches the decision; defining `_GNU_SOURCE` after `#include <stdio.h>` does nothing (or worse, half-works when another header re-enters).

| Macro | Effect |
| --- | --- |
| `_POSIX_C_SOURCE=200809L` | POSIX.1-2008. (`199309L` adds realtime, `200112L` is POSIX.1-2001.) Exposes POSIX names — and on glibc, defining it **hides** non-POSIX names that were visible by default. |
| `_XOPEN_SOURCE=700` | XSI, a superset; implies `_POSIX_C_SOURCE=200809L`. `600` for XSI/POSIX-2001. |
| `_DEFAULT_SOURCE` | glibc 2.19+; the modern replacement for `_BSD_SOURCE`/`_SVID_SOURCE`. Restores glibc's default (BSD + SVID + POSIX) visibility. Needed *in addition* when you also define `_POSIX_C_SOURCE`, because any explicit feature macro turns the default off. |
| `_GNU_SOURCE` | Everything glibc has. Implies the above plus GNU extensions (`asprintf`, `memmem`, `qsort_r`, `pipe2`, `getline` on old glibc, `RTLD_DEFAULT`). |
| `_FILE_OFFSET_BITS=64` | 32-bit glibc: makes `off_t` 64-bit and redirects `lseek`/`stat`/`fopen` to LFS variants. **Changes struct layout.** |
| `_TIME_BITS=64` | glibc 2.34+: 64-bit `time_t` on 32-bit targets. Requires `_FILE_OFFSET_BITS=64`. **Changes struct layout.** |
| `_DARWIN_C_SOURCE` | macOS: non-POSIX Darwin extensions. `-mmacosx-version-min=` / `MAC_OS_X_VERSION_MIN_REQUIRED` drives availability and weak linking. |
| `_WIN32_WINNT=0x0A00` | Windows: gates API declarations via `<sdkddkver.h>` to Windows 10+. Also `WIN32_LEAN_AND_MEAN`, `NOMINMAX`, `_CRT_SECURE_NO_WARNINGS`. |

`_GNU_SOURCE` changes *semantics*, not only availability. Two that bite:

- `strerror_r` becomes the GNU version returning `char *` instead of the XSI version returning `int`. Code that checks the return value for 0 then treats a non-null pointer as failure.
- `basename` becomes the `<string.h>` GNU version that does not modify its argument, instead of the POSIX `<libgen.h>` version that may. Including `<libgen.h>` flips it back.

Because these macros change struct layouts and function semantics, they must be **identical for every translation unit in the link**, including any static library you build. Mixing `_FILE_OFFSET_BITS` between two objects that pass a `struct stat` gives silent memory corruption with no diagnostic. Set them once, in one place, in the build system.

## ABI Stability

An **API break** costs your users a source edit. An **ABI break** silently miscompiles or crashes binaries that were never recompiled. Only the second one produces bug reports from people who did not change anything.

The rule that organizes everything below: **anything visible in a public header is baked into every caller at their compile time.** Sizes, offsets, enum widths, macro constants, and inline function bodies are all copied into the caller's object file. You cannot fix them by shipping a new shared library.

### Break table

| Change | API | ABI | Notes |
| --- | --- | --- | --- |
| Add a function | compatible | compatible | Bump minor / add a new symbol version node |
| Remove or rename an exported function | break | break | The only safe removal path is a long deprecation |
| Add a parameter to a function | break | break | Add `foo2()` instead |
| Change a parameter or return type | break | break | Includes `int`→`long` on LP64, and `int`→`size_t` |
| `char *` → `const char *` on a parameter | compatible-ish | compatible | Callers passing `char *` still compile; C is permissive here |
| `const char *` → `char *` on a parameter | break | compatible | Callers passing `const char *` now warn/error |
| Add a member to a **caller-visible** struct | compatible | **break** | Changes `sizeof`, so caller-allocated instances are too small |
| Add a member to an **opaque** struct | compatible | compatible | The whole point of opacity |
| Reorder members | compatible | **break** | Offsets move |
| Widen a member (`uint32_t`→`uint64_t`) | compatible | **break** | Size and every subsequent offset move |
| Change alignment (`alignas`, `#pragma pack`) | compatible | **break** | Size and offsets move |
| Add an enumerator | compatible | **maybe break** | See below |
| Change a `#define` constant's value | compatible | **break in effect** | Already-compiled callers hold the old value |
| Change a `static inline` function's body in a header | compatible | **break in effect** | Old callers keep the old body |
| Turn an exported function into `static inline` | compatible | **break** | The symbol disappears |
| Turn a `static inline` into an exported function | compatible | compatible | Old callers keep their copy; new ones call the symbol |
| Change struct size across the SysV x86-64 16-byte boundary | compatible | **break** | Pass-by-value classification flips from register to MEMORY |
| Add a member to a struct passed **by value** | compatible | **break** | Even for opaque-ish types, by-value passing exports the layout |
| Add a field to a struct the *library* allocates and the caller only points at | compatible | compatible | Provided the caller never does `sizeof`, embeds it, or arrays it |
| Change a function's variadic-ness | break | break | Different calling convention on many ABIs |
| Change bitfield widths or order | compatible | **break** | Bitfield layout is implementation-defined; never put bitfields in a public struct |
| Loosen a documented precondition | compatible | compatible | Tightening one is a semantic break even if the signature is identical |

Two entries deserve expansion.

**Enums.** In C, an enumerated type is compatible with `char`, a signed integer type, or an unsigned integer type — the choice is implementation-defined. GCC and Clang normally pick `unsigned int` or `int`. But **`-fshort-enums` is the default for bare-metal ARM EABI** (`arm-none-eabi-gcc`), where the compiler picks the smallest type that fits. Under that ABI, adding an enumerator with value 256 changes `sizeof(enum E)` from 1 to 2 and breaks every struct containing one. (It is *not* the default for `arm-linux-gnueabihf`; the ABIs differ, which is itself a portability hazard when linking objects built with different settings.) C23 lets you pin it: `enum E : int { ... };`. Before C23, pin it with a sentinel: `E_FORCE_INT = 0x7fffffff`.

Also: adding an enumerator is a semantic break for callers with an exhaustive `switch` compiled under `-Wswitch-enum -Werror`. That is an API break in practice even though the table says otherwise.

**`sizeof` leaking.** The moment a struct's definition appears in a public header, its size and layout are frozen, because callers can:

```c
struct foo f;                   /* stack allocation of a fixed size */
struct foo *a = malloc(10 * sizeof(struct foo));
struct bar { struct foo inner; int x; };   /* embedded by value */
size_t off = offsetof(struct foo, field);
f.field = 3;                    /* direct member access */
```

Any of these bakes today's layout into a binary you no longer control.

### Techniques for evolvable interfaces

**Opaque handles.** The default choice for anything stateful.

```c
/* foo.h */
typedef struct foo foo;
foo *foo_new(void);
void foo_free(foo *);
int  foo_set_timeout_ms(foo *, unsigned ms);
```

The struct is defined only in `foo.c`. You can add, remove, and reorder fields forever. Costs: one allocation per object, a pointer indirection, and accessor functions instead of field access. Buys: permanent layout freedom. For a library with external users this trade is almost always correct.

**Caller-allocated with a size field.** When an allocation per object is unacceptable (embedded, hot paths), let the caller pass the size it compiled against:

```c
typedef struct { size_t struct_size; unsigned ms; int flags; } foo_opts;
#define FOO_OPTS_INIT { sizeof(foo_opts), 0, 0 }
int foo_configure(foo *, const foo_opts *o);   /* branches on o->struct_size */
```

The library reads only fields the caller's `struct_size` covers, and treats absent fields as their documented defaults. This is the Win32 `cbSize` pattern. It works only when the *caller* fills the struct in; it cannot rescue a struct the library writes into caller-provided storage of an old size unless the size is passed in as well.

**Reserved padding.** `void *reserved[4];` documented as "must be zero". Cheap, but you can only ever store pointer-sized things there, and you must specify that callers zero-initialize.

**Symbol versioning (ELF/GNU only).** Ship two implementations under one name; old binaries keep binding to the old one.

```
# libfoo.map
LIBFOO_1.0 { global: foo_open; foo_close; local: *; };
LIBFOO_2.0 { global: foo_open; } LIBFOO_1.0;
```

```c
__asm__(".symver foo_open_v1, foo_open@LIBFOO_1.0");
__asm__(".symver foo_open_v2, foo_open@@LIBFOO_2.0");   /* @@ = default for new links */
```

Link with `-Wl,--version-script=libfoo.map`. Supported by GNU ld, gold, and lld on ELF. **Not available on macOS** (Mach-O has no symbol versioning; Apple used `$UNIX2003`-style name suffixes and uses availability attributes plus weak linking instead) and **not on Windows** (which uses ordinals, `.def` files, and side-by-side assemblies). Cross-platform libraries therefore usually pick the `foo_open2()` route instead, which works everywhere and is easier to explain.

The version script also does the export-restriction job. `local: *;` is more precise than `-fvisibility=hidden` because it acts at link time on the final set of symbols, including those pulled in from static archives.

**Additive function pairs.** `foo_open2(path, flags)` alongside `foo_open(path)`, with `foo_open` implemented as a wrapper. Ugly, portable, and unambiguous. Prefer it over versioning unless you have a real need to keep one name.

### Visibility and export control

Default ELF visibility exports *every* non-`static` symbol. That is a large accidental ABI, slower dynamic linking (every exported symbol needs a relocation and a symbol-table entry), and it blocks interprocedural optimization because any call could be interposed at load time.

Build shared libraries with `-fvisibility=hidden` (GCC/Clang) and annotate the intended exports:

```c
#if defined(_WIN32)
#  if defined(FOO_BUILDING_DLL)
#    define FOO_API __declspec(dllexport)
#  else
#    define FOO_API __declspec(dllimport)
#  endif
#elif defined(__GNUC__) && __GNUC__ >= 4
#  define FOO_API __attribute__((visibility("default")))
#else
#  define FOO_API
#endif

FOO_API int foo_open(const char *path);
```

Details that matter:

- `__declspec(dllimport)` is *required* for imported **data**; without it the caller reads the IAT slot as if it were the object. For functions it is a performance hint (avoids a thunk).
- `-Wl,--exclude-libs,ALL` stops symbols from static archives you link in from leaking out of your shared library.
- `-Bsymbolic` / `-Bsymbolic-functions` binds intra-library calls internally, which is faster, but it defeats legitimate interposition (`LD_PRELOAD` of `malloc`, sanitizer shims, `dlsym`-based overrides). Use it deliberately, not by default.
- CMake: `set(CMAKE_C_VISIBILITY_PRESET hidden)` plus `generate_export_header()`.

### `inline` and linkage — the part that is genuinely confusing

C's `inline` is **not** C++'s, and GNU89's `inline` is not C99's.

- **C99/C11 semantics.** A function declared `inline` in a translation unit, with no `extern` declaration of it in that TU, provides only an *inline definition*. The compiler is not required to emit an external symbol for it. If no TU in the program provides an external definition and some call is not inlined (which happens at `-O0`), you get an undefined-reference link error. The standard-blessed idiom is to put `inline int f(void) { ... }` in the header and exactly one `extern inline int f(void);` (a declaration, not a definition) in one `.c` file, which forces the external definition to be emitted there.
- **`static inline`.** Each TU gets its own private copy. No external symbol, no link-order puzzles, no ABI symbol. This is what almost all portable C uses. Costs: code duplication (usually irrelevant), and function pointers taken in different TUs may compare unequal.
- **GNU89 `extern inline`** means roughly the opposite of C99 `inline`: it provides an inline-only definition that never emits a symbol. Code written for `-std=gnu89` and compiled with `-std=gnu99` or later changes meaning. GCC defines `__GNUC_STDC_INLINE__` when it is using C99 rules and `__GNUC_GNU_INLINE__` for the old ones; `__attribute__((gnu_inline))` forces the old behavior explicitly.
- **The ABI point.** A `static inline` function in a public header is ABI surface even though it has no symbol. Its body is compiled into every caller. Changing it does not affect binaries already built. If it touches struct fields, it also freezes those offsets. Keep public-header inline functions trivial and permanent, or do not have them.
- `inline` is a hint about linkage and a suggestion about inlining; it is not a command. `__attribute__((always_inline))` (GCC/Clang) and `__forceinline` (MSVC) are commands, and mostly worth using only to make a macro-replacement actually behave like a macro.

### Allocators and error state across module boundaries

- On Windows, each DLL may link its own CRT. Memory allocated by `malloc` in one CRT and released by `free` in another is undefined behavior, and the same applies to `FILE *`, `errno`, locale, and file descriptors. **Every public API that returns allocated memory must also provide the matching `foo_free()`.** This is good practice on ELF too; on Windows it is mandatory.
- Do not expose `errno` in a public contract across a shared-library boundary. Return your own error enum.
- Do not pass C `FILE *` across a DLL boundary. Pass a file descriptor / `HANDLE`, or your own I/O callbacks.

### Verifying ABI compatibility

Build with `-g` (libabigail needs DWARF) and diff:

```sh
abidiff --harmless old/libfoo.so.1 new/libfoo.so.1     # libabigail
abi-compliance-checker -l foo -old old.xml -new new.xml
nm -D --defined-only --with-symbol-versions libfoo.so.1 | sort   # exported symbols
readelf -Ws libfoo.so.1
objdump -T libfoo.so.1
dumpbin /EXPORTS foo.dll                                # Windows
```

Keep a checked-in list of exported symbols and diff it in CI; an unreviewed new export is an unreviewed permanent commitment. Set the soname explicitly (`-Wl,-soname,libfoo.so.1`) and bump the major on any break. libtool's `current:revision:age` is a different numbering scheme from the soname major; do not mix mental models.

## Build and Target Separation

### Three machines, not two

Autoconf naming, and it is worth using precisely:

- **build** — the machine running the compiler.
- **host** — the machine that will run the artifact you are producing.
- **target** — only meaningful when the artifact is *itself* a compiler: the machine its output will run on.

The most common configuration error is passing `--target=aarch64-linux-gnu` when you meant `--host=aarch64-linux-gnu`. For ordinary libraries and programs, `--target` is not the option you want.

The corresponding discipline in a build system: some things are built to **run now, on the build machine** (code generators, table builders, `xxd`-style embedders, test-vector generators), and some are built to **ship**. They need different compilers and different flags. Mixing them produces "Exec format error" at build time — the good case — or a program built with the wrong ABI, which is the bad case.

- Make: `$(CC)` for artifacts, `$(CC_FOR_BUILD)`/`$(BUILD_CC)` for tools, with separate `BUILD_CFLAGS`.
- CMake: no first-class support; either build the tool in a separate host-toolchain build tree and import it (`find_program`/an exported target/`ExternalProject_Add`), or accept a cached `FOO_GENERATOR` path that the cross build is given.
- Meson: `native: true` on the tool's `executable()`, plus a cross file with `[binaries]`, `[host_machine]`, and `[properties]`.

### How build-host assumptions leak into targets

- **Running a probe to answer a compile-time question.** `configure` scripts that compute `sizeof(long)` or endianness by compiling *and executing* a program cannot work when cross-compiling. Autoconf's `AC_CHECK_SIZEOF` avoids this (it uses a compile-time trick); `AC_RUN_IFELSE` does not, and needs an explicit `[action-if-cross-compiling]` fallback. CMake's `try_run` similarly fails under `CMAKE_CROSSCOMPILING` unless you preseed the result cache variables. Any answer derived by running code is an answer about the build machine.
- **`-march=native` / `-mtune=native`.** Encodes the build machine's ISA into the artifact. The result illegal-instructions on any older CPU, breaks build reproducibility, and poisons shared ccache/distcc caches. Legitimate only for a benchmark or a machine-local build; never in a release or a default.
- **`uname -m` / `uname -s` in the build.** Describes the build machine. Under cross-compilation it is simply wrong. Use the compiler's own answer: `cc -dumpmachine`, or `cc -E -dM - </dev/null | grep -E '__(x86_64|aarch64|ARM|BYTE_ORDER)'`.
- **Host `pkg-config`.** Without `PKG_CONFIG_LIBDIR` and `PKG_CONFIG_SYSROOT_DIR` pointing into the sysroot, `pkg-config` hands you `/usr/lib` and `/usr/include` from the build machine. Symptom: the link picks up the host's `libc.so.6` or `libz.so` and fails with "incompatible" or, worse, succeeds with an ABI mismatch.
- **Absolute paths and environment.** `__FILE__`, `__DATE__`, `__TIME__`, `$HOME`, `$PWD`, locale-dependent sorting in generated files, and non-deterministic archive timestamps all embed the build machine into the artifact. `-ffile-prefix-map=$(PWD)=.` (GCC 8+/Clang 10+), `SOURCE_DATE_EPOCH`, deterministic `ar` (`ar -D`, default in most distributions), and a fixed link order fix these.

### Sysroots

A sysroot is the target's `/` as seen by the compiler: `<sysroot>/usr/include`, `<sysroot>/usr/lib`.

- GCC/Clang: `--sysroot=/path`. Apple: `-isysroot`. Bare metal: `-nostdinc` plus explicit `-isystem`, and `-nostdlib`/`-ffreestanding`.
- Clang is a cross-compiler out of the box: `clang --target=aarch64-linux-gnu --sysroot=/opt/sysroots/aarch64 -fuse-ld=lld`. GCC needs a separate binary per triple (`aarch64-linux-gnu-gcc`). Clang still needs a target sysroot with headers and libs — `--target` alone gives you the host's headers, which is a subtle and common misconfiguration.
- CMake toolchain file, the minimum that actually works:

```cmake
set(CMAKE_SYSTEM_NAME Linux)          # this is what sets CMAKE_CROSSCOMPILING
set(CMAKE_SYSTEM_PROCESSOR aarch64)
set(CMAKE_SYSROOT /opt/sysroots/aarch64)
set(CMAKE_C_COMPILER aarch64-linux-gnu-gcc)
set(CMAKE_FIND_ROOT_PATH /opt/sysroots/aarch64)
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)   # run build-machine tools
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)    # link target libraries
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
```

Forgetting `CMAKE_SYSTEM_NAME` leaves `CMAKE_CROSSCOMPILING` false and everything silently half-configures.

### Generated versus checked-in configuration headers

| Approach | Strengths | Weaknesses |
| --- | --- | --- |
| Generated `config.h` (autoconf, CMake `configure_file`, Meson `configure_file`) | Accurate per target and per libc version; single source of truth; adapts to new platforms without source edits | Requires a configure step; stale copies in the source tree shadow the out-of-tree one; must **never** be installed or included from a public header |
| Checked-in per-platform headers (`config_linux.h`, `config_win32.h`) | No configure step, reproducible, readable, ideal for vendored/amalgamated single-file libraries | Drifts from reality; cannot adapt to glibc-2.25-vs-2.28 differences; every new platform is a source edit |
| Compile-time detection (`__has_include`, `__has_builtin`, `__has_attribute`, version macros) | No configure step and it adapts; excellent for optional features | Compiler-dependent; `__has_include` finding a header does not prove the symbol is declared under the current feature macros |

Non-negotiables regardless of approach:

- `config.h` is included **first** in every `.c` that needs it, before any system header — because it may define `_FILE_OFFSET_BITS` and friends, which must precede `<features.h>`.
- `config.h` is **private**. A public header that includes it exports your build's macro namespace (`PACKAGE_VERSION`, `HAVE_STRINGS_H`) into your users' translation units and collides with theirs.
- One configuration per link. Static libraries built with a different `config.h` than the consumer are the same class of bug as mismatched `_FILE_OFFSET_BITS`.
- For out-of-tree builds, put the generated header in the build directory and make sure `-I<builddir>` precedes `-I<srcdir>`; a stale in-tree `config.h` from an old in-tree build is a classic multi-hour debugging session.

### Keeping target detection out of source

The goal is that adding a platform touches the build system and one port file, not three hundred source files. Concretely:

- Source contains `#if HAVE_PREADV` and `#if HAVE_STRUCT_STAT_ST_MTIM`, never `#if defined(__linux__) && !defined(__ANDROID__)`.
- Anything that genuinely differs per OS lives behind a narrow internal interface with one implementation file per platform. That interface is also the seam where you inject fakes for failure-injection tests.
- Architecture-specific code (SIMD kernels, atomics fallbacks) lives in its own translation units compiled with their own flags, selected at build time or dispatched at runtime — not `#ifdef`'d inside a shared function body where the two variants can drift.
- Every capability macro is defined to 0 or 1 by the build system, and `-Wundef` is on.

## Compiler Matrices

A compiler matrix is not a badge collection. Each entry earns its place by
catching a class of defect the others cannot, and every entry you keep costs CI
time and a stream of diagnostics somebody must triage. Decide what each column
is *for* before adding it.

### What each toolchain actually buys you

| Toolchain | Catches what others miss | Cost |
| --- | --- | --- |
| GCC | `-fanalyzer` path-sensitive checks, `-Wduplicated-cond`, `-Wlogical-op`, strongest `-Wmaybe-uninitialized` | `-fanalyzer` is slow and, on C++-adjacent or heavily macro'd code, noisy |
| Clang | Fastest sanitizers, `scan-build`/`clang-tidy`, far better diagnostics on macros and initialiser lists | Weaker interprocedural warnings than GCC's analyzer |
| MSVC | The only truth about Windows ABI, SEH, and `/analyze` annotations | Different preprocessor, no statement expressions, no VLAs |
| A cross target (e.g. `aarch64`, 32-bit `armhf`) | Wrong-sized `long`, unaligned access, signed `char` assumptions, atomics that only worked on x86's strong model | Emulation (`qemu-user`) is slow and hides some timing bugs |

The single highest-value addition to a matrix that only builds x86-64 Linux is
**not** a second x86-64 compiler; it is a target with a different word size,
alignment rule, char signedness, or memory model. `char` is signed on x86 and
ARM Linux but *unsigned* on AArch64 Linux and on PowerPC, and code doing
`char c = getchar(); if (c == EOF)` breaks only on the latter.

### Warnings as a policy, not a pile

Pick a base and treat additions as deliberate:

```
-Wall -Wextra -Wpedantic
-Wconversion -Wsign-conversion     # noisy at first, catches real truncation
-Wshadow -Wcast-qual -Wcast-align
-Wstrict-prototypes -Wmissing-prototypes
-Wwrite-strings                    # string literals become const char[]
-Wundef                            # a typo'd feature macro is silently 0 otherwise
-Wvla                              # if you have decided against VLAs, enforce it
```

`-Wall -Wextra` are not "all warnings" in either compiler; they are a curated
subset, and the list above is the part people assume is included and is not.

**`-Werror` belongs in CI, not in the shipped build.** A tarball that refuses to
compile because a *newer* compiler than you tested with added a warning is a
build break you handed to your users, and they cannot fix it. Gate it behind a
maintainer flag or a `--enable-werror` configure option, on by default only in
your own CI. This is a genuine tradeoff and reasonable projects go both ways;
what is not defensible is `-Werror` unconditionally in a release tarball.

### Where GCC and Clang genuinely diverge

These are not stylistic differences; the same source produces different
behaviour or different diagnostics.

- **`-Wmaybe-uninitialized`** exists in GCC only, and it is sensitive to
  optimization level: the same file is clean at `-O0` and warns at `-O2`,
  because the warning depends on what inlining exposed. Build the warning job at
  the optimization level you ship.
- **`-fno-common`** is the default from GCC 10 and Clang 11. Older code with a
  tentative definition in a header (`int counter;` rather than `extern int
  counter;`) linked "fine" for decades and now produces duplicate-symbol errors.
  The old behaviour is the bug; do not paper over it with `-fcommon`.
- **`-fwrapv` / `-fno-strict-aliasing`** are *dialect* changes, not warnings.
  They make specific undefined behaviours defined, which means code that builds
  clean under them can still break under a compiler invoked without them. If you
  need them, they belong in the project's required flags and in the README, not
  in one developer's local build.
- **`__has_builtin`** is available in Clang since forever and in GCC only from
  10. Guard it: `#if defined(__has_builtin)` before using it.
- **Diagnostic pragmas do not have matching spellings.** GCC's
  `#pragma GCC diagnostic ignored "-Wfoo"` is accepted by Clang, but Clang
  warns about *unknown* warning names under `-Wunknown-warning-option`, so
  suppressing a GCC-only warning in shared code needs its own `#ifdef __GNUC__`
  / `#ifdef __clang__` guard. Note that Clang also defines `__GNUC__`, so
  testing for GCC means `#if defined(__GNUC__) && !defined(__clang__)`.

### Keeping the matrix honest

A matrix job that is allowed to fail teaches the team to ignore it, and a red
square that has been red for a month conveys nothing. Either the job blocks the
merge or it is deleted. If a target is genuinely aspirational, keep it in a
scheduled nightly with an owner, not in the per-PR set.

Pin compiler versions explicitly (`gcc-13`, not `gcc`). "Latest" as a matrix
entry means your CI breaks on somebody else's release schedule, on a day you did
not choose, in a PR that has nothing to do with it.

## Profiling

Measure before you change anything. Intuition about where C spends its time is
wrong often enough that "obvious" hotspots are the standard cautionary tale, and
the cost of being wrong is not just wasted work: an optimization applied to cold
code is permanent complexity bought for nothing.

### Know what your tool samples

The tools are not interchangeable, and the differences decide which bugs you can
even see.

| Tool | Mechanism | Sees | Blind to |
| --- | --- | --- | --- |
| `perf record` | Hardware sampling (PMU), whole system | Kernel time, other processes, cache/branch counters | Very short runs; anything below the sample period |
| `gprof` | Compiler instrumentation (`-pg`) | Call counts exactly | Distorts timing badly; ignores time in uninstrumented libraries |
| Callgrind (Valgrind) | Full simulation | Exact instruction counts, deterministic and repeatable | Real time — it is 20-100x slower and simulates an idealised cache |
| Instruments / `sample` (macOS) | Sampling | Time profile with symbols, allocations | Requires codesigning entitlements to attach to some processes |
| VTune | PMU with vendor knowledge | Microarchitectural stalls, memory-bound vs core-bound | Intel-centric; heavy setup |

The distinction that trips people up: `perf` gives you *where wall time went, on
this machine, this run*, and Callgrind gives you *how many instructions ran,
reproducibly, on an idealised machine*. When a change looks good under Callgrind
and does nothing in production, the usual reason is that the real cost was a
cache miss or a branch mispredict, which Callgrind's model priced at zero.

### Getting usable output

```bash
# Frame pointers, or your call graph is fiction.
cc -O2 -g -fno-omit-frame-pointer -o app app.c

perf record -g --call-graph=fp -- ./app workload
perf report --stdio
```

Three things routinely make a profile useless:

- **`-O0` profiles.** Profiling an unoptimized build measures a program you do
  not ship. Inlining changes the shape of the call graph entirely. Always
  profile at the release optimization level, with `-g` added.
- **Missing frame pointers.** `-O2` implies `-fomit-frame-pointer`, and without
  either frame pointers or DWARF unwinding (`--call-graph=dwarf`, larger and
  slower) the call graph silently attributes everything to the wrong parent.
  `--call-graph=lbr` on recent Intel is cheaper than DWARF where available.
- **Stripped or split symbols.** Addresses without symbols produce a profile of
  hex numbers. Keep the unstripped binary or the separate `.debug` file.

### Profile the workload, not the benchmark

The input decides the profile. A parser profiled on a 200-byte document spends
its time in setup; the same parser on a 200 MB document spends it in the inner
loop, and those two profiles recommend opposite changes. Profile with production
inputs, or with a workload you can defend as representative of one.

Watch for the run being dominated by startup: if the process lives 40 ms, a
default 4000 Hz sample rate gives you roughly 160 samples total, which is noise.
Loop the workload inside the process until the steady state dominates.

### Reading a profile without fooling yourself

Self time and cumulative time answer different questions. A function with 60%
cumulative and 2% self time is a *router*, not a hotspot; optimizing its body
gains nothing, and the real cost is in one of its callees. Flame graphs make
this legible at a glance, which is most of why they are worth generating.

Flat profiles, where nothing exceeds a few percent, are a real and common
result. They mean there is no hotspot to fix, and the remaining wins are
structural: doing less work, a better algorithm, or a different data layout.
Micro-optimizing a flat profile is how weeks disappear.

## Benchmarking

A microbenchmark is an experiment, and most C microbenchmarks are broken in ways
that produce confident, reproducible, wrong numbers. The failure mode is not
noise you can see; it is a measurement of something other than what you meant.

### The compiler deletes your benchmark

This is the first thing to check, every time:

```c
/* Measures nothing. hash() is pure, the result is unused, so the whole
   loop is dead code and a good compiler removes it entirely. */
uint64_t t0 = now_ns();
for (size_t i = 0; i < N; i++)
    hash(data, len);
uint64_t t1 = now_ns();
```

The tell is a timing that does not change when you vary `N`, or a per-iteration
cost below one nanosecond. Force the work to be observable:

```c
static void consume(void *p) { __asm__ volatile("" :: "r"(p) : "memory"); }

uint64_t acc = 0;
for (size_t i = 0; i < N; i++) {
    acc ^= hash(data, len);
    consume(&acc);          /* the compiler must now materialise acc */
}
```

`volatile` on the accumulator also works, but it forces a store *and a reload*
each iteration, which adds cost you did not intend to measure. The empty-asm
barrier is the smaller hammer. Note this is a GCC/Clang extension; MSVC needs
`_ReadWriteBarrier()` or an exported sink function.

### What makes runs differ that has nothing to do with your change

- **Frequency scaling and thermal state.** The first run is on a cold, boosting
  core; the tenth is on a throttled one. Pin the governor (`cpupower frequency-set
  -g performance`), or accept that a 5% difference is unmeasurable on a laptop.
- **CPU migration.** Pin the process (`taskset -c 2`) so the cache it warmed
  stays the cache it uses. On a NUMA box add `numactl --membind`.
- **ASLR and code/data alignment.** This is the one people disbelieve. Changing
  an unrelated function's length shifts everything after it, and loop-buffer or
  cache-set alignment can move a hot loop by several percent with no
  instruction changed. Real measurements of link-order effects have found swings
  large enough to swamp the change under test. If a result is under ~5% and you
  cannot reproduce it across relinks, you have not measured anything.
- **Turbo, hyperthreading, and a noisy neighbour.** A sibling hyperthread doing
  work halves your effective throughput. Idle the machine or use an isolated
  core (`isolcpus`).

### Reporting a result

Report the *distribution*, not one number. Run the benchmark many times as
separate processes (which re-rolls ASLR and layout), and give minimum, median,
and spread.

Minimum is the most stable estimator of "how fast can this go" because noise is
one-directional: interference only ever makes a run slower. Median is the
better answer to "what will a user see". Mean plus standard deviation is the
worst of the three here, because the distribution is heavily right-skewed and
the mean chases outliers.

Then state the machine, the compiler and version, the exact flags, and the
input. A benchmark result without those is not reproducible, and a benchmark
nobody can reproduce is an assertion.

### Prefer a real workload

Microbenchmarks answer "is this function faster in isolation". That question
often has a different answer from "is the program faster", because in isolation
the function owns the whole cache, the branch predictor sees one pattern and
learns it perfectly, and the allocator is in a state no real run reaches. When
the two disagree, the whole-program measurement is the one that matters.

## Optimization

The order of operations is algorithmic complexity, then memory access patterns,
then everything else, and the gap between the first two and the rest is usually
an order of magnitude. Reaching for instruction-level tricks before the data
layout is settled is the most common way to spend effort and get nothing.

### Optimization levels are an empirical question

`-O3` is not "more optimized than `-O2`" in any guaranteed sense. It enables
more aggressive inlining and vectorization, which increases code size, which can
cost more in instruction-cache misses than the vectorization gains. `-Os`
sometimes beats both on code that is bound by i-cache pressure rather than
arithmetic.

| Level | Bias | Typically wins on |
| --- | --- | --- |
| `-O1` | Compile speed, debuggability | Debug-adjacent builds |
| `-O2` | Balanced; the default for most projects | Almost everything |
| `-O3` | Aggressive inline + vectorize, bigger code | Numeric kernels, tight hot loops |
| `-Os` / `-Oz` | Size | Large codebases with diffuse hot paths, embedded |
| `-Ofast` | `-O3` plus `-ffast-math`, **breaks IEEE semantics** | Rarely worth it; see below |

Measure your program at each; do not inherit somebody else's answer.

`-Ofast` (and `-ffast-math` alone) deserves a specific warning: it permits
reassociation of floating-point operations, assumes no NaNs or infinities, and
flushes denormals. That silently breaks Kahan summation, any NaN-based sentinel,
and most numerical error analysis, and in a shared library it can set the FTZ/DAZ
bits process-wide, changing the behaviour of code that never opted in.

### LTO, and what it costs

Link-time optimization gives the compiler cross-translation-unit visibility, so
it can inline across files and drop genuinely unreachable code. It pairs
naturally with `-fvisibility=hidden`: the fewer symbols that must be preserved
for external linkage, the more it can prove.

The costs are real and worth stating plainly. Link times rise substantially.
Debug information gets worse, because inlining across files makes stack traces
harder to relate to source. Build reproducibility becomes more sensitive to
linker and plugin versions. And LTO turns latent ODR-ish problems and
undefined behaviour into *visible* misbehaviour more often, because more
aggressive interprocedural analysis exploits assumptions that were previously
never tested. That last point is a feature disguised as a cost: the bug was
always there.

### Undefined behaviour is an optimization input

This is the mechanism behind "it worked at `-O0` and broke at `-O2`", and it is
worth being precise about, because it makes bug reports version-dependent.

```c
int check(int *p) {
    int v = *p;           /* dereference: compiler may now assume p != NULL */
    if (p == NULL)        /* ...so this test is dead, and is deleted */
        return -1;
    return v;
}
```

The null check does not survive, because dereferencing `p` above it would be
undefined if `p` were null, and the compiler is entitled to assume no undefined
behaviour occurs. Nothing warns by default. Similarly, signed overflow being
undefined is what lets `x + 1 > x` fold to `true`, which is why the overflow
check written that way does not work.

The consequence for optimization work: you cannot reason about what the
optimizer will do to code that has undefined behaviour anywhere in it, and
"faster at `-O3`" is meaningless if the program is UB-free only by accident.
Run the sanitizers (see `verification.md`) *before* trusting an optimization
result, not after shipping it.

### Profile-guided optimization

PGO gives the compiler real branch frequencies and hot/cold splitting, and on
branch-heavy code (interpreters, parsers, compilers) it delivers gains that no
amount of manual hinting matches. `__builtin_expect` is a poor substitute: it
covers one branch, it is frequently wrong, and it goes stale silently.

The cost is workflow, not compile flags. You need an instrumented build, a
representative training workload, a profile-merge step, and then the real build,
which means the build is no longer a single command and CI must carry the
profile as an artifact. A stale or unrepresentative profile is worse than none:
it confidently marks the wrong paths hot. Adopt PGO when someone owns the
training workload; skip it otherwise.

### Things worth doing before micro-optimizing

- **Shrink the working set.** Smaller structs, fewer pointer indirections, and
  arrays of structs turned into structs of arrays for the fields a loop actually
  touches. Cache misses dominate almost everything else.
- **Batch the work.** One call that processes 1000 items beats 1000 calls,
  independent of what is inside.
- **Stop allocating in the inner loop.** Reuse buffers; an arena for a
  phase-scoped lifetime removes both the allocator cost and the free-order bugs.
- **Let the compiler vectorize.** `-fopt-info-vec-missed` (GCC) or
  `-Rpass-missed=loop-vectorize` (Clang) tells you *why* it did not, and the
  answer is usually a possible-aliasing assumption that `restrict` or a local
  copy of a loop bound resolves. Reach for intrinsics only after this fails,
  and keep a portable fallback beside them.

Finally: keep the unoptimized version. A clear reference implementation that the
optimized path is differentially tested against (same inputs, same outputs, as
in `verification.md`) is what makes an optimization safe to keep. Optimized code
with no oracle is a bug that has not been noticed yet.
