# Kelvin design

This file holds the cumulative design results. How each decision was reached
is recorded in [Dialogue.md](Dialogue.md), and a C programmer's guide to the
differences is in [versusC.md](versusC.md).

## Principles

- **A quiet alternative to C.** No bloat, and no intention of becoming C++.
- **100% C ABI compatibility.** A Kelvin program is a C program with
  different spelling. Types, layout, calling conventions and semantics are
  C's.
- **Start with bare C and change it bit by bit.** Every departure from C is
  proposed, discussed and agreed on one at a time, then recorded here.
- **The preprocessor is TODO**, except `#import <x.h> as C` (#12).

### The name

C is also the symbol for Celsius, and Kelvin is its natural successor. The
step size is the same, so everything you know about C carries over one to
one, but it sits on an absolute scale. The source extension is `.k`.

## Status: v0.0.1 (bare C baseline)

`kelvinc` translates Kelvin into C and hands the result to the C compiler
(`$CC`, which defaults to `cc`). It has no type checker of its own. The C
compiler checks everything, so semantics and ABI are C's by construction.
`#line` directives make C compiler diagnostics point at the `.k` source.

## Agreed changes from C

| # | Change | C | Kelvin | Agreed |
|---|--------|---|--------|--------|
| 1 | The type comes after the name | `int x = 0;` | `var x: i32 = 0;` | 2026-10-01 |
| 2 | Postfix `^` for pointer types | `char *p;` | `var p: u8^;` | 2026-10-01 |
| 3 | Postfix `^` to dereference | `*p`, `p->m` | `p^`, `p^.m` | 2026-10-01 |
| 4 | XOR is binary `~` | `a ^ b`, `a ^= b` | `a ~ b`, `a ~= b` | 2026-10-01 |
| 5 | Functions use `name: type` too, with no `fn` and no `->` | `long add(long a, long b)` | `add(a: i64, b: i64): i64` | 2026-10-01 |
| 6 | Integer types always say their size, and are built in | `int32_t` (via `<stdint.h>`) | `i8 i16 i32 i64 u8 u16 u32 u64`, plus `i128 u128` where available | 2026-10-01 |
| 7 | C's integer names are gone | `char`, `short`, `int`, `long`, `signed`, `unsigned` | `u8` (or `i8`), `i16`, `i32`, `i64`/`u64`, ... | 2026-10-01 |
| 8 | An inferred integer is `i64`; a written type is always explicit | | `var i = 42;` is `var i: i64 = 42;` | 2026-10-01 |
| 9 | Floating-point types say their size too | `float`, `double` | `f32`, `f64` | 2026-10-01 |
| 10 | `bool` is built in | `_Bool` (or `bool` via `<stdbool.h>`) | `bool` | 2026-10-01 |
| 11 | An inferred C double literal is `f64` | `double d = 1.5;` | `var d = 1.5;` | 2026-10-01 |
| 12 | C headers are importable | `#include <stdio.h>` | `#import <stdio.h> as C` | 2026-10-01 |
| 13 | Literals carry no size hints; the declaration carries the type | `10UL`, `1.5f` | `val: u64 = 10`, `f: f32 = 1.5` | 2026-10-01 |

Notes:

- (2, 3) `*` means only multiplication. `p^^` is `**p`, and `p++^` is
  `*p++`. Postfix operators apply left to right, so `p^[i]` is `(*p)[i]`.
- (4) Unary `~` is still bitwise NOT, in the same way that `-` is both unary
  and binary. Since `^` never means XOR, `p^ = x` is always an assignment
  through `p`, which is why `^=` is not a token.
- (5) Types are always written `name: type`, even for functions. A
  function's type follows its parameter list. A top-level `name(` starts a
  function, and a prototype ends with `;` instead of a body.
- (6) These map to `<stdint.h>` types (`i32` is `int32_t`), plus
  `__int128` and `unsigned __int128` for `i128`/`u128`. The generated C
  includes `<stdint.h>` itself, so Kelvin source still needs no
  preprocessor. `i128`/`u128` only compile where the C compiler supports
  `__int128` (gcc and clang on 64-bit targets).
- (7) Using a C integer name is an error that suggests the replacement, e.g.
  `'long' is not a Kelvin type; use i64 or u64 (or i128/u128)`. The words
  stay reserved, because they are still C keywords in the generated code.
- (8) For now only integer literals (optionally negated) are inferred, in
  `var` declarations: `var x = y + 1;` or `var f = 1.5;` still need a type.
- (9, 10) `float`, `double` and `_Bool` are errors that suggest `f32`,
  `f64` and `bool`. The generated C includes `<stdbool.h>`.
- (11) This extends #8. A literal with a `.` or an exponent is `f64`.
  `true`/`false` are not inferred: `var b = true;` needs `: bool` (Q8
  answered no).
- (12) `#import <x.h> as C` or `#import "x.h" as C` becomes `#include`.
  Everything the header declares is usable from Kelvin. It is the only
  directive, and the rest of the preprocessor is still TODO.
- (13) C's suffixes `u`, `l`, `ll`, `f` and their combinations are errors
  that suggest the typed declaration, e.g. `'10UL': literals have no
  suffixes in Kelvin; put the type on the declaration, e.g. 'x: u64 = 10'`.
  Hex digits `a`–`f` are of course not suffixes: `0xff` is fine. An
  unsuffixed literal still has C's type (`1` is an `int`), so C's
  `1UL << 40` is written `(u64)1 << 40`.

## Provisional decisions (made during implementation; please review)

These follow from the agreed changes, or were needed to write any code at
all. None of them has been explicitly agreed yet.

| # | Decision | Example | Why |
|---|----------|---------|-----|
| P1 | Array brackets are postfix too | `var a: i32[4];` | Mixing postfix `^` with prefix `[4]` would make `[4]i32^` ambiguous |
| P2 | Type suffixes apply left to right, but a run of brackets reads in C order | `i32^[4]` is `int32_t *[4]`, `i32[4]^` is `int32_t (*)[4]`, `i32[2][3]` is `int32_t[2][3]` | So that `m: i32[2][3]` indexes as `m[1][2]`, exactly as in C |
| P3 | Variable declarations start with `var` | `var x: i32;` | Carried over from v0.1. Change #5 removed `fn`; whether `var` should go too is an open question (see below) |
| P4 | `()` means no parameters | `f(): i32` is `int32_t f(void)` | C's `()` (unspecified parameters) is obsolescent |
| P5 | No `: type` after a function means `void` | `f()` is `void f(void)` | Same as v0.1 |
| P6 | Qualifiers bind to what is on their left; a leading qualifier binds to the base | `u8 const^` and `const u8^` are both `const uint8_t *`; `u8^ const` is `uint8_t *const` | This is C's rule, written postfix |
| P7 | Several names per `var` | `var a: i32 = 1, b: u8^;` | Each name has its own full type, since C's `int a, *b` split is gone |
| P8 | Struct and union members end with `;` | `struct p { x: i32; y: i32; };` | Kept from C, as is the `;` after `}` |
| P9 | Storage class goes in front | `static f(): i32`, `static var`, `extern var` | Kept from C |
| P10 | Anonymous enums are allowed | `enum { LIMIT = 3 };` | The common C idiom for constants |
| P11 | Kelvin reserves `var` and the sized type names | | C code that uses them as identifiers cannot be named from Kelvin yet |
| P12 | Literals are passed through verbatim (minus suffixes, #13) | `0x1f`, `017`, `0b101`, `'\n'`, `"a" "b"` | So C interprets them exactly as it always has. Octal `017` and C23's `0b` stay |
| P13 | `u8` and C's `char` mix freely | `var s: u8^ = "hi";`, `printf(fmt: const u8^, ...): i32;`, `main(argc: i32, argv: u8^^): i32` | Follows from #7. String literals and libc use `char`, while `u8` is `unsigned char`. They are ABI-identical, so kelvinc silences C's pointer-sign and library-redeclaration warnings, and emits `main`'s `argv` as `char **`, which C requires |
| P14 | `true` and `false` are built in alongside `bool` | `var done: bool = false;` | `<stdbool.h>` provides all three together, and a `bool` without them would be half a feature. They are reserved words |
| P15 | Any identifier after `:` is a type name | `var f: FILE^ = stdout;`, `var n: size_t;` | Needed for #12: headers define typedef names that Kelvin cannot know without reading them. After `:` a type is certain, so this is unambiguous |
| P16 | `#import` details | `#import "x.h" as C` | Top level only, at the start of a line. A quoted header is searched next to the `.k` file (kelvinc passes `-I<dir of .k>`), since the generated C lives in a temp directory |

## Open questions

- **Q1: Drop `var` as well?** Following change #5, `x: i32 = 0;` would
  declare a variable. That is unambiguous because no Kelvin statement can
  start with a type, so `x: i32` is never a goto label.
- ~~**Q2: `i64`-style type names?**~~ Answered: yes, see changes #6–#8.
- ~~**Q3: `float`/`double`?**~~ Answered: `f32`/`f64` (change #9).
  `long double` has no Kelvin spelling yet.
- ~~**Q4: `_Bool`?**~~ Answered: built-in `bool` (change #10).
- **Q5: `size_t`?** `sizeof`, `malloc` and `strlen` all use it. Should Kelvin
  have `usize`/`isize`, or should programs use `u64`/`i64`?
- ~~**Q6: Integer literal suffixes.**~~ Answered: no suffixes at all (#13).
- **Q7: Printing `i64`.** `int64_t` is `long long` on macOS but `long` on
  Linux, so no single `printf` format fits both. `#import <inttypes.h> as C`
  now provides `PRId64`, but `"%" PRId64 "\n"` (a string pasted to a macro)
  does not parse. With `<stdio.h>` imported, C checks formats again and
  warns about the mismatch. A hand-written `printf` prototype gets no
  checking.
- ~~**Q8: Infer more than integers?**~~ Answered: no. Only integer (`i64`)
  and floating (`f64`) literals are inferred (#8, #11), and `bool` must be
  written.
- **Q9: Casts to C typedef names.** `(size_t)x` or `(FILE^)p` does not parse.
  Inside parentheses, `size_t` could be a type or a variable, which is C's
  own typedef ambiguity. C solves it with a symbol table built from the
  headers. Kelvin would need to read headers, or use a different cast
  syntax.

## Unchanged from C (on purpose, for now)

These are everything else: operator precedence (including `==` binding
tighter than `&`), implicit conversions, integer promotion (to C's `int`,
which is `i32` on every supported target), integer truthiness, assignment as an expression, `++`/`--`, the comma operator,
`?:`, `if`/`while`/`do`/`for`/`switch`/`goto`, casts `(T)x` (with Kelvin
type spelling), compound literals, designated initializers, arrays that
decay to pointers, declare-before-use, `struct`/`union`/`enum` tags, and all
undefined behavior.

## TODO (C features not yet expressible in Kelvin)

- The rest of the preprocessor (`#define`, `#if`, ...). Headers are
  covered by `#import ... as C`.
- `typedef`
- Function pointer types
- Bit-fields
- Nested or anonymous struct/union definitions inside other declarations
- `inline`, `restrict`, `register`, `_Alignas`, `_Static_assert`,
  `_Generic`, `_Atomic`, `_Thread_local`, `_Noreturn`
- String prefixes (`L"..."`, `u8"..."`)
- Unnamed parameters in prototypes
- Local struct/union/enum definitions (only top-level definitions work)

## Ideas tried in v0.1 and set aside

The first cut (PR #1, before this reset) went much further than bare C.
These features were removed, and any of them could come back only as an
individual proposal:

- runtime traps instead of undefined behavior (overflow, bounds, null)
- slices `[]T`, arrays as values, `defer`, `let` (immutability)
- `i32`/`u8`-style type names, wrapping operators `+%`
- stricter typing (no implicit conversions, `bool`-only conditions)
- order-independent declarations

## Implementation

| File | Role |
|------|------|
| `src/lexer.c` | C's lexical rules. Kelvin keywords `var`, `i8`…`u128`, `f32`, `f64`, `bool`, `true`, `false`; `~=`, no `^=` |
| `src/parser.c` | Recursive descent over C's grammar with the changes above |
| `src/codegen.c` | Prints C: postfix types become C declarators, `i32` becomes `int32_t` and `f64` becomes `double`, `p^` becomes `(*p)`, `~` becomes `^` |
| `src/main.c` | Driver: writes the C, runs `$CC` with `-I<dir of .k>`, and optionally runs the program |
| `tests/run.sh` | `tests/run/*.k` check output; `tests/error/*.k` check diagnostics |

The driver adds `$KELVIN_CFLAGS` to the C compiler command line, for
libraries (`-lcurl`) and other flags. `--emit-c --no-line` shows the
generated C without `#line` directives.
