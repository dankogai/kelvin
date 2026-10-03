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
| 15 | ~~No `var`: `x: T = v` declares, and so does `x = v` when `x` is not declared yet~~ (superseded by #27) | `int32_t x = 0; long i = 42;` | `x: i32 = 0; i = 42;` | 2026-10-01 |
| 16 | `expr:T` annotates any expression; it means `expr as T` | `(uint16_t)0xdead`, `1UL << 40` | `0xdead:u16`, `1:u64 << 40` | 2026-10-01 |
| 17 | A prelude with `print()` and `println()`, in `libkelvin.{a,so,dylib}` | `printf("%" PRId64 "\n", n)` | `println(n)` | 2026-10-01 |
| 18 | Every type has methods; ~~`toString()` is mandatory; `fmt()` a la Raku~~ (shelved by #22) | | `point.area(): f64 { ... }` | 2026-10-01 |
| 19 | `:=` assigns references (pointers); `=` assigns values | `int64_t *buffer = malloc(8 * 1024); p = q;` | `buffer := malloc(8 * 1024):i64^; p := q;` | 2026-10-01 |
| 20 | No `void`: `any^` is C's `void *`, `nullptr` is `(void *)0`, and `ptr: any^;` means `ptr := nullptr` | `void *p = NULL;` | `p: any^;` | 2026-10-02 |
| 21 | Properties: `x.size` is `sizeof(x)`; integers have `.dec`, `.hex`, `.oct` and `.bin`, and `f32`/`f64` have `.dec` and `.hex`, as `u8^` text in a stack buffer | `sizeof x`, `snprintf(buf, n, "0x%x", x)` (unsigned `x`) | `x.size`, `x.hex` | 2026-10-02 |
| 22 | `toString()`, `fmt()` and `String` are shelved until Kelvin has a true string type. Every type has `.cstr`, its text as `cstr` on the stack, and `cstr` is a built-in name for `u8^` | `snprintf(buf, n, "%lld", x)`; `char *s` | `x.cstr`; `s: cstr` | 2026-10-02 |
| 23 | `if`, `while` and `do` take a condition without parentheses and a block body; every condition, and every operand of `&&`, `||` and `!`, is a `bool`; comparisons and logical operators give a `bool` | `if (n) x = 1;`, `while (fgets(b, n, f))` | `if n != 0 { x = 1; }`, `while fgets(b, n, f) != nullptr { ... }` | 2026-10-03 |
| 24 | `true` and `false` infer `bool` | `bool t = true;` | `t = true;` | 2026-10-03 |
| 25 | A `bool` expression infers `bool` | `bool ok = a < b;` | `ok = a < b;` | 2026-10-03 |
| 26 | Assignment is a statement; `++` and `--` are gone; pointers step with `.next` and `.prev` | `*p++ = *q++;`, `a = b = 0;` | `p^ = q^; p := p.next; q := q.next;`, `a = 0, b = 0;` | 2026-10-03 |
| 27 | `let` and `var` declare, with the type after the name: a `let` never changes (C's `const`); parameters are lets unless written `var`; a plain `x = v` only assigns | `const int k = 42; int n = 0;` | `let k = 42; var n: i32 = 0;`, `f(var p: u8^)` | 2026-10-03 |
| 28 | Ranges: `for i in a..<b { }` and `for i in a...b { }`, with `i` a `let` | `for (int i = 0; i < n; i++)` | `for i in 0..<n { ... }` | 2026-10-03 |
| 29 | A `struct`, `union` or `enum` is a type by its bare name, as if typedef'd | `typedef struct point point;`, `struct point p;` | `var p: point;` | 2026-10-03 |

Notes:

- (2, 3) `*` means only multiplication. `p^^` is `**p` (and `p++^` was
  `*p++` until #26 removed `++`). Postfix operators apply left to right,
  so `p^[i]` is `(*p)[i]`.
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
  `true`/`false` were not inferred at first (`b = true;` needed `: bool`,
  Q8 answered no); #24 changed that.
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
  - A declaration cannot be the body of `for` or follow a label, as in
    C11 (`if`, `while` and `do` take blocks since #23).
  - `:=` was deliberately left unused here. It is now the reference
    assignment (#19).
  - Hazard: kelvinc does not see names declared by C headers, so
    assigning to a header global such as `optind` declares a new local.
    Declare such globals first with `extern optind: i32;` (Q11).
  - `var` is no longer reserved. `var x: ...` gets a hint.
  - #27 superseded these rules: declarations start with `let` or `var`,
    and a plain `x = v` always assigns, so the hazard with header globals
    and the declaration-or-label question are gone.
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
  `point.area(): f64 { ... self ... }` with an implicit `self`.
  `toString()` and `fmt()` returned a `String`, a fixed inline buffer.
  Every struct got a derived `toString()` that could be overridden, and
  `f64.toString()` was `fmt("%.17g")`, which is lossless. `print` keeps
  its own formatting (P21). The user's example `pi.fmt("5a")` was read as
  `pi.fmt("%a")` (Shift+5), which gives `"0x1.921fb54442d18p+1"`. #22
  shelved `toString()`, `fmt()` and `String`; their code is in the git
  history (commit 8eb42bc and before).

- (22) Agreed details: `toString()`, `String` and `fmt()` are all shelved
  until Kelvin has a true string type (a la C++ and others). `x.cstr`
  gives the text `toString()` gave, as `cstr` in a buffer on the stack
  like `.dec`. A struct's `.cstr` is derived (`{x: 3, y: 4}`), with a
  buffer kelvinc sizes from the member types, and cannot be overridden
  for now. `cstr` is a built-in type name for `u8^` (`uint8_t *` in C),
  not a `typedef` declaration: Kelvin still has none.

- (23) Agreed details: `bool` was already built in (#10) and `b.cstr` is
  `true` or `false`; `.cstr` stays a property. Strictness covers every
  condition: `if`, `while`, `do`, `for` and `?:`, and the operands of
  `&&`, `||` and `!`. `if`, `while` and `do-while` drop their parentheses
  (`do { ... } while cond;`), while `for (...)` and `switch (...)` keep
  them for now. The C compiler enforces `bool` where kelvinc cannot see a
  type, and comparisons and logical operators give a real `bool`, so
  `println(a == b)` prints `true`. Without parentheses a body must be a
  block, as in Go, Swift and Rust.

- (24) `t = true;` declares a `bool`: `true` is a `bool` literal, so its
  type is as obvious as `42`'s or `1.5`'s. This reverses the note on #11.
  Other `bool` values, such as `ok = a < b;`, still needed `: bool`
  until #25.

- (25) Agreed details: every `bool` expression infers `bool`, with one
  exception the user accepted: a `bool` kelvinc cannot see, such as the
  result of a C function from a header, still needs `: bool`. The user
  asked whether `ok = a < b` could be read as `(ok = a) < b`: it cannot,
  since assignment has the lowest precedence, as in C.

- (26) Agreed details: assignment (`=`, `:=`, `+=`, ...) is a statement
  with no value, and `++` and `--` are gone, as in Swift. Pointers get
  `.next` and `.prev` instead. Index expressions must not change
  anything, which follows: nothing inside `[...]` can assign. "The good
  old days of `*p++ = *q++;` are gone." A `for` init or step takes a
  comma list of assignments.

- (27) Agreed details: the user wanted `var` back to mark mutability, and
  chose `let` over `val` for the immutable binding, as in Swift. `let i =
  42; i += 1;` is an error. Every local and global declaration starts with
  `let` or `var` (`let x = 42;`, `var n: i32 = 0;`,
  `static var calls: i32;`), so a plain `x = 0;` always assigns, which
  also ends #15's guessing between declaring and assigning. Parameters
  are lets unless written `var`, as in `f(var p: i32^) { p := p.next; }`,
  and a method's `self` is a mutable copy (`self.x += 1` is fine). A
  `let` is C's `const` (agreed in the discussion): a let pointer is
  fixed, but what it points to may change. Struct members keep
  `name: type;`.

- (28) Agreed details: C's counting `for` is discouraged in favour of
  ranges, `for i in 0..<count { }` (half-open) and `for i in 1...n { }`
  (closed), where `i` is immutable in the body. `i`'s type comes from the
  bounds (or is written, `for i: u8 in ...`), and ranges exist only in
  `for` for now. C's `for (...)` stays, written `for (var i = 0; ...)`.

- (29) Agreed details: `struct st` and `union un` are "auto-typedef'd", so
  `st` and `un` are types without the keyword; the user chose to include
  enums, as C++ does, and to keep `struct point` working as well.

- (19) Agreed details: the user's example `buffer := malloc(8 * 1024):i64`
  was a typo for `:i64^`, and `v:T` keeps meaning `v as T`.
  - Declarations of references use `:=` too (`p: i32^ := &x`, or
    `buffer := ...:i64^`, which infers `i64^`).
  - Pointer arithmetic (`p += 1`) stays as in C (`p++` went with #26).
  - Enforcement is best effort. kelvinc checks a target whose type it can
    see: a variable, parameter or `self`, a field of a Kelvin struct,
    `p^`, `a[i]`, and combinations of these. `=` on a reference and `:=`
    on a value are errors. Targets of unknown type, such as C typedef
    types, fields of C structs and call results, are not checked.
  - `:=` is an assignment like `=`, emitted as C's `=`, and usable in a
    `for` clause (`for (var n: struct node^ := list; n != nullptr;
    n := n^.next)` since #27). Like `=`, it declared a name that was not
    declared yet, until #27; since #26 it is a statement, not a value.

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
| P1 | Array brackets are postfix too | `var a: i32[4];` | Mixing postfix `^` with prefix `[4]` would make `[4]i32^` ambiguous |
| P2 | Type suffixes apply left to right, but a run of brackets reads in C order | `i32^[4]` is `int32_t *[4]`, `i32[4]^` is `int32_t (*)[4]`, `i32[2][3]` is `int32_t[2][3]` | So that `var m: i32[2][3]` indexes as `m[1][2]`, exactly as in C |
| P3 | ~~Variable declarations start with `var`~~ | | Superseded by #15, and back, with `let`, since #27 |
| P4 | `()` means no parameters | `f(): i32` is `int32_t f(void)` | C's `()` (unspecified parameters) is obsolescent |
| P5 | No `: type` after a function means it returns nothing | `f()` is `void f(void)` | Same as v0.1. Kelvin itself has no `void` (#20) |
| P6 | Qualifiers bind to what is on their left; a leading qualifier binds to the base | `u8 const^` and `const u8^` are both `const uint8_t *`; `u8^ const` is `uint8_t *const` | This is C's rule, written postfix |
| P7 | Several names per declaration | `var a: i32 = 1, b: u8^;` | Each name has its own full type, since C's `int a, *b` split is gone |
| P8 | Struct and union members end with `;` | `struct p { x: i32; y: i32; };` | Kept from C, as is the `;` after `}` |
| P9 | Storage class goes in front | `static f(): i32`, `static var n: i32`, `extern var optind: i32` | Kept from C |
| P10 | Anonymous enums are allowed | `enum { LIMIT = 3 };` | The common C idiom for constants |
| P11 | Kelvin reserves the sized type names, `String`, `any`, `nullptr`, `cstr`, `let` and `var` (`as` is reserved by #14) | | C code that uses them as identifiers cannot be named from Kelvin yet. `var` was unreserved by #15 and, with `let`, reserved again by #27. `String` stays reserved while shelved (#22) |
| P12 | Literals are passed through verbatim (minus suffixes, #13) | `0x1f`, `017`, `0b101`, `'\n'`, `"a" "b"` | So C interprets them exactly as it always has. Octal `017` and C23's `0b` stay |
| P13 | `u8` and C's `char` mix freely | `let s: u8^ := "hi";`, `printf(fmt: const u8^, ...): i32;`, `main(argc: i32, argv: u8^^): i32` | Follows from #7. String literals and libc use `char`, while `u8` is `unsigned char`. They are ABI-identical, so kelvinc silences C's pointer-sign and library-redeclaration warnings, and emits `main`'s `argv` as `char **`, which C requires |
| P14 | `true` and `false` are built in alongside `bool` | `var done: bool = false;` | `<stdbool.h>` provides all three together, and a `bool` without them would be half a feature. They are reserved words, and are `bool`s (P23) |
| P15 | Any identifier after `:` or `as` is a type name | `let f: FILE^ := stdout;`, `n as size_t` | Needed for #12: headers define typedef names that Kelvin cannot know without reading them. After `:` or `as` a type is certain, so this is unambiguous |
| P21 | How `print` formats values | `println(1.0, " ", 0.1:f32, " ", 1e300)` prints `1.0 0.1 1e+300` | Integers print in decimal, including `i128`/`u128`. Floats print in the shortest text that reads back the same, always with a `.` or an exponent; every NaN prints `nan`, whatever its sign bit. `bool` prints `true`/`false`. `u8^`, `i8^` and string literals print as strings, with `(null)` for a null pointer. Other pointers print as addresses, and C's `char` as a character. Dispatch is by C type via `_Generic`; comparisons, `&&`, `||` and `!` are `bool`s since #23, so `x == y` prints `true` |
| P22 | Runtime layout and linking | `make` builds `libkelvin.a` plus `libkelvin.dylib` (macOS) or `libkelvin.so` (Linux); `make install` puts them in `$PREFIX/lib` and the header in `$PREFIX/include` | kelvinc links `libkelvin.a` statically, so programs need no runtime library at run time. It finds the runtime in `$KELVIN_HOME`, next to itself (source tree), or in `../include` and `../lib` (installed). The shared libraries are for use from C and other toolchains. Zero-argument `print()`/`println()` rely on `__VA_OPT__`, which gcc and clang accept in C11 mode |
| P23 | `true` and `false` are `bool`s in the generated C | `println(true)` prints `true` | C's `true` is the `int` `1`. kelvinc emits `(bool)true`, so the prelude sees a `bool`. Arithmetic is unchanged (`true + 1` is 2) |
| P24 | A decimal literal above `INT64_MAX` gets C's `U` in the generated C | `18446744073709551615:u64` | Without suffixes (#13), C has no signed type for it and warns, although it already treats it as unsigned. kelvinc writes the `U` |
| P25 | ~~`String` holds up to 255 bytes inline, plus a NUL~~ | | Shelved by #22 |
| P26 | Method dispatch | `p.area()` becomes `({ __auto_type t = p; _Generic((t), ..., struct point: point__area, ...)(t); })` | kelvinc has no type checker, so C11 `_Generic` picks the method, and the receiver is evaluated once into a temporary (P31). The rules that follow from this: (1) as in C, a method must be declared (defined or prototyped as `point.area(): f64;`) before a call, for every receiver type; a method may call itself; (2) `x.name(...)` is a method call when `name` is a method somewhere in the file, and a call through a field otherwise; (3) enums cannot have methods, because C cannot tell an enum from its integer type; (4) `toString` and `fmt` cannot be defined while shelved (#22); (5) C typedef names (`size_t`) cannot be receivers; (6) `self` is passed by value; (7) `point.area` is the C function `point__area`, and two methods whose C names would collide (`a_.b`, `a._b`) are an error; (8) method calls cannot appear in global initializers |
| P27 | The text of built-in types, now `.cstr` (#22) | `0.1.cstr` is `0.10000000000000001`, `(0.1:f32).cstr` is `0.100000001` | Lossless, as agreed for `f64` (`%.17g`): `f32` uses `%.9g` and `long double` `%.21Lg`, and a NaN is `nan`. Complex numbers are `re+imi` (`1+2i`). Integers are decimal (including 128-bit) with no `+`, `bool` is `true`/`false`, and other pointers are hex addresses (`0x0` for null) |
| P28 | The derived text of a struct, now `.cstr` (#22) | `{from: {x: 3, y: 4}, to: {x: 6, y: 8}, tag: edge}`, `[{x: 0, y: 0}, ...]` | Fields are written `name: value`, nested structs recurse, and arrays print as `[a, b]` (a flexible array member as `[...]`). Text is unquoted, and pointers print as addresses (`u8^`/`i8^` as text). Fields of C types print through C's type (scalars) or as `{...}`. A union prints as `<union name>`, since its active member is unknown. Derived functions are `static inline`, so two files that share a struct still link |
| P29 | ~~`fmt()`~~ (shelved by #22; this was its design) | `n.fmt("%5d")`, `255.fmt("%#x")`, `42.fmt("%.2f")` is `42.00`, `(-1:i32).fmt("%x")` is `ffffffff` | One conversion (`diouxXcfFeEgGaAsp`) with flags, width and precision (each at most 4096), plus any text and `%%`. No length modifiers (#13: no size hints), since the value's own type decides. The value is converted to the conversion's kind (a float to an integer only within range), and an unsigned conversion of a negative value shows its bits in the value's own width. Integers, including 128-bit ones, are formatted by Kelvin with every flag defined; flags C leaves undefined for a conversion (`%05c`, `%#d`) are ignored. The format is never passed to C's printf. Anything else gives `<invalid format>` |
| P30 | A number ends before `.name` | `2.cstr`, `1.5.hex`, `0xff.bin`, `(7:i64).inc()` | So properties and methods apply to literals. `1.e5` and hex floats such as `0x1.f4p+9` are still numbers. `1.f` or `1.L` (a C suffix spelled as a field) is an error |
| P31 | Method calls use two GNU C extensions in the generated C, as does a property whose receiver holds a method call or property | `({ __auto_type kv_self1 = recv; ...; })` | A statement expression and `__auto_type` evaluate the receiver once and keep chained calls (`x.a().b().c()`) linear in size; without them the receiver had to be printed twice per call, doubling the C at each link of a chain. gcc and clang accept both in C11 mode. The ABI is unaffected |
| P32 | What counts as a reference for `:=` | `var p: i32^` (a reference), `var a: i32^[2]` (a value), `var t: pthread_t` (unknown) | A pointer type is a reference. Built-in types, structs, unions, enums and arrays (even of pointers) are values, except that an array parameter is a pointer, as C adjusts it (`var argv: u8^[]`, so `argv := argv + 1`). A C typedef name is unknown, so both `=` and `:=` are accepted. Initializer lists and function arguments are not assignments |
| P33 | Two readings of #20 | `var q: i32^;` is `int32_t *q = 0;`; discarding is `x;` | (1) The user's example `var ptr: any^;` is applied to every reference: a pointer declared without a value is `nullptr`, local or global, except an `extern` declaration. (2) The discard idiom `x as void` went with `void`, and the user did not pick a replacement, so a value is discarded by writing it as a statement (C may warn about an unused value). Also, comparisons were C `int`s, so `println(p == nullptr)` printed `1`; since #23 it prints `true` |
| P34 | Property details | `(-5:i32).hex` is `-0x5`; `x.hex` emits `_Generic((x), ...)(x, kv_text1)`, with `uint8_t kv_text1[36];` at the top of the enclosing block | Integers are sign and magnitude (not two's complement), with lowercase digits and no padding. A NaN is `nan`, unsigned. The buffer is declared at the top of the enclosing block and fits the text of any type (41, 36, 47 and 132 bytes for `.dec`, `.hex`, `.oct` and `.bin`), so the text lives until that block ends, also when made in a brace-less `if`/`for` body or among a method call's arguments: storing `let t: u8^ := x.hex` is fine inside the block, but returning it is not (as with any C local). An enum's sign follows its C type, and a C bit-field must be converted first (gcc's `_Generic` does not match it). `.dec`/`.hex`/`.oct`/`.bin` stay properties on receivers kelvinc cannot see (`(a + b).hex`), because such fields are rare; since #22 it also sees the results of Kelvin functions and methods (P35), so `get().hex` reads a field `hex` of the struct `get()` returns. A Kelvin struct's own field of that name still wins, and a C struct's too |
| P35 | `.cstr` details | `s.cstr` is `s` itself for a `cstr`; `p.cstr` is `point__cstr(p, kv_text1)` with `uint8_t kv_text1[point__cstr_size]` | A string (`u8^`, `i8^`, a literal) is its own text, not a copy (`(null)` for null), and stays `const` if it was; a pointer to `volatile` bytes is an address. One value's buffer is 64 bytes. A struct's derived function comes with a size constant, `kv_cstr_size_point`, which C computes from the member types, so the buffer is exact; both are emitted only for structs whose `.cstr` is used, directly or as a member. Inside a struct, a string member shows at most 60 bytes and a longer one is cut with `...`; a pointer to a C typedef (`xmlChar^`, `uint8_t^`) is text or an address as C's type says; a member of a C typedef type shows numbers, bool, complex numbers, byte strings and `void *` as `.cstr` would, a char array as the text in it (never past its end), and anything else as `{...}` (C structs, other arrays, other pointer typedefs). A flexible array member behind a C typedef leaves the struct without `.cstr` (C's `sizeof` fails). kelvinc sees the type of names, `v as T`, compound literals and the results of Kelvin functions, and of methods when every method of that name returns the same type, and of `p^`, `a[i]` and fields of all of these. Anything else, such as `(c ? p : q).cstr`, gets one value's buffer, and if C finds a Kelvin struct there, it is a C error naming `kv_cstr_unseen_struct` (assign it to a variable first), never an overflow. C struct and union values have no `.cstr` (inside a Kelvin struct they show as `{...}`). `.cstr` of an array kelvinc can see is an error (C arrays are not values). A Kelvin struct cannot have a field named `cstr` (a keyword); a C struct's field `cstr` wins, also as a designator. Derived functions are marked `__attribute__((unused))` |
| P36 | How the shelving reads | `x.toString()`, `point.fmt(): cstr {...}` and `s: String` are errors that point at `.cstr`; `cstr const` is `uint8_t *const`; `cstr(v)` is an error | `String` stays a reserved word, and `toString` and `fmt` stay reserved as method names, so a later true string type can take them back without breaking code. Plain functions, variables and parameters named `toString` or `fmt` are fine (`printf(fmt: const u8^, ...)`). A call through a field of that name still works where the field is visible, or where kelvinc cannot see the receiver (a C struct). `cstr` behaves as `u8^` written out: qualifiers after it apply to the pointer, as with a C typedef, and `:=` assigns it (#19). It is not a converter (P18): write `v as cstr` |
| P37 | Details of #23 | `if (n > 0) { ... }` still works; `for (i = 0; i < n; i += 1) x += i;` keeps a single-statement body; `var x: i32 = a < b;` is 1 | Parentheses around a condition are grouping, so a `(...)` before the body's `{` is never a compound literal there; in a condition, `(T){...}` and `sizeof (T){...}` are compound literals only when the expression goes on after the `}` (`(struct point){1, 2}.x == n`), so `if n == sizeof(i32) {} {` has an empty body. C's `if (c) x = 1;` and `else x = 1;` are errors that ask for a block, and `do`'s body is a block too, like `while`'s. `for` and `switch` keep C's syntax, including a statement body for `for`, until decided. A `bool` converts to numbers as in C. A condition kelvinc cannot see is wrapped as `_Generic((c), bool: kv_bool, default: kv_condition_is_not_bool)(c)`; one it sees is printed as written. In a value position a comparison or logical operator is `((bool)(...))`, and `?:` between two `bool`s is a `bool` (C would promote it to `int`); a discarded `a && f();` statement keeps C's form, which clang does not call unused. Since a `?:` or `&&` needs `bool` operands, statements like `flag ~ f() || g();` need `bool(...)` |
| P38 | Details of #26 | `x = 1, y = 2;`, `for (...; ...; i += 1, p := p.next)`, `n := n^.next` | A comma list of assignments is allowed at the top of any expression statement, not just in a `for` clause, and runs left to right. (Before #27 each item could declare or assign on its own; since #27 a list either declares, after `let` or `var`, or assigns.) `p.next` is `(p + 1)` and `p.prev` is `(p - 1)` for a pointer whose type kelvinc sees, including results of Kelvin functions; `.next` of an array is an error that suggests `&a[1]`, and `any^` has no `.next`. On anything else `.next` is a field (a struct, a C type kelvinc cannot see). `p += 1` stays. The comma operator stays for expressions that do not assign. A statement such as `a || f();` is still allowed, and gcc `-Wall` calls its value unused |
| P39 | Details of #27 | `let p: i32^ := &x;` is `int32_t *const p`; `let a: i32[2] = {1, 2};` is `const int32_t a[2]`; `f(n: i32)` is `void f(const int32_t n)` where defined | A let names a value that cannot change through it: a let struct's fields and a let array's elements cannot be assigned, while a let pointer's target can. kelvinc reports assignments to lets it can see (names, their fields, elements of let arrays), and the C compiler enforces the rest through `const`. A let needs a value except in an `extern` declaration. Let parameters are `const` only in a function's definition (C ignores top-level `const` in prototypes), and an array parameter becomes the `const` pointer C makes of it; a parameter of a C typedef kelvinc cannot see gets no `const`, since the typedef may be an array (`jmp_buf`), and kelvinc alone checks it. Taking `&` of a let gives a `const` pointer, so storing it in a plain pointer is a C warning (discarded qualifiers). `x: i32 = 0;` without `let` or `var`, when the type starts with a type word, is an error with a hint; `again: n = 0;` is a label, as in C. C-style declarations get `var name: type` as their hint |
| P40 | Details of #28 | `for i in 0..<n { }` is `for (int64_t kv_i1 = 0, kv_end1 = n; kv_i1 < kv_end1; kv_i1++) { const int64_t i = kv_i1; ... }` | The bounds are evaluated once, before the loop. A closed range steps with a flag, so `for b: u8 in 250...255` ends instead of wrapping, and `continue` works in both. A bound is parsed down to the shifts (`0..<n - 1` is `0..<(n - 1)`). The loop variable's type is written, or is the upper bound's type if kelvinc sees it, else the lower one's, else `i64`, without `const` or `volatile` (the counter must change); both bounds and a written type must be integers. `for _ in ...` declares no variable, since C warns about an unused one. `in` is a keyword only after `for name`, so C names called `in` still work |
| P41 | Details of #29 | `var p: point;` is `struct point p;`; `sizeof(point)`; `var point: point;` | kelvinc resolves a bare tag name to `struct point` (or `union`/`enum`) wherever a type is read (after `:`, `as`, in compound literals), and writes the long form in the C: no C typedef is emitted, so a variable or function of the same name is fine. A tag declared so far counts, so a struct's members may name it (`next: node^`), as may a C struct that Kelvin declares (`struct timespec;`); a Kelvin tag hides a C typedef of the same name from a header. Where an expression could stand too, in `sizeof(name)` and `(name)...`: a Kelvin variable of that name wins (`sizeof(point)` after `var point: point` is the variable's size), from its own declarator on, as in C (`let p: node^ := malloc(sizeof(p^))`); a Kelvin function of that name wins too, except in `sizeof`, where a function's size is never meant (`node(v)` as a constructor and `sizeof(node)`); and a struct only declared in Kelvin (`struct timezone;`) is left to C there, because headers give such names to functions and variables too (`stat`, `timezone`), so `sizeof(struct timezone)` names the struct. C habits get the usual hints: `p: point = ...` (no `let`/`var`), `point^ p;`, `sizeof point` |
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
- ~~**Q11: C globals from headers.**~~ Answered by #27: a plain
  `optind = 1;` only assigns, so it reaches the header's global.
- **Q12: Infer from typed variables?** kelvinc now knows the declared type
  of every variable in scope (#19). Should `var n := list` infer `n`'s
  type from `list`, as `var n: struct node^ := list` currently spells it?
  Today only literals, `bool`s (#24, #25) and annotated values are
  inferred (#8, #11, #15).
- **Q10: Compound literals.** `(struct point){.y = 7}` keeps C's
  cast-like syntax (P19). Should it get a Kelvin spelling, such as
  `struct point{.y = 7}`?

## Unchanged from C (on purpose, for now)

These are everything else: operator precedence (including `==` binding
tighter than `&`), implicit conversions, integer promotion (to C's `int`,
which is `i32` on every supported target), the comma operator,
`?:` (with a `bool` condition, #23), `for`/`switch`/`goto`, compound literals, designated initializers, arrays that
decay to pointers, declare-before-use, `struct`/`union`/`enum` tags (also
types by their bare name since #29), and all
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
| `src/lexer.c` | C's lexical rules. Kelvin keywords `as`, `i8`…`u128`, `f32`, `f64`, `bool`, `true`, `false`, `String` (shelved), `any`, `nullptr`, `cstr`, `let`, `var`; `..<` and `...` for ranges; `~=`, no `^=`; a number ends before `.name` (P30) |
| `src/parser.c` | Recursive descent over C's grammar with the changes above, plus a table of declared names, their types and which are lets: it checks `=` against `:=` (#19) and assignments to lets (#27), and infers types (#25, #28) |
| `src/codegen.c` | Prints C: methods and properties become `_Generic` dispatch, every struct gets a derived `.cstr` and its size, property buffers are declared at the top of their block; postfix types become C declarators, `i32` becomes `int32_t` and `f64` becomes `double`, `p^` becomes `(*p)`, `~` becomes `^` |
| `src/main.c` | Driver: writes the C, finds the runtime, runs `$CC` with `-I<dir of .k>` and `libkelvin.a`, and optionally runs the program |
| `runtime/kelvin_prelude.h` | The prelude: `print`/`println` as `_Generic` macros, and the dispatch tables for `.cstr`, `.dec`, `.hex`, `.oct` and `.bin` |
| `runtime/prelude.c` | `print`/`println`, built into `libkelvin.{a,so,dylib}` |
| `runtime/string.c` | The text of values: `.cstr`, `.dec`, `.hex`, `.oct` and `.bin` |
| `tests/run.sh` | `tests/run/*.k` check output; `tests/error/*.k` check diagnostics; `tests/c/*.c` use libkelvin from C, linked statically and dynamically |

The driver adds `$KELVIN_CFLAGS` to the C compiler command line, for
libraries (`-lcurl`) and other flags. `--emit-c --no-line` shows the
generated C without `#line` directives.
