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
| 1 | The type comes after the name | `int x = 0;` | `x: i32 = 0;` | 2026-10-01 |
| 2 | Postfix `^` for pointer types | `char *p;` | `p: u8^;` | 2026-10-01 |
| 3 | Postfix `^` to dereference | `*p`, `p->m` | `p^`, `p^.m` | 2026-10-01 |
| 4 | XOR is binary `~` | `a ^ b`, `a ^= b` | `a ~ b`, `a ~= b` | 2026-10-01 |
| 5 | Functions use `name: type` too, with no `fn` and no `->` | `long add(long a, long b)` | `add(a: i64, b: i64): i64` | 2026-10-01 |
| 6 | Integer types always say their size, and are built in | `int32_t` (via `<stdint.h>`) | `i8 i16 i32 i64 u8 u16 u32 u64`, plus `i128 u128` where available | 2026-10-01 |
| 7 | C's integer names are gone | `char`, `short`, `int`, `long`, `signed`, `unsigned` | `u8` (or `i8`), `i16`, `i32`, `i64`/`u64`, ... | 2026-10-01 |
| 8 | An inferred integer is `i64`; a written type is always explicit | | `i = 42;` is `i: i64 = 42;` | 2026-10-01 |
| 9 | Floating-point types say their size too | `float`, `double` | `f32`, `f64` | 2026-10-01 |
| 10 | `bool` is built in | `_Bool` (or `bool` via `<stdbool.h>`) | `bool` | 2026-10-01 |
| 11 | An inferred C double literal is `f64` | `double d = 1.5;` | `d = 1.5;` | 2026-10-01 |
| 12 | C headers are importable | `#include <stdio.h>` | `#import <stdio.h> as C` | 2026-10-01 |
| 13 | Literals carry no size hints; the declaration carries the type | `10UL`, `1.5f` | `val: u64 = 10`, `f: f32 = 1.5` | 2026-10-01 |
| 14 | No `(T)v` casts: convert with `T(v)` or `v as T` | `(int)x`, `(int *)malloc(n)` | `i32(x)`, `malloc(n) as i32^` | 2026-10-01 |
| 15 | No `var`: `x: T = v` declares, and so does `x = v` when `x` is not declared yet | `int32_t x = 0; long i = 42;` | `x: i32 = 0; i = 42;` | 2026-10-01 |
| 16 | `expr:T` annotates any expression; it means `expr as T` | `(uint16_t)0xdead`, `1UL << 40` | `0xdead:u16`, `1:u64 << 40` | 2026-10-01 |
| 17 | A prelude with `print()` and `println()`, in `libkelvin.{a,so,dylib}` | `printf("%" PRId64 "\n", n)` | `println(n)` | 2026-10-01 |
| 18 | Every type has methods; `toString()` is mandatory; `fmt()` a la Raku | `snprintf(buf, n, "%a", pi)` | `pi.fmt("%a")`, `p.toString()`, `point.area(): f64 { ... }` | 2026-10-01 |
| 19 | `:=` assigns references (pointers); `=` assigns values | `int64_t *buffer = malloc(8 * 1024); p = q;` | `buffer := malloc(8 * 1024):i64^; p := q;` | 2026-10-01 |
| 20 | No `void`: `any^` is C's `void *`, `nullptr` is `(void *)0`, and `ptr: any^;` means `ptr := nullptr` | `void *p = NULL;` | `p: any^;` | 2026-10-02 |
| 21 | Properties: `x.size` is `sizeof(x)`; integers have `.dec`, `.hex`, `.oct` and `.bin`, and `f32`/`f64` have `.dec` and `.hex`, as `u8^` text in a stack buffer | `sizeof x`, `snprintf(buf, n, "%#x", x)` | `x.size`, `x.hex` | 2026-10-02 |

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
- (8) Only literals (optionally negated) are inferred, and only in `var`
  declarations: `x = y + 1;` still needs a type. #11 extends this to
  floating literals.
- (9, 10) `float`, `double` and `_Bool` are errors that suggest `f32`,
  `f64` and `bool`. The generated C includes `<stdbool.h>`.
- (11) This extends #8. A literal with a `.` or an exponent is `f64`.
  `true`/`false` are not inferred: `b = true;` needs `: bool` (Q8
  answered no).
