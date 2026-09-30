# Kelvin versus C

This is a reference for C programmers. It lists every way Kelvin differs
from C, as of the current compiler. Anything not listed here works exactly
as in C, including the semantics, the ABI, operator precedence, implicit
conversions and undefined behavior.

Items marked *(provisional)* were chosen during implementation and have not
been agreed yet. See the P-numbers in [Design.md](Design.md).

## At a glance

| C | Kelvin |
|---|--------|
| `int x = 0;` | `var x: i32 = 0;` |
| `long n = 42;` | `var n = 42;` (inferred as `i64`) |
| `double d = 1.5;` | `var d = 1.5;` (inferred as `f64`) |
| `char *s;` | `var s: u8^;` |
| `int *a[4];` | `var a: i32^[4];` *(provisional)* |
| `int (*p)[4];` | `var p: i32[4]^;` *(provisional)* |
| `const char *const s;` | `var s: const u8^ const;` |
| `long add(long a, long b) { ... }` | `add(a: i64, b: i64): i64 { ... }` |
| `void f(void);` | `f();` |
| `static int g(void);` | `static g(): i32;` |
| `int main(int argc, char **argv)` | `main(argc: i32, argv: u8^^): i32` |
| `struct p { int x, y; };` | `struct p { x: i32, y: i32; };` |
| `*p` | `p^` |
| `**pp` | `pp^^` |
| `*p++` | `p++^` |
| `p->m` | `p^.m` |
| `a ^ b`, `a ^= b` | `a ~ b`, `a ~= b` |
| `(unsigned char)c` | `(u8)c` |
| `sizeof(long)` | `sizeof(i64)` |
| `#include <stdio.h>` | `#import <stdio.h> as C` |

## Declarations

Every declaration is written `name: type`, with the name first and the type
after a colon.

- **Variables** start with `var` *(provisional P3)*: `var x: i32;`, and
  `var a: i32 = 1, b: u8^;` declares several at once *(provisional P7)*.
  Each name has its own complete type, so C's `int a, *b` split cannot
  happen.
- **Functions** have no keyword. The return type follows the parameter
  list after a colon: `add(a: i64, b: i64): i64 { ... }`.
  - A prototype ends with `;` instead of a body.
  - With no `: type`, the function returns `void` *(provisional P5)*.
  - Empty parentheses mean no parameters, i.e. C's `(void)` *(provisional P4)*.
- **Parameters** must be named: `f(n: i32)`. C's unnamed `f(int)` is not
  available yet.
- **Struct and union members** follow the same form and end with `;`:
  `struct p { x: i32; y: i32; };` *(provisional P8)*.
- **Storage classes** go in front: `static f(): i32`, `static var n: i32`,
  `extern var e: i32` *(provisional P9)*.
- There is no C-style declaration. `int x;` is an error, and so is `int`
  itself (see below).

## Types

### Numeric types always say their size

| Kelvin | C |
|--------|---|
| `i8` `i16` `i32` `i64` | `int8_t` `int16_t` `int32_t` `int64_t` |
| `u8` `u16` `u32` `u64` | `uint8_t` `uint16_t` `uint32_t` `uint64_t` |
| `i128` `u128` | `__int128`, `unsigned __int128` (where the C compiler has them) |
| `f32` `f64` | `float`, `double` |
| `bool` | `bool` from `<stdbool.h>`, i.e. `_Bool` |

C's `char`, `short`, `int`, `long`, `signed`, `unsigned`, `float`, `double`
and `_Bool` are errors that suggest the Kelvin name. As a result:

- There is no plain `char`. Use `u8`, or `i8` for signed bytes.
- `long double` has no Kelvin spelling yet.
- `true` and `false` are built in *(provisional P14)*.
- `f32 _Complex` and `f64 _Complex` are C's complex types.

Kelvin's built-in types need no header, and neither do `<stdint.h>` and
`<stdbool.h>`, because the generated C includes those two itself.

### `u8` and C's `char` mix freely *(provisional P13)*

C string literals are `char` arrays, and libc takes `char *`. Kelvin's `u8`
is `unsigned char`, which has the same size, representation and ABI. So
`var s: u8^ = "hi";` and passing a `u8^` to `strlen` just work. kelvinc
silences C's pointer-sign warnings about the mix, and emits `main`'s `argv`
as `char **`, because C requires that.

### Pointers and arrays are postfix

- `T^` is a pointer to `T`. `*` only means multiplication.
- `T[N]` is an array of N `T` *(provisional P1)*. Suffixes read left to
  right: `i32^[4]` is an array of four pointers, and `i32[4]^` is a pointer
  to an array. A run of brackets keeps C's order, so `i32[2][3]` indexes as
  `m[1][2]` *(provisional P2)*.
- C's hardest declarators become readable. A function returning a pointer to
  an array of four ints, `int (*f(void))[4]`, is `f(): i32[4]^`.

### Qualifiers

`const` and `volatile` apply to whatever is on their left. A leading
qualifier applies to the base type, which is C's own rule
*(provisional P6)*. `u8 const^` and `const u8^` are both `const uint8_t *`,
and `u8^ const` is `uint8_t *const`.

### C typedef names

After a colon, any identifier is accepted as a type, so typedefs from
imported headers work: `var f: FILE^ = stdout;` and
`var n: size_t = strlen(s);`. Casts to typedef names such as `(size_t)x` do
not parse yet (open question Q9).

### Type inference

`var` without a type infers it from a literal initializer:

- an integer literal is `i64`: `var i = 42;`, `var m = -1;`
- a C double literal is `f64`: `var d = 1.5;`, `var e = 1e9;`

Anything else needs a written type, including `var y = x + 1;`, `1.5f`
(C's float) and `1.5L` (C's long double). A written type is always what you
get: `var b: u8 = 42;` is a `u8`.

## Expressions

| C | Kelvin | Note |
|---|--------|------|
| `*p` | `p^` | Postfix, so it chains left to right: `p^[i]` is `(*p)[i]` |
| `p->m` | `p^.m` | `->` is an error with a hint |
| `a ^ b` | `a ~ b` | `~` keeps its C precedence slot for XOR |
| `a ^= b` | `a ~= b` | `p^ = x` is always an assignment through `p` |
| `~a` | `~a` | Unary `~` is still bitwise NOT |
| `(int)x` | `(i32)x` | Casts use Kelvin type spelling |

Everything else is C's, including precedence, so `6 & 3 == 3` is still
`6 & (3 == 3)`. The same goes for integer promotion, implicit conversions,
truthiness, `?:`, `,`, `++`/`--`, compound literals and designated
initializers.

## Statements

Only declarations differ: they start with `var`, as does a declaration in
`for (var i: i32 = 0; ...)`. `if`, `while`, `do`, `for`, `switch`, `case`,
`goto` and labels are C's.

## Headers and the preprocessor

- `#import <header.h> as C` includes a C header, and everything it declares
  can be used: functions, typedef names, macros like `stdout`, `NULL` or
  `EOF`, and enums.
- `#import "mylib.h" as C` is looked up next to the `.k` file first.
- `as C` is required. It leaves room for importing other kinds of files
  later.
- Every other directive (`#include`, `#define`, `#if`, ...) is an error.
  The rest of the preprocessor is TODO.
- Without an import you can still declare C functions by hand:
  `printf(fmt: const u8^, ...): i32;`. Don't do both, because a
  hand-written prototype conflicts with the header's.

## Reserved words

Kelvin reserves all of C's keywords, plus `var`, `i8` … `u128`, `f32`,
`f64`, `bool`, `true` and `false` *(provisional P11)*. `fn` is not reserved.

## Not available yet

These are C features without a Kelvin spelling so far:

- `typedef`
- function pointer types (a Kelvin function can still be passed to C, as in
  `qsort(p, n, sizeof(i32), cmp)`)
- bit-fields
- unnamed parameters
- nested or local struct/union/enum definitions
- `long double`
- string prefixes (`L"..."`)
- `inline`, `restrict`, `_Alignas`, `_Static_assert`, `_Generic`
- casts to C typedef names
- the preprocessor beyond `#import`

## Diagnostics

The C compiler checks Kelvin programs, and `#line` directives make its
errors and warnings point at your `.k` file and line. Kelvin's own syntax
errors also carry hints for C habits, such as `*p`, `p->m`, `int x;` or
`long`.