- (12) `#import <x.h> as C` or `#import "x.h" as C` becomes `#include`.
  Everything the header declares is usable from Kelvin. It is the only
  directive, and the rest of the preprocessor is still TODO.
- (13) C's suffixes `u`, `l`, `ll`, `f` and their combinations are errors
  that suggest the typed declaration, e.g. `'10UL': literals have no
  suffixes in Kelvin; put the type on the declaration, e.g. 'x: u64 = 10'`.
  Hex digits `a`–`f` are of course not suffixes: `0xff` is fine. An
  unsuffixed literal still has C's type (`1` is an `int`), so C's
  `1UL << 40` is written `1:u64 << 40` (#16).
- (14) Both forms have exactly C's cast semantics: `i32(3.9)` is 3 and
  `u8(300)` is 44. `T(v)` takes exactly one value, and a statement may
  start with one. `(T)v` is an error that suggests the
  replacements.

  Kelvin cannot see C typedefs or macros, which leaves C room to read
  Kelvin text differently from how Kelvin parsed it. These guards keep
  that from happening silently:
  - **Casts to typedef names.** `(size_t)n` is caught by the token after
    `)`: a value, `!`, `sizeof`, `true`/`false`, a converter, or
    `++`/`--` before a name. `(T *)p` and `(T const *)p` are caught by
    their shape.
  - **Parenthesized names before an operand.** In `(size_t)-1`,
    `(size_t)(n)` or `(int32_t)*p`, Kelvin reads a subtraction, call or
    multiplication. Where a parenthesized name, call or index is followed
    by an operand (before a binary `-`, `+`, `*` or `&`, or as a callee),
    it is emitted with double parentheses: `((size_t)) - 1`. C never reads
    that as a cast, so it rejects the line instead. Elsewhere parentheses
    are printed as written, so `__attribute__((fallthrough))` and macro
    arguments are untouched. Under `sizeof`, a parenthesized operand other
    than a lone name is also doubled.
  - **C declarations at the start of a statement or `for` initializer.**
    These are rejected with the Kelvin spelling as a hint. A shape counts
    only when its declarator ends with `;`, `,` or `=`, so
    `n * f(x) == 4 || g();` stays an expression. Examples:
    - `i32 * r = &x;` suggests `r: i32^`, and `const u8 *s` suggests
      `s: const u8^`.
    - `size_t a[3];` suggests `a: size_t[3]`, `static size_t m;`
      suggests `static m: size_t`, and `size_t * (p) = q;` and
      `size_t * p^ = &q;` are caught too.
    - `size_t f(void);` points to function syntax, and a C function-pointer
      declarator is reported as not available yet.
    - `F ~ cb = 0;` is rejected, because Apple's clang reads the emitted
      `F ^ cb` as a block pointer.
  - **C compiler keywords** that act as prefix operators or type
    specifiers in C (`__extension__`, `__real__`, `typeof`, `_BitInt`,
    `__signed__`, ...) are rejected (P20). `_Pragma("...")` is allowed
    only as a statement of its own.
  - **Emitted form.** `T(v)` becomes `((T)(v))`, which groups `v` even when
    it is an unparenthesized macro such as `1.5 + 2.5`. `v as T` becomes
    `(T)v`, which is exactly C's cast.

  Known limitations, which follow from Kelvin not reading C headers. The
  user decided to keep the current guards and accept these, rather than
  read headers (Dialogue §20):
  - A statement `name(x);` or `name(x) = v;` is a call or a function-like
    macro (e.g. `ARR(i) = 5`), unless `name` is a typedef, in which case C
    reads a declaration of `x`. Converting to a typedef type is written
    `x as size_t`, never `size_t(x)`. Wrapping such statements in
    parentheses was tried and reverted, because it breaks header macros
    that expand to statements (`do { } while (0)`, `static_assert`,
    `timeradd`, ...).
  - A header macro that expands to nothing or to an operator can change
    how C reads the tokens around it. For example, macOS's
    `__BEGIN_DECLS * p` is C's `*p`. Kelvin treats every macro as an
    ordinary name.
  - `__asm__ __volatile__ (...)`, two names in a row, cannot be written
    in Kelvin. `__asm__(...)` can.

- (15) The user's own example: "`i = 42` is inferred as `i:i64 = 42`.
  `u = 0xdead:u16` is identical to ... `u = 0xdead as u16`." (The middle
  form in the original message read `u:u64 = 0xdead`, which was taken as a
  typo for `u16`.) Rules:
  - `name: T [= v]` declares (or `name: T [:= v]` for a reference, #19),
    at the top level, in blocks and in `for` initializers. Several
    declarators are separated by commas: `a: i32 = 1, b = 2;`.
  - `name = v` (or `name := v` for a reference) declares `name` when no
    enclosing scope (block, function, parameters, globals, functions, enum
    constants) has declared it.
    Otherwise it assigns. At the top level it always declares. The type is
    inferred from `v` (#8, #11): a literal, or a value written `v:T`,
    `v as T` or `T(v)`. Anything else needs `name: T = v`, or
    `name: T := v` for a reference.
  - In a declaration list inside a function, a later `name = v` or
    `name := v` whose name is already declared assigns it instead of
    redeclaring it. So `for (i = 0, n = 0; ...)` declares `i` and resets
    an existing `n`, and `k = 1, n = 40;` declares `k` and assigns `n`. At
    the top level every name in the list is declared.
  - Declaration wins over a label: `again: n = 0;` declares `again` of
    type `n`. Write `again: ; n = 0;` to label it.
  - A declaration cannot be the body of `if`/`while`/`for`/`do` or follow
    a label, as in C11. `if (c) x = 1;` with `x` undeclared is an error.
  - `:=` was deliberately left unused here. It is now the reference
    assignment (#19).
  - Hazard: kelvinc does not see names declared by C headers, so
    assigning to a header global such as `optind` declares a new local.
    Declare such globals first with `extern optind: i32;` (Q11).
  - `var` is no longer reserved. `var x: ...` gets a hint.
- (16) `expr:T` has the same precedence and meaning as `expr as T` (P17).
  A bare name after `:` is not an annotation in the middle operand of
  `?:` or in a `case` label, where `:` is the separator. A converter call
  such as `c ? x : u8(y)` is not an annotation either.

- (17) The prelude is available in every Kelvin program without an
  import. kelvinc includes `kelvin_prelude.h` in the generated C and links
  `libkelvin.a`. `print(a, b, ...)` prints its values with no
  separators, and `println(...)` adds a newline. Both take 0 to 16
  values. `print` and `println` cannot be redefined. This answers Q7:
  `println(n)` prints an `i64` on every platform. The same library and
  header work from C (`#include <kelvin_prelude.h>`, link `-lkelvin`).

- (18) Agreed details: methods are defined Swift-style as
  `point.toString(): String { ... self ... }` with an implicit `self`.
  `toString()` and `fmt()` return a `String`, a fixed inline buffer.
  Every struct gets a derived `toString()` that can be overridden, and
  `f64.toString()` is `fmt("%.17g")`, which is lossless. `print` keeps its
  own formatting (P21). The user's example `pi.fmt("5a")` was read as
  `pi.fmt("%a")` (Shift+5), which gives `"0x1.921fb54442d18p+1"`.

- (19) Agreed details: the user's example `buffer := malloc(8 * 1024):i64`
  was a typo for `:i64^`, and `v:T` keeps meaning `v as T`.
  - Declarations of references use `:=` too (`p: i32^ := &x`, or
    `buffer := ...:i64^`, which infers `i64^`).
  - Pointer arithmetic (`p += 1`, `p++`) stays as in C.
  - Enforcement is best effort. kelvinc checks a target whose type it can
    see: a variable, parameter or `self`, a field of a Kelvin struct,
    `p^`, `a[i]`, and combinations of these. `=` on a reference and `:=`
    on a value are errors. Targets of unknown type, such as C typedef
    types, fields of C structs and call results, are not checked.
  - `:=` is an assignment operator like `=`, usable in expressions
    (`for (n: struct node^ := list; n; n := n^.next)`), and is emitted as
    C's `=`. Like `=`, it declares a name that is not declared yet.

- (20) The user's words: "abolish type `void`. to mean C's `void *`,
  introduce `any^`", then "not `any`. it must be `any^`. Introduce
  `nullptr` to mean `(void *)0`. `ptr:any^;` means `ptr := nullptr`".
  - `any` is valid only behind `^`. `void` is rejected with a hint
    everywhere.
  - `nullptr` is a keyword, emitted as `((void *)0)`, and infers `any^`.
  - A function without a result still omits `: type`.

- (21) Agreed details:
  - The text comes back as `u8^` in a buffer on the caller's stack, sized
    in advance from the type: no heap.
  - `.hex`, `.oct` and `.bin` prefix `0x`, `0o` and `0b`.
  - Signed integers always carry a sign (`+42`, `-0x2a`), which tells them
    from unsigned ones (`42`, `0x2a`).
  - `f32`/`f64` `.dec` is `%.17g` style (`%.9g` for `f32`), and `.hex` is
    `%a`, both always signed.
  - For `.size`, a field wins when unsure. `.size` is `sizeof` only where
    kelvinc sees the receiver is not a struct (a scalar, pointer or array),
    or is a Kelvin struct without a `size` field. On C structs and unknown
    types, `.size` stays a field access.

## Provisional decisions (made during implementation; please review)

These follow from the agreed changes, or were needed to write any code at
all. None of them has been explicitly agreed yet.

| # | Decision | Example | Why |
|---|----------|---------|-----|
| P1 | Array brackets are postfix too | `a: i32[4];` | Mixing postfix `^` with prefix `[4]` would make `[4]i32^` ambiguous |
| P2 | Type suffixes apply left to right, but a run of brackets reads in C order | `i32^[4]` is `int32_t *[4]`, `i32[4]^` is `int32_t (*)[4]`, `i32[2][3]` is `int32_t[2][3]` | So that `m: i32[2][3]` indexes as `m[1][2]`, exactly as in C |
| P3 | ~~Variable declarations start with `var`~~ | | Superseded by #15 |
| P4 | `()` means no parameters | `f(): i32` is `int32_t f(void)` | C's `()` (unspecified parameters) is obsolescent |
| P5 | No `: type` after a function means it returns nothing | `f()` is `void f(void)` | Same as v0.1. Kelvin itself has no `void` (#20) |
| P6 | Qualifiers bind to what is on their left; a leading qualifier binds to the base | `u8 const^` and `const u8^` are both `const uint8_t *`; `u8^ const` is `uint8_t *const` | This is C's rule, written postfix |
| P7 | Several names per declaration | `a: i32 = 1, b: u8^;` | Each name has its own full type, since C's `int a, *b` split is gone |
| P8 | Struct and union members end with `;` | `struct p { x: i32; y: i32; };` | Kept from C, as is the `;` after `}` |
| P9 | Storage class goes in front | `static f(): i32`, `static n: i32`, `extern optind: i32` | Kept from C |
| P10 | Anonymous enums are allowed | `enum { LIMIT = 3 };` | The common C idiom for constants |
| P11 | Kelvin reserves the sized type names, `String`, `any` and `nullptr` (`as` is reserved by #14) | | C code that uses them as identifiers cannot be named from Kelvin yet. `var` is no longer reserved (#15) |
| P12 | Literals are passed through verbatim (minus suffixes, #13) | `0x1f`, `017`, `0b101`, `'\n'`, `"a" "b"` | So C interprets them exactly as it always has. Octal `017` and C23's `0b` stay |
| P13 | `u8` and C's `char` mix freely | `s: u8^ := "hi";`, `printf(fmt: const u8^, ...): i32;`, `main(argc: i32, argv: u8^^): i32` | Follows from #7. String literals and libc use `char`, while `u8` is `unsigned char`. They are ABI-identical, so kelvinc silences C's pointer-sign and library-redeclaration warnings, and emits `main`'s `argv` as `char **`, which C requires |
| P14 | `true` and `false` are built in alongside `bool` | `done: bool = false;` | `<stdbool.h>` provides all three together, and a `bool` without them would be half a feature. They are reserved words, and are `bool`s (P23) |
| P15 | Any identifier after `:` or `as` is a type name | `f: FILE^ := stdout;`, `n as size_t` | Needed for #12: headers define typedef names that Kelvin cannot know without reading them. After `:` or `as` a type is certain, so this is unambiguous |
| P21 | How `print` formats values | `println(1.0, " ", 0.1:f32, " ", 1e300)` prints `1.0 0.1 1e+300` | Integers print in decimal, including `i128`/`u128`. Floats print in the shortest text that reads back the same, always with a `.` or an exponent; every NaN prints `nan`, whatever its sign bit. `bool` prints `true`/`false`. `u8^`, `i8^` and string literals print as strings, with `(null)` for a null pointer, and a `String` prints as its text. Other pointers print as addresses, and C's `char` as a character. Dispatch is by C type via `_Generic`, so `x == y` and `!b` (C `int`s) print `1`/`0`; use `bool(x == y)` |
| P22 | Runtime layout and linking | `make` builds `libkelvin.a` plus `libkelvin.dylib` (macOS) or `libkelvin.so` (Linux); `make install` puts them in `$PREFIX/lib` and the header in `$PREFIX/include` | kelvinc links `libkelvin.a` statically, so programs need no runtime library at run time. It finds the runtime in `$KELVIN_HOME`, next to itself (source tree), or in `../include` and `../lib` (installed). The shared libraries are for use from C and other toolchains. Zero-argument `print()`/`println()` rely on `__VA_OPT__`, which gcc and clang accept in C11 mode |
| P23 | `true` and `false` are `bool`s in the generated C | `println(true)` prints `true` | C's `true` is the `int` `1`. kelvinc emits `(bool)true`, so the prelude sees a `bool`. Arithmetic is unchanged (`true + 1` is 2) |
| P24 | A decimal literal above `INT64_MAX` gets C's `U` in the generated C | `18446744073709551615:u64` | Without suffixes (#13), C has no signed type for it and warns, although it already treats it as unsigned. kelvinc writes the `U` |
| P25 | `String` holds up to 255 bytes inline, plus a NUL | `t: String = p.toString(); println(t, t.bytes[0]);` | No allocation, no freeing, safe to copy, return and chain. Longer text is truncated. `bytes` is a `u8` array, so Kelvin sees no `char` |
| P26 | Method dispatch | `p.toString()` becomes `({ __auto_type t = p; _Generic((t), ..., struct point: point__toString, ...)(t); })` | kelvinc has no type checker, so C11 `_Generic` picks the method, and the receiver is evaluated once into a temporary (P31). The rules that follow from this: (1) as in C, a method must be declared (defined or prototyped as `point.area(): f64;`) before a call, for every receiver type; a method may call itself; (2) `x.name(...)` is a method call when `name` is a method somewhere in the file or the prelude, and a call through a field otherwise; (3) enums cannot have methods, because C cannot tell an enum from its integer type; (4) the prelude's `toString`/`fmt` of built-in types cannot be redefined; (5) C typedef names (`size_t`) cannot be receivers; (6) `self` is passed by value; (7) `point.area` is the C function `point__area`, and two methods whose C names would collide (`a_.b`, `a._b`) are an error; (8) method calls cannot appear in global initializers |
| P27 | `toString()` of built-in types | `0.1.toString()` is `0.10000000000000001`, `(0.1:f32).toString()` is `0.100000001` | Lossless, as agreed for `f64` (`%.17g`): `f32` uses `%.9g` and `long double` `%.21Lg`. Complex numbers are `re+imi` (`1+2i`). Integers are decimal (including 128-bit), `bool` is `true`/`false`, `u8^`, `i8^` and string literals are their text (`(null)` for null), and other pointers are addresses. A C struct value has no `toString` unless one is written for it (`tm.toString(): String {...}`) |
| P28 | The derived `toString()` | `{from: {x: 3, y: 4}, to: {x: 6, y: 8}, tag: edge}`, `[{x: 0, y: 0}, ...]` | Fields are written `name: value`, nested structs recurse, and arrays print as `[a, b]` (a flexible array member as `[...]`). Text is unquoted, and pointers print as addresses (`u8^`/`i8^` as text). A field whose type has a user `toString`, including a header struct, uses it. Other fields of C types print through C's type (scalars) or as `{...}`. A union prints as `<union name>`, since its active member is unknown. Derived functions are `static inline`, so two files that share a struct still link |
| P29 | `fmt()` | `n.fmt("%5d")`, `255.fmt("%#x")`, `42.fmt("%.2f")` is `42.00`, `(-1:i32).fmt("%x")` is `ffffffff` | One conversion (`diouxXcfFeEgGaAsp`) with flags, width and precision (each at most 4096), plus any text and `%%`. No length modifiers (#13: no size hints), since the value's own type decides. The value is converted to the conversion's kind (a float to an integer only within range), and an unsigned conversion of a negative value shows its bits in the value's own width. Integers, including 128-bit ones, are formatted by Kelvin with every flag defined; flags C leaves undefined for a conversion (`%05c`, `%#d`) are ignored. The format is never passed to C's printf. Anything else gives `<invalid format>` |
| P30 | A number ends before `.name` | `2.toString()`, `1.5.fmt("%e")`, `0xff.fmt("%#x")` | So methods can be called on literals. `1.e5` and hex floats such as `0x1.f4p+9` are still numbers. `1.f` or `1.L` (a C suffix spelled as a field) is an error |
| P31 | Method calls use two GNU C extensions in the generated C | `({ __auto_type kv_self1 = recv; ...; })` | A statement expression and `__auto_type` evaluate the receiver once and keep chained calls (`x.a().b().c()`) linear in size; without them the receiver had to be printed twice per call, doubling the C at each link of a chain. gcc and clang accept both in C11 mode. The ABI is unaffected |
| P32 | What counts as a reference for `:=` | `p: i32^` (a reference), `a: i32^[2]` (a value), `t: pthread_t` (unknown) | A pointer type is a reference. Built-in types, structs, unions, enums and arrays (even of pointers) are values, except that an array parameter is a pointer, as C adjusts it (`argv: u8^[]`, so `argv := argv + 1`). A C typedef name is unknown, so both `=` and `:=` are accepted. Initializer lists and function arguments are not assignments |
| P33 | Two readings of #20 | `q: i32^;` is `int32_t *q = 0;`; discarding is `x;` | (1) The user's example `ptr: any^;` is applied to every reference: a pointer declared without a value is `nullptr`, local or global, except an `extern` declaration. (2) The discard idiom `x as void` went with `void`, and the user did not pick a replacement, so a value is discarded by writing it as a statement (C may warn about an unused value). Also, comparisons are C `int`s, so `println(p == nullptr)` prints `1` |
| P34 | Property details | `(-5:i32).hex` is `-0x5`; `x.hex` emits `_Generic((x), ...)(x, (uint8_t[sizeof(x) * 2 + 28]){0})` | Integers are sign and magnitude (not two's complement), with lowercase digits and no padding. A NaN is `nan`, unsigned. The buffer is a compound literal at the use site, so the text lives until the enclosing block ends: storing `t: u8^ := x.hex` is fine inside the block, but returning it is not (as with any C local). `.dec`/`.hex`/`.oct`/`.bin` stay properties on receivers kelvinc cannot see (`(a + b).hex`), because such fields are rare. A Kelvin struct's own field of that name still wins, and a C struct's too |
| P16 | `#import` details | `#import "x.h" as C` | Top level only, at the start of a line. A quoted header is searched next to the `.k` file (kelvinc passes `-I<dir of .k>`), since the generated C lives in a temp directory |
| P17 | `as` binds tighter than every binary operator and looser than prefix operators, and chains left to right | `-x as u8` is `(-x) as u8`; `a * b as i64` is `a * (b as i64)`; `x as i64 as i32` | This is where C's cast sits (and Rust's `as`). To index or dereference the result, parenthesize: `(p as u8^)[0]`, because a `[`…`]` or `^` after the type is read as part of the type |
| P18 | `T(v)` only for built-in types (`i8`…`u128`, `f32`, `f64`, `bool`) | `u8(c)`, but `n as size_t` and `p as u8^` | For a typedef name, `size_t(n)` would look exactly like a function call, and suffixes such as `u8^(p)` read poorly. `as` covers every type |
| P19 | Compound literals `(T){...}` stay, for any type (including typedef names with suffixes or qualifiers) and under `sizeof` | `(struct point){.y = 7}`, `(size_t[2]){1, 2}`, `(div_t^){NULL}`, `sizeof (i32[3]){1, 2, 3}` | They are not casts, although they share C's syntax. A `(...)` followed by `{` can only be a compound literal, because an expression is never followed by `{`, so its contents are read as a type. A Kelvin spelling is an open question (Q10) |
| P20 | C compiler keywords beyond C11 are rejected | `__extension__`, `__real__`, `__imag__`, `__alignof__`, `alignof`, `__typeof__`, `typeof`, `_BitInt`, `__int128` (use `i128`), `__signed__`, `__complex__`, `__auto_type`, `_Float16`, ... | In C they act as prefix operators or type specifiers, which would let a C cast or a prefix `*` dereference through (#14). `__asm__(...)` and `__attribute__((...))` stay usable, and `_Pragma("...")` is allowed as a statement of its own |

## Open questions

- ~~**Q1: Drop `var` as well?**~~ Answered: yes (#15).
- ~~**Q2: `i64`-style type names?**~~ Answered: yes, see changes #6–#8.
- ~~**Q3: `float`/`double`?**~~ Answered: `f32`/`f64` (change #9).
  `long double` has no Kelvin spelling yet.
- ~~**Q4: `_Bool`?**~~ Answered: built-in `bool` (change #10).
- **Q5: `size_t`?** `sizeof`, `malloc` and `strlen` all use it. Should Kelvin
  have `usize`/`isize`, or should programs use `u64`/`i64`?
- ~~**Q6: Integer literal suffixes.**~~ Answered: no suffixes at all (#13).
- ~~**Q7: Printing `i64`.**~~ Answered by #17: `print()` and `println()` in
  the prelude.
- ~~**Q8: Infer more than integers?**~~ Answered: no. Only integer (`i64`)
  and floating (`f64`) literals are inferred (#8, #11), and `bool` must be
  written.
- ~~**Q9: Casts to C typedef names.**~~ Answered by #14: `n as size_t` and
  `p as FILE^` parse, because a type is certain after `as`.
- **Q11: C globals from headers.** `optind = 1;` declares a new local
  unless `extern optind: i32;` comes first, because kelvinc cannot see
  header declarations (#15). Is the `extern` workaround enough?
- **Q12: Infer from typed variables?** kelvinc now knows the declared type
  of every variable in scope (#19). Should `n := list` infer `n`'s type
  from `list`, as `n: struct node^ := list` currently spells it? Today
  only literals and annotated values are inferred (#8, #11, #15).
- **Q10: Compound literals.** `(struct point){.y = 7}` keeps C's
  cast-like syntax (P19). Should it get a Kelvin spelling, such as
  `struct point{.y = 7}`?

## Unchanged from C (on purpose, for now)

These are everything else: operator precedence (including `==` binding
tighter than `&`), implicit conversions, integer promotion (to C's `int`,
which is `i32` on every supported target), integer truthiness, assignment as an expression, `++`/`--`, the comma operator,
`?:`, `if`/`while`/`do`/`for`/`switch`/`goto`, compound literals, designated initializers, arrays that
decay to pointers, declare-before-use, `struct`/`union`/`enum` tags, and all
undefined behavior.

## TODO (C features not yet expressible in Kelvin)

- The rest of the preprocessor (`#define`, `#if`, ...). Headers are
  covered by `#import ... as C`.
- `sizeof` of a type spelled from a C typedef plus a suffix, e.g.
  `sizeof(FILE^)`. Kelvin reads it as dereferencing a variable named
  `FILE`. `sizeof(size_t)` works, and so does `sizeof p` for a variable
  `p: FILE^`.
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
| `src/lexer.c` | C's lexical rules. Kelvin keywords `as`, `i8`…`u128`, `f32`, `f64`, `bool`, `true`, `false`, `String`, `any`, `nullptr`; `~=`, no `^=`; a number ends before `.name` (P30) |
| `src/parser.c` | Recursive descent over C's grammar with the changes above, plus a table of declared names and types: it tells `x = v` (declare) from an assignment, and `=` from `:=` (#19) |
| `src/codegen.c` | Prints C: methods become `_Generic` dispatch and derived `toString()`s; postfix types become C declarators, `i32` becomes `int32_t` and `f64` becomes `double`, `p^` becomes `(*p)`, `~` becomes `^` |
| `src/main.c` | Driver: writes the C, finds the runtime, runs `$CC` with `-I<dir of .k>` and `libkelvin.a`, and optionally runs the program |
| `runtime/kelvin_prelude.h` | The prelude: `String`, `print`/`println` as `_Generic` macros, and the dispatch tables for built-in `toString`/`fmt` |
| `runtime/prelude.c` | `print`/`println`, built into `libkelvin.{a,so,dylib}` |
| `runtime/string.c` | `String`, `toString()` and `fmt()` for the built-in types |
| `tests/run.sh` | `tests/run/*.k` check output; `tests/error/*.k` check diagnostics; `tests/c/*.c` use libkelvin from C, linked statically and dynamically |

The driver adds `$KELVIN_CFLAGS` to the C compiler command line, for
libraries (`-lcurl`) and other flags. `--emit-c --no-line` shows the
generated C without `#line` directives.
