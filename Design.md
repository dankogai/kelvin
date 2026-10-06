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
| 1 | The type comes after the name | `int x = 0;` | `x:i32 = 0;` | 2026-10-01 |
| 2 | Postfix `^` for pointer types | `char *p;` | `p:u8^;` | 2026-10-01 |
| 3 | Postfix `^` to dereference | `*p`, `p->m` | `p^`, `p^.m` | 2026-10-01 |
| 4 | XOR is binary `~` | `a ^ b`, `a ^= b` | `a ~ b`, `a ~= b` | 2026-10-01 |
| 5 | Functions use `name:type` too, with no `fn` and no `->` | `long add(long a, long b)` | `add(a:i64, b:i64):i64` | 2026-10-01 |
| 6 | Integer types always say their size, and are built in | `int32_t` (via `<stdint.h>`) | `i8 i16 i32 i64 u8 u16 u32 u64`, plus `i128 u128` where available | 2026-10-01 |
| 7 | C's integer names are gone | `char`, `short`, `int`, `long`, `signed`, `unsigned` | `u8` (or `i8`), `i16`, `i32`, `i64`/`u64`, ... | 2026-10-01 |
| 8 | An inferred integer is `i64`; a written type is always explicit | | `i = 42;` is `i:i64 = 42;` | 2026-10-01 |
| 9 | Floating-point types say their size too | `float`, `double` | `f32`, `f64` | 2026-10-01 |
| 10 | `bool` is built in | `_Bool` (or `bool` via `<stdbool.h>`) | `bool` | 2026-10-01 |
| 11 | An inferred C double literal is `f64` | `double d = 1.5;` | `d = 1.5;` | 2026-10-01 |
| 12 | C headers are importable | `#include <stdio.h>` | `#import <stdio.h> as C` | 2026-10-01 |
| 13 | Literals carry no size hints; the declaration carries the type | `10UL`, `1.5f` | `val:u64 = 10`, `f:f32 = 1.5` | 2026-10-01 |
| 14 | No `(T)v` casts: convert with `T(v)` or `v as T` | `(int)x`, `(int *)malloc(n)` | `i32(x)`, `malloc(n) as i32^` | 2026-10-01 |
| 15 | ~~No `var`: `x:T = v` declares, and so does `x = v` when `x` is not declared yet~~ (superseded by #27) | `int32_t x = 0; long i = 42;` | `x:i32 = 0; i = 42;` | 2026-10-01 |
| 16 | `expr:T` annotates any expression; it means `expr as T` | `(uint16_t)0xdead`, `1UL << 40` | `0xdead:u16`, `1:u64 << 40` | 2026-10-01 |
| 17 | A prelude with `print()` and `println()`, in `libkelvin.{a,so,dylib}` | `printf("%" PRId64 "\n", n)` | `println(n)` | 2026-10-01 |
| 18 | Every type has methods; ~~`toString()` is mandatory; `fmt()` a la Raku~~ (shelved by #22) | | `point.area():f64 { ... }` | 2026-10-01 |
| 19 | `:=` assigns references (pointers); `=` assigns values | `int64_t *buffer = malloc(8 * 1024); p = q;` | `buffer := malloc(8 * 1024):i64^; p := q;` | 2026-10-01 |
| 20 | No `void`: `any^` is C's `void *`, `nullptr` is `(void *)0`, and `ptr:any^;` means `ptr := nullptr` | `void *p = NULL;` | `p:any^;` | 2026-10-02 |
| 21 | Properties: `x.size` is `sizeof(x)`; integers have `.dec`, `.hex`, `.oct` and `.bin`, and `f32`/`f64` have `.dec` and `.hex`, as `u8^` text in a stack buffer | `sizeof x`, `snprintf(buf, n, "0x%x", x)` (unsigned `x`) | `x.size`, `x.hex` | 2026-10-02 |
| 22 | `toString()`, `fmt()` and `String` are shelved until Kelvin has a true string type. Every type has `.cstr`, its text as `cstr` on the stack, and `cstr` is a built-in name for `u8^` | `snprintf(buf, n, "%lld", x)`; `char *s` | `x.cstr`; `s:cstr` | 2026-10-02 |
| 23 | `if`, `while` and `do` take a condition without parentheses and a block body; every condition, and every operand of `&&`, `||` and `!`, is a `bool`; comparisons and logical operators give a `bool` | `if (n) x = 1;`, `while (fgets(b, n, f))` | `if n != 0 { x = 1; }`, `while fgets(b, n, f) != nullptr { ... }` | 2026-10-03 |
| 24 | `true` and `false` infer `bool` | `bool t = true;` | `t = true;` | 2026-10-03 |
| 25 | A `bool` expression infers `bool` | `bool ok = a < b;` | `ok = a < b;` (and any seen type since #47) | 2026-10-03 |
| 26 | Assignment is a statement; `++` and `--` are gone; pointers step with `.next` and `.prev` | `*p++ = *q++;`, `a = b = 0;` | `p^ = q^; p := p.next; q := q.next;`, `a = 0, b = 0;` | 2026-10-03 |
| 27 | `let` and `var` declare, with the type after the name: a `let` never changes (C's `const`); parameters are lets unless written `var`; a plain `x = v` only assigns | `const int k = 42; int n = 0;` | `let k = 42; var n:i32 = 0;`, `f(var p:u8^)` | 2026-10-03 |
| 28 | Ranges: `for i in a..<b { }` and `for i in a...b { }`, with `i` a `let` | `for (int i = 0; i < n; i++)` | `for i in 0..<n { ... }` | 2026-10-03 |
| 29 | A `struct`, `union` or `enum` is a type by its bare name, as if typedef'd | `typedef struct point point;`, `struct point p;` | `var p:point;` | 2026-10-03 |
| 30 | `for x in s { }` walks a sequence that ends at a terminator: a string up to its NUL, a list along `next`, an array of known length | `while (*s) { c = *s++; ... }` | `for c in s { ... }` | 2026-10-03 |
| 31 | A function type is a function's head without names, `(T, U):R`: C's pointer to a function | `int (*cmp)(const void *, const void *);` | `var cmp:(const any^, const any^):i32;` | 2026-10-03 |
| 32 | Anonymous functions `{ ... }`, which enclose nothing. `$0`, `$1` or `$[k]` are the parameters where kelvinc sees their types, and `{ (a:T, b:U):R in ... }` writes them elsewhere. A body of one expression is the result, and the last argument of a call may follow the call | a `static` function written only to be passed | `sort(xs, n) { $0 < $1 }` | 2026-10-03 |
| 33 | Anonymous functions are inline by default: C's `static inline` | `static inline bool before(int64_t a, int64_t b)` | `{ $0 < $1 }` | 2026-10-04 |
| 34 | Every variable has `v.type`, its type, used where a type goes, and `v.typename`, its Kelvin spelling as `cstr` | `__typeof__(v) w;` | `var w:v.type;`, `v.typename` | 2026-10-04 |
| 35 | A `;` may be left out at the end of a line, and a function whose body is one expression returns it, unless kelvinc sees it has no value or the function is `main`. In a function with a result, `return` at the end of a line takes the next line | `x = 1;`, `long sq(long x) { return x * x; }` | `x = 1`, `sq(x:i64):i64 { x * x }` | 2026-10-04 |
| 36 | Converters read numbers from text, as C's `strtol` and `strtod` do, with an optional base for integers; `text.T` is `T(text)` | `strtol(s, NULL, 8)`, `atof(s)` | `i32("755", 8)`, `f64(s)`, `"42".i64` | 2026-10-05 |
| 37 | Pointers and functions have `.addr`, their address as a `uintptr_t`, and `.hex`, `0x` and all its digits | `(uintptr_t)p`, `printf("%p", p)` | `p.addr`, `p.hex` | 2026-10-05 |
| 38 | What kelvinc writes is named `_kv_`, after its source: `_kv_n_text`, `_kv_i_count`, `_kv_main_fn` | (no C counterpart) | `uint8_t _kv_n_text[36];` instead of `kv_text3` | 2026-10-05 |
| 39 | Template literals: `` `...` `` may span lines, and `${expression}` is the expression's text as `print` shows it; the text is on the heap, freed when the enclosing block ends (on the stack since #44) | `snprintf(buf, n, "Hello, %s!", name)` | `` `Hello, ${name}!` `` | 2026-10-05 |
| 40 | `#import` of a Kelvin file brings in its source, once per program: `"x.k"` next to the importing file, `<lib/x.k>` from Kelvin's home (`<x.k>` from `modules/` since #46) | `#include "x.h"` and a separately compiled `x.c` | `#import <lib/complex.k>` | 2026-10-05 |
| 41 | Functions overload: one name may have several parameter lists, chosen by the arguments' types, and a Kelvin function of a C function's name overloads C's | `csin(z)` beside `sin(x)` | `sin(z:complex64):complex64` beside C's `sin(x)` | 2026-10-05 |
| 42 | A struct or union may define operators: `+ - * / % == != < <= > >=`, and unary `-` | `cadd(a, b)` | `+(a:complex64, b:complex64):complex64 { ... }`, then `a + b` | 2026-10-05 |
| 43 | `lib/complex.k` (`modules/complex.k` since #46): `complex32` and `complex64`, with arithmetic and the elementary functions, without C's `_Complex` | `double complex z = 1.0 + 2.0 * I;` | `let z:complex64 = complex64(1.0, 2.0)` | 2026-10-05 |
| 44 | Template literals use no heap: the text is in a buffer at the top of the enclosing block, with room for each value's longest text, and a string value longer than 256 bytes is cut with `...` | `char buf[N]; snprintf(buf, sizeof buf, "%s", name)` | `` `Hello, ${name}!` ``, as before | 2026-10-06 |
| 45 | A top-level function, method or operator is declared with `let`, as a value that never changes is | `long add(long a, long b)` | `let add(a:i64, b:i64):i64` | 2026-10-06 |
| 46 | `lib/` is `modules/`, which also holds `kelvin_prelude.h` and `libkelvin`; `<x.k>` is looked for in `./modules`, then in Kelvin's `modules/`, where C also looks for headers and libraries | `-I`, `-L` and `#include <x.h>` | `#import <complex.k>` | 2026-10-06 |
| 47 | A declaration infers its type from any value whose type kelvinc sees: a Kelvin function's result, a variable, a field, `&x`, ... but not arithmetic, nor what only C sees | `struct complex64 z = complex64(0.0, 1.0);` | `var z = complex64(0.0, 1.0)` | 2026-10-06 |
| 48 | An array is initialized with `[...]`; a struct or union keeps `{...}` | `int a[3] = {1, 2, 3};` | `let a:i32[3] = [1, 2, 3]`, `let a = [1, 2, 3]` | 2026-10-06 |

Notes:

- (2, 3) `*` means only multiplication. `p^^` is `**p` (and `p++^` was
  `*p++` until #26 removed `++`). Postfix operators apply left to right,
  so `p^[i]` is `(*p)[i]`.
- (4) Unary `~` is still bitwise NOT, in the same way that `-` is both unary
  and binary. Since `^` never means XOR, `p^ = x` is always an assignment
  through `p`, which is why `^=` is not a token.
- (5) Types are always written `name:type`, even for functions. A
  function's type follows its parameter list. A top-level `name(` starts a
  function, and a prototype ends with `;` or the end of its line (#35)
  instead of a body. Since #45 a function is declared with `let`:
  `let add(a:i64, b:i64):i64`.
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
  `u8(300)` is 44, except that a converter of text reads the number in it
  (#36). `T(v)` takes one value (and for text, a base: #36),
  and a statement may start with one. `(T)v` is an error that suggests the
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
    only when its declarator ends with `;`, `,` or `=`, or with a line
    end or `}` since #35, so `n * f(x) == 4 || g();` stays an expression.
    So do `a * b` and `a ~ b` where kelvinc sees that `a` is a variable
    or function (but not before `=`), where they are the one expression a
    body returns, or where `b` is declared in the same block already,
    since C does not read those as declarations. Examples:
    - `i32 * r = &x;` suggests `r:i32^`, and `const u8 *s` suggests
      `s:const u8^`.
    - `size_t a[3];` suggests `a:size_t[3]`, `static size_t m;`
      suggests `static m:size_t`, and `size_t * (p) = q;` and
      `size_t * p^ = &q;` are caught too.
    - `size_t f(void);` points to function syntax, and a C function-pointer
      declarator such as `size_t (*f)(size_t);` suggests the function type
      `var f:(...):size_t` (#31).
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
  - `name:T [= v]` declares (or `name:T [:= v]` for a reference, #19),
    at the top level, in blocks and in `for` initializers. Several
    declarators are separated by commas: `a:i32 = 1, b = 2;`.
  - `name = v` (or `name := v` for a reference) declares `name` when no
    enclosing scope (block, function, parameters, globals, functions, enum
    constants) has declared it.
    Otherwise it assigns. At the top level it always declares. The type is
    inferred from `v` (#8, #11): a literal, or a value written `v:T`,
    `v as T` or `T(v)`. Anything else needs `name:T = v`, or
    `name:T := v` for a reference.
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
    Declare such globals first with `extern optind:i32;` (Q11).
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
  `point.area():f64 { ... self ... }` with an implicit `self`.
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
  `let` or `var` (`let x = 42;`, `var n:i32 = 0;`,
  `static var calls:i32;`), so a plain `x = 0;` always assigns, which
  also ends #15's guessing between declaring and assigning. Parameters
  are lets unless written `var`, as in `f(var p:i32^) { p := p.next; }`,
  and a method's `self` is a mutable copy (`self.x += 1` is fine). A
  `let` is C's `const` (agreed in the discussion): a let pointer is
  fixed, but what it points to may change. Struct members keep
  `name:type;`.

- (28) Agreed details: C's counting `for` is discouraged in favour of
  ranges, `for i in 0..<count { }` (half-open) and `for i in 1...n { }`
  (closed), where `i` is immutable in the body. `i`'s type comes from the
  bounds (or is written, `for i:u8 in ...`), and ranges exist only in
  `for` for now. C's `for (...)` stays, written `for (var i = 0; ...)`.

- (29) Agreed details: `struct st` and `union un` are "auto-typedef'd", so
  `st` and `un` are types without the keyword; the user chose to include
  enums, as C++ does, and to keep `struct point` working as well.

- (30) Agreed details: loops such as `while s^ != 0 { ...; s := s.next; }`
  are frequent, so `for c in s { }` walks them, for any sequence ended by
  a terminator value (usually `'\0'` or `nullptr`), linked lists
  included. For a list, the loop variable is each node's pointer, found
  through the `next` field. An array of known length is walked up to its
  length, breaking early at the terminator. A `nullptr` string is empty.

- (31) Agreed details: anonymous functions (#32) need their parameters'
  types, and kelvinc cannot see those of a C header's functions, so Kelvin
  got function types first. The user chose `(T, U):R`, the shape of
  Swift's `(T, U) -> R`, over `fn(T, U):R` and `((T, U):R)^`.

- (32) Agreed details: the user asked for anonymous functions without
  closures ("True closures are too much for normal C (ignore GNU
  extensions)"), with Swift's trailing form, `$` as the argument stack,
  `$[idx]`, and `$0` for `$[0]`. Where no type is in sight, the user chose
  Swift's `{ (a:T, b:U):R in ... }` over an unnamed function head and
  `{ ... } as (T, U):R`. A body of one expression is the result
  (`{ $0 < $1 }`). `$[k]` takes a decimal number only, since each
  parameter may have its own type, and `$` works only in anonymous
  functions.

- (33) Agreed details: "anonymous function are inlined by default". The
  user chose C11's `static inline`, a hint the C compiler follows when
  optimizing, over GNU's `always_inline` and over kelvinc specializing
  the callee itself. There is no way to opt out for now; one may come
  with a Kelvin spelling of `inline` for named functions.

- (34) Agreed details: "every variable has `.type` where
  `v.type == typeof(v)`. if possible, add `.typename` which returns a
  `cstr`". The user chose: `.type` goes where a type goes, and in an
  expression `x.type` stays a field (C structs often have one); it is
  the type kelvinc sees, else `__typeof__`; `.typename` is the Kelvin
  spelling, else `_Generic`'s name of a built-in type, else `"?"`. The
  user's earlier `(p0 - p1).diff`, a `ptrdiff_t`, was to wait for a
  change of its own (Q13), and was later set aside.

- (35) Agreed details: "like many modern languages, `;` can be omitted
  if the statement ends in line and `return` is not necessary for
  expressions." The user chose Swift's rule (a new line ends a statement
  once it is complete; an operator, `.member`, `[`, `?`, `:` or `as` on
  the next line goes on, a `(` or `{` there starts the next statement)
  over Go's; `return` may be left out where a body is one expression, as
  in Swift, rather than for the last expression; and `;` stays valid,
  while Style.md, the examples and the docs leave it out (the tests keep
  both forms). After review the user chose, over Swift's literal rule
  and over Rust's (`;` makes it a statement), that one expression is not
  returned where kelvinc sees it has no value (`println`, a function with
  no result, `_Pragma`), and that `main` keeps C's rule that its end
  returns 0, so `main():i32 { printf("hi\n") }` exits 0. They also chose
  Swift's `return` over Go's in a function with a result: there
  `return` at the end of a line takes the expression on the next line,
  while in one with no result it ends at its line and kelvinc reports a
  statement after it in the same block, which could never run.

- (40) Agreed details: "you can `#import <lib/complex.k>`". The user
  chose that an import brings in the file's source, compiled with the
  program as if written in place, rather than a separately compiled
  library with a generated header. `<...>` is looked for in Kelvin's
  home, where the runtime is (`$KELVIN_HOME`, kelvinc's directory, its
  parent), and `"..."` next to the importing file.

- (41) Agreed details: "ensure that kelvin is multi-dispatch.
  `sin(r:f64):f64` is distinct from `sin(z:complex):complex`." The user
  chose that only overloaded and imported functions get C names made
  from their parameter types (`sin__complex64`), while a program's one
  function of a name keeps its name. So that a Kelvin function can
  overload C's, one that shares its name with a C function the program
  calls is named so too (P52). Overloads are chosen statically by the
  types kelvinc sees, and by C's `_Generic` where only C sees an
  argument's type.

- (42) Agreed details: the user chose operators over named functions
  (`cadd(a, b)`) for complex arithmetic. An operator is a function
  written with the operator as its name, overloaded by its types like
  any other.

- (43) Agreed details: "add `lib/complex.k` That implements complex
  arithmetics including elementary functions. DO NO USE C99's Complex.
  `struct complex { real:f64; imag:f64 }`. `exp(z) =
  exp(z.real)*{cos(z.imag), sin(z.imag) }`, for instance. maybe `complex`
  should be named `complex64` with corresponding implementation of
  `complex32`. we are yet to go for generics (even I am tempted to)." The
  user chose "complex{32,64,128} where f{32,64,128} are available. the
  last one might not be available for some platforms. complex128 iff
  f128 is available on the platform", and then `complex32` and
  `complex64` now, `complex128` with `f128` later. The number is the
  size of each part, as in `f64`.

- (44) Agreed details: "let's make template literals heap-free. so far
  as I know that is the only feature of kelvin which implicitly use
  heap." An audit confirmed that templates were the only implicit heap
  use in kelvinc's C, the prelude and libkelvin; libc's own (the stdout
  buffer, and on macOS a small cache for formatting floats) remains, as
  for C's `printf`. Of three designs, the user took the bounded one, with
  each recommendation: a string value is cut at 256 bytes, as P35 cuts a
  string member (`KV_TEMPLATE_STR`, which `-DKV_TEMPLATE_STR=n` changes);
  each evaluation builds its text in a buffer of its own and then copies
  it, as before, so the order of evaluation and ``s := `${s}b` `` stay as
  they are; the check that the text does not outlive its block stays as
  it is, its gap for fields, elements and `p^` (shared with `.hex` and
  `.cstr` text) left for a later change; and for longer text there is
  only the macro for now, writing a template into a byte array to be
  proposed later.

- (45) Agreed details: "make `let` mandatory for toplevel functions.
  Kelvin allows anonymous functions meaning internal functions are
  available like `var idi64:(x:i64):i64 = { x }` possible. mandating
  `let` makes the language a little more consistent." Methods and
  operators are functions, so they take `let` too, and `static` or
  `extern` goes before it, as for a variable. The user chose to keep
  functions at the top level: inside a function, `let f(...)` is an error
  that shows the anonymous function a let holds there (#32); `var f(...)`
  is an error too, since a function never changes (P57).

- (46) Agreed details: "move `lib/` to `modules/` and move
  `libkelvin.{a,dylib,*.so}` therein. add `./modules/` default search
  directories of the language. Both "include" files and compiled
  libraries can reside." The user chose, with each recommendation: `<x.k>`
  is looked for in `./modules` of the directory kelvinc runs in, then in
  Kelvin's own `modules/`, so `<lib/complex.k>` is now `<complex.k>`;
  both are where C looks for headers and libraries too (`-I` and `-L`),
  while kelvinc links only libkelvin itself; and `kelvin_prelude.h` moves
  to `modules/` as well, which `make install` copies to
  `$PREFIX/lib/kelvin/modules` (P58).

- (47) Agreed details: "why can not you infer the type of `i`? RHS is
  obviously `complex64`." The rule of #11, #24 and #25, that only
  literals, bools and annotated values infer a type, dates from when
  kelvinc knew no types; since #41 it tracks the result type of every
  Kelvin function and method, and #25 already infers `bool` from one.
  The user chose to infer from every value whose type kelvinc sees,
  "with arithmetic excluded": `small + 1` has C's promoted type, which
  would surprise. A value only C sees still needs a written type, since
  `__auto_type` would leave kelvinc blind to it (P59).

- (48) Agreed details: "use `[]` for array initializations.
  `[0,1,2,...]` instead of `{0,1,2,...}`. struct/union inits remains
  the same." The user chose, with each recommendation, that `{...}` for
  an array kelvinc sees, and `[...]` for a struct, are errors with a
  hint; that an array literal infers its type from items of one type,
  as #47 infers from seen values; and for compound literals
  "`(i32[])[1,2,3]`. the number of the elements are inferred from rhs."
  (P60).

- (39) Agreed details: "implement the template literal a la JS.
  backquote up to backquote. multi-line. `${expression}` is substituted
  with the string representation of `expression`". The user chose that
  the text is on the heap, freed automatically when the enclosing block
  ends (any length, and the same lifetime as `.cstr` text), and that
  `${x}` is shown as `print` shows it.

- (38) Agreed details: "When you add hidden variables when translating
  to C, `kv_` doesn't look automatic enough. use `_kv_` instead and
  trailing word should be the one the variable is derived.
  `_kv_varname_text[36]` instead of `kv_text3[36]` or when you resort the
  the latter style, count the prefix number from `0` instead of `1`."
  The user chose: everything kelvinc writes is renamed, file-scope names
  too (C reserves file-scope names starting with `_`, which gcc and clang
  accept; clang warns only under `-Wreserved-identifier`), while the
  runtime's API keeps `kv_`; a name that repeats in a function gets 1,
  2, ..., and one with no source counts from 0 (`_kv_text0`).

- (37) Agreed details: "Add `p.addr` to pointer types which always
  returns its own numerical value. `p.hex` returns its stringified value
  in a printf format `%016p` or `%08p` depending on the size of the
  pointer." The user also linked a claude.ai conversation, which needs a
  sign-in, so Claude did not read it. Since `%016p` counts the `0x` in
  its width (`0x0000016ee86888`, 14 digits) and the 0 flag with `%p` is
  undefined in C, Claude asked. The user chose `uintptr_t` for `.addr`;
  `0x` and all the digits for `.hex` (`0x000000016ee86888`, 8 digits on
  a 32-bit target); and both properties for every pointer and function
  value, with an array an error, `.dec`, `.oct` and `.bin` of a pointer
  still errors, and `.cstr` unchanged.

- (36) Agreed details: "add numerical string to numerical value
  converters as `i64("42")`, `"42".i64` and such. You can add base as
  `i32("755",8)`. You can use C's `strtol` (and friends) and `strtod`."
  The user chose that strings parse (a literal, `cstr`, `u8^`/`i8^`, C's
  `char *` through `_Generic`) while numbers and other pointers convert
  as before; that bad text is read the way `strtol` reads it (the
  longest number, else 0), with out-of-range values clamped to the type's
  limits; and that the base is 10 unless given, with Kelvin's own
  prefixes accepted when a base is.

- (19) Agreed details: the user's example `buffer := malloc(8 * 1024):i64`
  was a typo for `:i64^`, and `v:T` keeps meaning `v as T`.
  - Declarations of references use `:=` too (`p:i32^ := &x`, or
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
all. None of them has been explicitly agreed yet, except where a row
says "as agreed".

| # | Decision | Example | Why |
|---|----------|---------|-----|
| P1 | Array brackets are postfix too | `var a:i32[4];` | Mixing postfix `^` with prefix `[4]` would make `[4]i32^` ambiguous |
| P2 | Type suffixes apply left to right, but a run of brackets reads in C order | `i32^[4]` is `int32_t *[4]`, `i32[4]^` is `int32_t (*)[4]`, `i32[2][3]` is `int32_t[2][3]` | So that `var m:i32[2][3]` indexes as `m[1][2]`, exactly as in C |
| P3 | ~~Variable declarations start with `var`~~ | | Superseded by #15, and back, with `let`, since #27 |
| P4 | `()` means no parameters | `let f():i32` is `int32_t f(void)` | C's `()` (unspecified parameters) is obsolescent |
| P5 | No `: type` after a function means it returns nothing | `let f()` is `void f(void)` | Same as v0.1. Kelvin itself has no `void` (#20) |
| P6 | Qualifiers bind to what is on their left; a leading qualifier binds to the base | `u8 const^` and `const u8^` are both `const uint8_t *`; `u8^ const` is `uint8_t *const` | This is C's rule, written postfix |
| P7 | Several names per declaration | `var a:i32 = 1, b:u8^;` | Each name has its own full type, since C's `int a, *b` split is gone |
| P8 | Struct and union members end with `;` | `struct p { x: i32; y: i32; };` | Kept from C, as is the `;` after `}`; since #35 a new line or the `}` ends them too, as in `struct p { x: i32; y: i32 }` |
| P9 | Storage class goes in front | `static let f():i32`, `static var n:i32`, `extern var optind:i32` | Kept from C |
| P10 | Anonymous enums are allowed | `enum { LIMIT = 3 };` | The common C idiom for constants |
| P11 | Kelvin reserves the sized type names, `String`, `any`, `nullptr`, `cstr`, `let` and `var` (`as` is reserved by #14) | | C code that uses them as identifiers cannot be named from Kelvin yet. `var` was unreserved by #15 and, with `let`, reserved again by #27. `String` stays reserved while shelved (#22) |
| P12 | Literals are passed through verbatim (minus suffixes, #13) | `0x1f`, `017`, `0b101`, `'\n'`, `"a" "b"` | So C interprets them exactly as it always has. Octal `017` and C23's `0b` stay |
| P13 | `u8` and C's `char` mix freely | `let s:u8^ := "hi";`, `let printf(fmt:const u8^, ...):i32;`, `let main(argc:i32, argv:u8^^):i32` | Follows from #7. String literals and libc use `char`, while `u8` is `unsigned char`. They are ABI-identical, so kelvinc silences C's pointer-sign and library-redeclaration warnings, and emits `main`'s `argv` as `char **`, which C requires |
| P14 | `true` and `false` are built in alongside `bool` | `var done:bool = false;` | `<stdbool.h>` provides all three together, and a `bool` without them would be half a feature. They are reserved words, and are `bool`s (P23) |
| P15 | Any identifier after `:` or `as` is a type name | `let f:FILE^ := stdout;`, `n as size_t` | Needed for #12: headers define typedef names that Kelvin cannot know without reading them. After `:` or `as` a type is certain, so this is unambiguous |
| P21 | How `print` formats values | `println(10.0, " ", 0.1:f32, " ", 1e300)` prints `10.0 0.1 1e+300` | Integers print in decimal, including `i128`/`u128`. Floats print in the shortest text that reads back the same, always with a `.` or an exponent. As agreed on 2026-10-06, they follow Swift's rule: plain decimal from 0.0001 up to 2 to the power of the type's mantissa bits (2^53 for `f64`, 2^24 for `f32`, `LDBL_MANT_DIG` bits for C's `long double`), where every integer is exact, and C's exponent form otherwise: `10.0`, `0.0001`, `9007199254740992.0`, but `1e+16`, `9.5e+15` and `1e-05`. Both forms use `.`, whatever the C locale's decimal point (agreed the same day). Every NaN prints `nan`, whatever its sign bit. `bool` prints `true`/`false`. `u8^`, `i8^` and string literals print as strings, with `(null)` for a null pointer. Other pointers print as addresses, and C's `char` as a character. Dispatch is by C type via `_Generic`; comparisons, `&&`, `||` and `!` are `bool`s since #23, so `x == y` prints `true` |
| P22 | Runtime layout and linking | `make` builds `libkelvin.a` plus `libkelvin.dylib` (macOS) or `libkelvin.so` (Linux); all in `modules/` beside the header since #46, and `make install` copies them to `$PREFIX/lib/kelvin/modules` | kelvinc links `libkelvin.a` statically, so programs need no runtime library at run time. It finds the runtime in Kelvin's `modules/` (P58). The shared libraries are for use from C and other toolchains. Zero-argument `print()`/`println()` rely on `__VA_OPT__`, which gcc and clang accept in C11 mode |
| P23 | `true` and `false` are `bool`s in the generated C | `println(true)` prints `true` | C's `true` is the `int` `1`. kelvinc emits `(bool)true`, so the prelude sees a `bool`. Arithmetic is unchanged (`true + 1` is 2) |
| P24 | A decimal literal above `INT64_MAX` gets C's `U` in the generated C | `18446744073709551615:u64` | Without suffixes (#13), C has no signed type for it and warns, although it already treats it as unsigned. kelvinc writes the `U` |
| P25 | ~~`String` holds up to 255 bytes inline, plus a NUL~~ | | Shelved by #22 |
| P26 | Method dispatch | `p.area()` becomes `({ __auto_type t = p; _Generic((t), ..., struct point: point__area, ...)(t); })` | kelvinc has no type checker, so C11 `_Generic` picks the method, and the receiver is evaluated once into a temporary (P31). The rules that follow from this: (1) as in C, a method must be declared (defined or prototyped as `let point.area():f64;`) before a call, for every receiver type; a method may call itself; (2) `x.name(...)` is a method call when `name` is a method somewhere in the file, and a call through a field otherwise; (3) enums cannot have methods, because C cannot tell an enum from its integer type; (4) `toString` and `fmt` cannot be defined while shelved (#22); (5) C typedef names (`size_t`) cannot be receivers; (6) `self` is passed by value; (7) `point.area` is the C function `point__area`, and two methods whose C names would collide (`a_.b`, `a._b`) are an error; (8) method calls cannot appear in global initializers |
| P27 | The text of built-in types, now `.cstr` (#22) | `0.1.cstr` is `0.10000000000000001`, `(0.1:f32).cstr` is `0.100000001` | Lossless, as agreed for `f64` (`%.17g`): `f32` uses `%.9g` and `long double` `%.21Lg`, and a NaN is `nan`. Complex numbers are `re+imi` (`1+2i`). Integers are decimal (including 128-bit) with no `+`, `bool` is `true`/`false`, and other pointers are hex addresses (`0x0` for null) |
| P28 | The derived text of a struct, now `.cstr` (#22) | `{from: {x: 3, y: 4}, to: {x: 6, y: 8}, tag: edge}`, `[{x: 0, y: 0}, ...]` | Fields are written `name: value`, nested structs recurse, and arrays print as `[a, b]` (a flexible array member as `[...]`). Text is unquoted, and pointers print as addresses (`u8^`/`i8^` as text). Fields of C types print through C's type (scalars) or as `{...}`. A union prints as `<union name>`, since its active member is unknown. Derived functions are `static inline`, so two files that share a struct still link |
| P29 | ~~`fmt()`~~ (shelved by #22; this was its design) | `n.fmt("%5d")`, `255.fmt("%#x")`, `42.fmt("%.2f")` is `42.00`, `(-1:i32).fmt("%x")` is `ffffffff` | One conversion (`diouxXcfFeEgGaAsp`) with flags, width and precision (each at most 4096), plus any text and `%%`. No length modifiers (#13: no size hints), since the value's own type decides. The value is converted to the conversion's kind (a float to an integer only within range), and an unsigned conversion of a negative value shows its bits in the value's own width. Integers, including 128-bit ones, are formatted by Kelvin with every flag defined; flags C leaves undefined for a conversion (`%05c`, `%#d`) are ignored. The format is never passed to C's printf. Anything else gives `<invalid format>` |
| P30 | A number ends before `.name` | `2.cstr`, `1.5.hex`, `0xff.bin`, `(7:i64).inc()` | So properties and methods apply to literals. `1.e5` and hex floats such as `0x1.f4p+9` are still numbers. `1.f` or `1.L` (a C suffix spelled as a field) is an error |
| P31 | Method calls use two GNU C extensions in the generated C, as does a property whose receiver holds a method call or property | `({ __auto_type _kv_p_self = p; ...; })` | A statement expression and `__auto_type` evaluate the receiver once and keep chained calls (`x.a().b().c()`) linear in size; without them the receiver had to be printed twice per call, doubling the C at each link of a chain. gcc and clang accept both in C11 mode. The ABI is unaffected |
| P32 | What counts as a reference for `:=` | `var p:i32^` (a reference), `var a:i32^[2]` (a value), `var t:pthread_t` (unknown) | A pointer type is a reference. Built-in types, structs, unions, enums and arrays (even of pointers) are values, except that an array parameter is a pointer, as C adjusts it (`var argv:u8^[]`, so `argv := argv + 1`). A C typedef name is unknown, so both `=` and `:=` are accepted. Initializer lists and function arguments are not assignments |
| P33 | Two readings of #20 | `var q:i32^;` is `int32_t *q = 0;`; discarding is `x;` | (1) The user's example `var ptr:any^;` is applied to every reference: a pointer declared without a value is `nullptr`, local or global, except an `extern` declaration. (2) The discard idiom `x as void` went with `void`, and the user did not pick a replacement, so a value is discarded by writing it as a statement (C may warn about an unused value). Also, comparisons were C `int`s, so `println(p == nullptr)` printed `1`; since #23 it prints `true` |
| P34 | Property details | `(-5:i32).hex` is `-0x5`; `x.hex` emits `_Generic((x), ...)(x, _kv_x_text)`, with `uint8_t _kv_x_text[36];` at the top of the enclosing block | Integers are sign and magnitude (not two's complement), with lowercase digits and no padding. A NaN is `nan`, unsigned. The buffer is declared at the top of the enclosing block and fits the text of any type (41, 36, 47 and 132 bytes for `.dec`, `.hex`, `.oct` and `.bin`), so the text lives until that block ends, also when made in a brace-less `if`/`for` body or among a method call's arguments: storing `let t:u8^ := x.hex` is fine inside the block, but returning it is not (as with any C local), and kelvinc reports it in a `return` or a one-expression body (#35). An enum's sign follows its C type, and a C bit-field must be converted first (gcc's `_Generic` does not match it). `.dec`/`.hex`/`.oct`/`.bin` stay properties on receivers kelvinc cannot see (`(a + b).hex`), because such fields are rare; since #22 it also sees the results of Kelvin functions and methods (P35), so `get().hex` reads a field `hex` of the struct `get()` returns. A Kelvin struct's own field of that name still wins, and a C struct's too |
| P35 | `.cstr` details | `s.cstr` is `s` itself for a `cstr`; `p.cstr` is `_kv_point_cstr(p, _kv_p_text)` with `uint8_t _kv_p_text[_kv_point_cstr_size]` | A string (`u8^`, `i8^`, a literal) is its own text, not a copy (`(null)` for null), and stays `const` if it was; a pointer to `volatile` bytes is an address. One value's buffer is 64 bytes. A struct's derived function comes with a size constant, `_kv_point_cstr_size`, which C computes from the member types, so the buffer is exact; both are emitted only for structs whose `.cstr` is used, directly or as a member. Inside a struct, a string member shows at most 60 bytes and a longer one is cut with `...`; a pointer to a C typedef (`xmlChar^`, `uint8_t^`) is text or an address as C's type says; a member of a C typedef type shows numbers, bool, complex numbers, byte strings and `void *` as `.cstr` would, a char array as the text in it (never past its end), and anything else as `{...}` (C structs, other arrays, other pointer typedefs). A flexible array member behind a C typedef leaves the struct without `.cstr` (C's `sizeof` fails). kelvinc sees the type of names, `v as T`, compound literals and the results of Kelvin functions, and of methods (the method of the receiver's type where kelvinc sees it, otherwise when every method of that name returns the same type), and of `p^`, `a[i]` and fields of all of these, and of a `?:` between two values of one such type (#34). Anything else, such as `(q, p).cstr`, gets one value's buffer, and if C finds a Kelvin struct there, it is a C error naming `kv_cstr_unseen_struct` (assign it to a variable first), never an overflow. C struct and union values have no `.cstr` (inside a Kelvin struct they show as `{...}`). `.cstr` of an array kelvinc can see is an error (C arrays are not values). A Kelvin struct cannot have a field named `cstr` (a keyword); a C struct's field `cstr` wins, also as a designator. Derived functions are marked `__attribute__((unused))` |
| P36 | How the shelving reads | `x.toString()`, `let point.fmt():cstr {...}` and `s:String` are errors that point at `.cstr`; `cstr const` is `uint8_t *const`; `cstr(v)` is an error | `String` stays a reserved word, and `toString` and `fmt` stay reserved as method names, so a later true string type can take them back without breaking code. Plain functions, variables and parameters named `toString` or `fmt` are fine (`let printf(fmt:const u8^, ...)`). A call through a field of that name still works where the field is visible, or where kelvinc cannot see the receiver (a C struct). `cstr` behaves as `u8^` written out: qualifiers after it apply to the pointer, as with a C typedef, and `:=` assigns it (#19). It is not a converter (P18): write `v as cstr` |
| P37 | Details of #23 | `if (n > 0) { ... }` still works; `for (i = 0; i < n; i += 1) x += i;` keeps a single-statement body; `var x:i32 = a < b;` is 1 | Parentheses around a condition are grouping, so a `(...)` before the body's `{` is never a compound literal there; in a condition, `(T){...}` and `sizeof (T){...}` are compound literals only when the expression goes on after the `}` (`(struct point){1, 2}.x == n`), so `if n == sizeof(i32) {} {` has an empty body. C's `if (c) x = 1;` and `else x = 1;` are errors that ask for a block, and `do`'s body is a block too, like `while`'s. `for` and `switch` keep C's syntax, including a statement body for `for`, until decided. A `bool` converts to numbers as in C. A condition kelvinc cannot see is wrapped as `_Generic((c), bool: kv_bool, default: kv_condition_is_not_bool)(c)`; one it sees is printed as written. In a value position a comparison or logical operator is `((bool)(...))`, and `?:` between two `bool`s is a `bool` (C would promote it to `int`); a discarded `a && f();` statement keeps C's form, which clang does not call unused. Since a `?:` or `&&` needs `bool` operands, statements like `flag ~ f() || g();` need `bool(...)` |
| P38 | Details of #26 | `x = 1, y = 2;`, `for (...; ...; i += 1, p := p.next)`, `n := n^.next` | A comma list of assignments is allowed at the top of any expression statement, not just in a `for` clause, and runs left to right. (Before #27 each item could declare or assign on its own; since #27 a list either declares, after `let` or `var`, or assigns.) `p.next` is `(p + 1)` and `p.prev` is `(p - 1)` for a pointer whose type kelvinc sees, including results of Kelvin functions; `.next` of an array is an error that suggests `&a[1]`, and `any^` has no `.next`. On anything else `.next` is a field (a struct, a C type kelvinc cannot see). `p += 1` stays. The comma operator stays for expressions that do not assign. A statement such as `a || f();` is still allowed, and gcc `-Wall` calls its value unused |
| P39 | Details of #27 | `let p:i32^ := &x;` is `int32_t *const p`; `let a:i32[2] = [1, 2];` is `const int32_t a[2]`; `let f(n:i32)` is `void f(const int32_t n)` where defined | A let names a value that cannot change through it: a let struct's fields and a let array's elements cannot be assigned, while a let pointer's target can. kelvinc reports assignments to lets it can see (names, their fields, elements of let arrays), and the C compiler enforces the rest through `const`. A let needs a value except in an `extern` declaration. Let parameters are `const` only in a function's definition (C ignores top-level `const` in prototypes), and an array parameter becomes the `const` pointer C makes of it; a parameter of a C typedef kelvinc cannot see gets no `const`, since the typedef may be an array (`jmp_buf`), and kelvinc alone checks it. Taking `&` of a let gives a `const` pointer, so storing it in a plain pointer is a C warning (discarded qualifiers). `x:i32 = 0;` without `let` or `var`, when the type starts with a type word, is an error with a hint; `again: n = 0;` is a label, as in C. C-style declarations get `var name:type` as their hint |
| P40 | Details of #28 | `for i in 0..<n { }` is `for (int64_t _kv_i_count = 0, _kv_i_end = n; _kv_i_count < _kv_i_end; _kv_i_count++) { const int64_t i = _kv_i_count; ... }` | The bounds are evaluated once, before the loop. A closed range steps with a flag, so `for b:u8 in 250...255` ends instead of wrapping, and `continue` works in both. A bound is parsed down to the shifts (`0..<n - 1` is `0..<(n - 1)`). The loop variable's type is written, or is the upper bound's type if kelvinc sees it, else the lower one's, else `i64`, without `const` or `volatile` (the counter must change); both bounds and a written type must be integers. `for _ in ...` declares no variable, since C warns about an unused one. `in` is a keyword only after `for name`, so C names called `in` still work |
| P41 | Details of #29 | `var p:point;` is `struct point p;`; `sizeof(point)`; `var point:point;` | kelvinc resolves a bare tag name to `struct point` (or `union`/`enum`) wherever a type is read (after `:`, `as`, in compound literals), and writes the long form in the C: no C typedef is emitted, so a variable or function of the same name is fine. A tag declared so far counts, so a struct's members may name it (`next: node^`), as may a C struct that Kelvin declares (`struct timespec;`); a Kelvin tag hides a C typedef of the same name from a header. Where an expression could stand too, in `sizeof(name)` and `(name)...`: a Kelvin variable of that name wins (`sizeof(point)` after `var point:point` is the variable's size), from its own declarator on, as in C (`let p:node^ := malloc(sizeof(p^))`); a Kelvin function of that name wins too, except in `sizeof`, where a function's size is never meant (`node(v)` as a constructor and `sizeof(node)`); and a struct only declared in Kelvin (`struct timezone;`) is left to C there, because headers give such names to functions and variables too (`stat`, `timezone`), so `sizeof(struct timezone)` names the struct. C habits get the usual hints: `p:point = ...` (no `let`/`var`), `point^ p;`, `sizeof point` |
| P42 | Details of #30 | `for c in s { }` is `for (const uint8_t *_kv_c_ptr = s; _kv_c_ptr != 0 && *_kv_c_ptr != 0; _kv_c_ptr++) { const uint8_t c = *_kv_c_ptr; ... }` | `s` is evaluated once into a hidden pointer that only reads, so `s` itself never moves and a let array works. The loop variable is a let copy of the element without its qualifiers, or for a list a let copy of the node pointer, taken (with the next pointer) before the body runs, so the body may change or free the node. The terminator is a zero element: `0`, `'\0'`, `nullptr`, `0.0` or `false`. An array of structs has none, so all of its elements are walked. A pointer whose type kelvinc cannot see (a C function's result, a C typedef) is walked like a pointer, with C's `__auto_type` and `__typeof__`. A list needs a Kelvin struct with a pointer field named `next`; a number, an `any^`, an array of arrays, a flexible array member, or a C struct kelvinc cannot see the fields of is an error. `for x:T in s` reads the elements as what they are and converts each to `T` for `x` only; for a list, `T` must be the node's pointer. An array is reached through a pointer to it, taken once, so a row of a variable length array is evaluated once, although `sizeof` would evaluate it again. An array in a value that a call or `?:` returns (`make().xs`) is an error, since C discards the value before the loop runs; so is a row of an array kelvinc cannot see there. A let array parameter, which C passes as a pointer, has its declared length, evaluated again at the loop, so the length must be made of numbers, lets and C's constants, with no call, no var and no name that a local hides; that the argument is that long is the caller's promise, as in C. A var array parameter may have moved (P32), so it is walked as a pointer. `main`'s `argv`, which C types `char **`, is converted for the hidden pointer. The hidden lines map to the `for`'s line. In the head, a compound literal followed by `..<` or `...`, and an array's or a pointer's before the body (`for x in (i32[3]){1, 2, 3} {`), are compound literals. `0..n` and `0..=n` get the range hint. kelvinc now also sees `&x`'s type, `T^` |
| P43 | Details of #31 | `before:(i64, i64):bool` is `bool (*before)(int64_t, int64_t)`; `let pick():(i64):i64` is `int64_t (*pick(void))(int64_t)` | `(T)` and `()` have no result, and `...` ends a variadic one. The parameters are types without names; an array parameter is printed in C as the pointer C makes of it. The result takes every suffix after it (`(i64):i64^` returns a pointer); a pointer to a function type or an array of functions has no spelling yet, and says so. In the middle of `?:`, a `:` after a function type with no result is the `?:`'s unless a type word follows, as for annotations (`c ? f as (i64) : nullptr`). A function type is a reference (P32): assigned with `:=`, `nullptr` until assigned, compared with `nullptr`, and a let one is a const pointer. A Kelvin function's name, and an anonymous function, designate a function, which is its function value: `&f` is `f`, and `f.size` and `sizeof(f)` are `sizeof(&f)`, a pointer's size. `?:` between functions is a function; a call through a function value is a call whose result kelvinc sees. Function types are read after a declaration's `:` and after `as`, not as an annotation `v:(T):R` (which would clash with `c ? a : (b)`) and not inside `(...)` in an expression. Where kelvinc sees a function, `.cstr`, `.next`, `.prev` and `print`/`println` of it are errors; `&fp` of a variable of a function type is an ordinary data pointer. In a struct's derived text, a function member is its address. A C function with `char` parameters does not match a Kelvin function type with `u8` ones, since `char` and `unsigned char` make incompatible function types (P13 covers pointers only), so it is wrapped: `{ strcmp($0, $1) }`; for the same reason `main`, whose `argv` C types `char **`, is not a `(i32, u8^^):i32` value. C's `T (*f)(...)` gets a hint with the Kelvin spelling, in a body, at the top level, as a member and as a parameter |
| P44 | Details of #32 | `sort(xs, n) { $0 < $1 }` passes `_kv_main_fn` (when written in `main`), declared before the function around it and defined after it as `__attribute__((unused)) static inline bool _kv_main_fn(__attribute__((unused)) const int64_t _kv_arg0, __attribute__((unused)) const int64_t _kv_arg1) { return ((bool)(_kv_arg0 < _kv_arg1)); }` | Each anonymous function is a static inline function named after the top-level declaration it is written in, `_kv_main_fn`, then `_kv_main_fn1` and so on (#33, #38), its prototype too, marked unused (one used only in `sizeof` is never emitted), declared before the top-level declaration around it (a function, a method, one global of a `let`/`var` list, a struct, union or enum, after a `struct s;` its prototypes may name) and defined after it, so each may use the other, and a global's function may use that global and the ones before it. Its parameters are lets, `$k` ones marked unused, and its array parameters are pointers in C. Where a `{` may start one (an argument, an initializer, a value assigned or returned), it is parsed as an expression, so one that writes its parameters may be called or compared there, and one that writes them may stand anywhere a value may. Their types come from the parameter of a Kelvin function, method or function value it is passed to (for a method whose receiver kelvinc cannot see, the only method of that name, a prototype and its definition counting once), a declared variable's type, a struct member's or array element's type in an initializer list (in order and through designators of one member; a string fills an array member and a value of the struct's type fills a struct member, while after brace elision or a longer designator there is none), the type of an assignment's target (also through a cast or a call), or the result type of the function that returns it. An array length in such a type that names a local or a parameter, also inside `sizeof`, a conversion or a compound literal (recorded where the type is written), means something else in the anonymous function: the parameter's outer array becomes a pointer, and such a length anywhere else that reaches C is an error asking for written parameters; lengths of numbers and globals are kept, and `for x in $0` checks them against the names C will see. Without a type in sight it writes its parameters, or has none (`atexit() { ... }`); in a declaration without a type, `{` is an initializer list unless it writes them (`{ () in ... }`). Where a list is taken for a value (a C function's argument, a struct parameter, an assignment, `println`), kelvinc asks for a compound literal. A written signature without `:R` takes the result from the context (checked as above), or has none; an inferred type drops the outer array lengths that name its parameters, and another such length is an error saying so. `$k` and `$[k]` are the innermost anonymous function's parameter `k`, also when they are written; `k` is decimal without leading zeros, messages spell it as written, and `$` is an error in the written parameters themselves. A body that is one expression statement is the result (#35 parses every body as statements); with a result it may not be an assignment or a call kelvinc sees has no value (P46), and without one it must have an effect: a call, an assignment, or a comma or `?:` of those (`{x: 1}`, a label before `1` as a body, is therefore still a list where C's argument is meant). Returning text in the function's own buffer (`.hex`, `.cstr` of anything but a string kelvinc sees), also through `as`, `?:`, the comma, `+`/`-` or `&x[i]`, and in a `return` statement, is an error. It encloses nothing: a local, a parameter (also a static local or `self`) of the function around it is an error, in its body and in its written types; globals, functions and C names are fine. A trailing `{ }` follows the `)` of a call or method call; at the top level of a statement it starts on the line of that `)` (on the next line, `{` starts a block, and `$0` there says so), while inside brackets lines do not matter; like every statement since #35, one ending with it needs no `;` at the end of a line or before a `}`. In the head of `if`, `while` or `for`, the `{` starts the body; inside parentheses (a converter's included), an initializer list, or `do ... while`, it is an argument. Passing one where kelvinc sees a parameter that is not a function, or beyond the last parameter of a function that is not variadic, is an error; where the parameter is a C typedef, the hint asks whether an argument is missing. It is recognized by `in` after the parameters and result, or by the shapes `(a:T)`, `(var a:T)` and `()` when nothing can go on with an expression after them, so `{ (n:i64) * 2, 3 }` is a list. Names starting with `_kv_` are kelvinc's own and `kv_` ones its runtime's (#38), so Kelvin cannot declare either: variables, parameters, members, functions, methods, enumerators, tags, loop variables and labels |
| P45 | Details of #34 | `var w:k.type = 4;` for `let k = 3` is `int64_t w = 4;`; `var e:errno.type;` is `__typeof__(errno) e;`; `var b:a.type;` for a variable length `a` is `__typeof__(a) b;`; `k.typename` is `"i64"`, `abs(-1).typename` is `_Generic((abs(-1)), ..., int: "i32", ...)` | `v` in `v.type` is a name or `$k`, then `.member`, `^` and `[i]` steps, and the last `.type` in such a chain is the type; `^`, `[n]` and qualifiers after it make a new type of it (`w.type^`), and a `const` before it is on an array's elements, as in C. Calls are not part of it. It is read wherever a type is read: after a declaration's `:`, `as` and an annotation's `:`, in `sizeof(...)`, compound literals (also in a `for` head, for an array or a pointer), function types, a written signature's result and `for x:T`. Where an expression could stand too, in `sizeof(x.type)` and `(x.type)`, it is a field when `x` has one, is a C struct, or has a type kelvinc cannot see; after a qualifier, `:` and `as`, and before a compound literal's `{`, it is always the type. The type is the one kelvinc sees (a copy), so a `let`'s own `const` is not part of it, while a `const` written in the type is. It is `__typeof__(v)` instead where kelvinc cannot see it, where it holds an expression C would evaluate again (a length that is not a number, an earlier `__typeof__`), and for a parameter whose declared type kelvinc cannot see (C adjusts an array, as `jmp_buf`, to a pointer); that keeps `v`'s own length and also a `let`'s `const`, and kelvinc keeps the type it saw for its own checks. A function designator's fallback is `__typeof__(&f)`, a function value; a C function kelvinc cannot see is C's function type, whose pointer is `f.type^`. A `for` counter of such a type is `__typeof__((void)0, (v))`, without qualifiers. A result type that names a parameter through `__typeof__` is an error (C writes the result before the parameters). `point.type` of a tag with a body, and `i64.type` of a built-in type, ask for the type itself; a C typedef name is left to C. Inside an anonymous function, `.type` of a local of the function around it is the usual error. A pointer to a function type or an array of functions made with `.type` is the P43 error. In an expression, `.type` is a field where there may be one and otherwise an error, also in parentheses. `.typename` is a string literal where kelvinc sees the type and it holds no `__typeof__` (Kelvin tags by their bare names, a function type under `^` or `[n]` in parentheses, C structs as `struct tm`, escaped for C); otherwise `kv_typename(v)`, a `_Generic` over C's built-in types (C's `long` by `__SIZEOF_LONG__`, `char` as `u8`) and the pointers to characters and `void`, with `"?"` for anything else: arrays decay, enums are their integer type, and bit-fields may differ between clang and gcc. A literal is C's (`42` is `i32`, as `42.size` is 4), `nullptr` is `any^`, and a `?:` between two values of one type is that type. `.typename` is a property also of a C struct and of what kelvinc cannot see, since C++ reserves the word; a Kelvin struct's field of that name wins. A variable used only for its `.type` or `.typename` is unused as far as C sees (`-Wunused-variable` under `-Wall`). The prelude does not include `<limits.h>`, whose names stay the user's |
| P46 | Details of #35 | `let t:i64 = price\n    * count` is one statement; `f(x)\n(p as i64^)^ = 1` is two; `let square(x:i64):i64 { x * x }` returns `x * x` | A statement, a declaration, a struct member, a struct, union or enum, and a prototype (`let f(a:i32):i32` with no body, also of a method) end with `;`, or with a new line, a `}` or the end of the file after them; otherwise `;` is required between them, except after a statement that ends with a block (`if c { a = 1 } b = 2`), whose `}` ends it, as in C. After the head of a function, a method, `if`, `while`, `for`, `else`, `do` or `switch`, a `{` on the next line is the body. Lines go on wherever the expression cannot end (after an operator, a `,` or an open bracket), and before an operator, `.`, `[`, `^`, `?`, `:` or `as`; a `-` or `&` at the start of a line is therefore a binary operator, while a `*` there touching what is then assigned (`*p = 1`) is C's `*p`, an error. At the top level of a statement, a `(` on a new line starts the next statement rather than calling what went before, and a `{` there starts a block: a trailing `{ }` starts on the line of the call's `)` (a block there that writes an anonymous function's parameters, or that follows a call lacking its function argument, is an error saying so), `(n)` or `sizeof(T)` before it is no compound literal (`(T)` before it is an error saying so), and `(x)` before a name on the next line is no C cast; inside brackets lines do not matter. `break`, `continue` and `goto L` end at the end of their line. So does `return` in a function with no result, where a statement after it in the same block is an error, as it could never run, unless it is `case`, `default`, a label or a block holding one, the `return` is the body of `for` or a label, or it is C's `return;`; in a function with a result, `return` at the end of a line takes the expression on the next line, as in Swift. `_Pragma("...")` is a statement also at the end of a line. A function, method or anonymous function with a result whose body is one expression statement returns it. An assignment there is an error, and so is a call kelvinc sees has no value (`print`, `println`, a Kelvin function, method or function value with no result, `_Pragma`, `asm`); `main` keeps C's rule that its end returns 0, so its one expression is a statement (`let main():i32 { 42 }` is an error asking for `return`). A body that ends, on any path (both branches of `if`/`else`, a block, a label, a switch's last statement, or one with no effect before a case), in an expression with no effect, or outside `main` in a call kelvinc sees has a result, is an error asking for `return`, and text in the function's own buffer (`x.hex`) is one in a `return` too. Bodies are parsed as statements, so an anonymous function's body is one expression by the same rule. A statement that starts with `n:T` is an annotation, not a label, when an operator, `as` or `?` follows the type, or when it is the expression a body returns (`let widen(n:i32):i64 { n:i64 }`); with a C typedef `T`, only in that expression and when kelvinc sees `n`; C habits keep their hints at the end of a line and before a `}`: `count:i32`, `size_t n` and `FILE *fp`. `;` stays valid everywhere |
| P47 | Details of #36 | `i32("755", 8)` is `((int32_t)kv_text_int(("755"), (8), INT32_MIN, INT32_MAX))`; `i64(f())` of a C function is `({ __auto_type _kv_self0 = ((void)0, (f())); KV_TEXT(int64_t, _kv_self0, kv_text_int(KV_TEXT_PTR(_kv_self0), 10, INT64_MIN, INT64_MAX)); })` | The runtime's `kv_text_int`, `kv_text_uint`, `kv_text_i128`, `kv_text_u128`, `kv_text_f64` and `kv_text_f32` read the text after leading spaces and one sign (a second sign or a space there is no number), skipping `0o` and `0b` in base 8 and 2 as `strtoull` skips `0x` in base 16; i128 and u128 are read digit by digit the same way. No number, a NULL text or a base outside 2 to 36 at run time (the base is taken as a 64-bit value) is 0. For integers, a clamped value sets `errno` to `ERANGE` and leaves it alone otherwise; an unsigned type's lowest is 0, so `u8("-1")` is 0. Floats are `strtod`/`strtof` itself: infinities out of range, `ERANGE` also on underflow, and the C locale's decimal point. Text is a string literal, a pointer to or array of `u8` or `i8` that is not volatile, a text property (`.dec`, `.hex`, `.oct`, `.bin`, `.cstr`, `.typename`) or a `?:` of those (whose arms become `const void *`). A number kelvinc sees (a literal, `sizeof`, arithmetic, a prefix operator, a comparison) converts as before; anything else it cannot see as text or a number, including a pointer to a C typedef such as `xmlChar^`, goes through `KV_TEXT`, whose `_Generic` reads `char *`, `signed char *` and `unsigned char *` (const or not) and converts anything else. Inside a function, the value is first put in a temporary, so that it is evaluated and written once and nesting stays linear; at file scope `KV_TEXT` is used directly and stays a constant expression for numbers, so `let big = u64(UINT32_MAX)` still initializes a global. With a base, the value must be text: after a number kelvinc sees it is an error, and where only `_Generic` sees it, a C type error names `kv_base_needs_text`. A written base outside 2 to 36, in any radix or negated, or a float, is an error. `v.T` is `T(v)` for every converter type, numbers included (`300.u8` is 44), except that a field of that name wins: a Kelvin struct's, a C struct's, and, as for `.size`, one of whatever kelvinc cannot see is not a struct (`o.via.i64`); a Kelvin struct or union without one is an error, and so is `.i64(...)` where it is not a field. `bool` reads no text: `bool(p)` of a pointer is C's test for `nullptr`, and of a string literal or a text property, which is never `nullptr`, an error. A number read from text is no text in the function's buffer, so `{ i64(x.hex, 16) }` may be returned |
| P48 | Details of #37 | `p.addr` is `((uintptr_t)(p))`; `p.hex` is `kv_hex_addr((uintptr_t)(p), _kv_p_text)`; `getenv("X").hex` is `_Generic((...), KV_PROPERTY_hex default: KV_HEX_DEFAULT((...)))(..., _kv_text0)` | Pointers are what kelvinc sees as `T^` (also `any^` and `cstr`) or a function type, a Kelvin function's or an anonymous function's name, a string literal, `nullptr`, `&x`, a text property (`.cstr`, `.dec`, `.hex`, `.oct`, `.bin`, `.typename`, all `u8^`), a pointer plus or minus a number, and a `?:` or comma of pointers. `.hex` writes into the same 36-byte buffer as an integer's `.hex`, so returning it is the usual error, while `.addr` is a number that may be returned. Where kelvinc cannot see the receiver, `.addr` is a field, as `.size` is (#21: a field wins when unsure; C structs often have an `addr`), so a pointer only C sees writes `x as uintptr_t`; `.hex` stays a property: `KV_HEX_DEFAULT` picks `kv_hex_ptr` for any pointer by GCC's and clang's `__builtin_classify_type`, and `kv_no_such_property` for anything else, so `.hex` of a C struct is still a C error naming it. `__builtin_classify_type` sees an array as a pointer, so an array only C sees (a C struct's `char` array field) gives its first element's address, as `.typename` and `.cstr` of one do. A function pointer only `_Generic` sees is passed as a `const volatile void *`, which `-pedantic` warns about; a value kelvinc sees is converted to `uintptr_t` first. `.addr` is an unsigned integer for other properties and converters (`p.addr.hex`, `p.addr.u64`) and needs a written type in a declaration (`let a:uintptr_t = p.addr`), as `.size` does; methods on `u64` do not reach it where `uintptr_t` is `unsigned long`, as with `.size`. A Kelvin struct without an `addr` field, a number or a bool is an error for `.addr`; `.hex` of a struct or a bool keeps its error |
| P49 | Details of #38 | `n.hex` writes into `_kv_n_text`, `for i in 0..<n` counts with `_kv_i_count` and `_kv_i_end` (and a closed range `0...n` steps with `_kv_i_go`), and `sort(xs, n) { $0 < $1 }` in `main` passes `_kv_main_fn` | A hidden name is `_kv_`, its source, and its kind. The source is a variable's or a parameter's name (`$0` is `arg0`), a member chain joined with `_` (`p^.x` is `p_x`), what is indexed or stepped, a loop's variable, or for an anonymous function, the top-level declaration it is written in (a method `point.area` is `point_area`, a global or a struct, union or enum its name). The kinds are `text` (a property's buffer), `self` (a temporary for a method's receiver, a condition, or a converter's value), `count`, `end` and `go` (a range), `ptr`, `end` and `array` (`for x in`), `fn` (an anonymous function), `template`, `build` and `value` (a template literal, #39), and `arg0`, `arg1`, ... (an anonymous function's `$k` parameters, by their number). Each stem counts on its own within a C function (and anonymous functions in the file), so a repeat is numbered 1, 2, ... and nothing is ever shadowed; with no source (`(a + b).hex`, `for _ in`), the kind is numbered from 0. Only names a construct uses are taken. A struct's derived text is `_kv_point_cstr(self, _kv_buf)`, writing with `_kv_p`, with its size `_kv_point_cstr_size`, and its array loops count with `_kv_i0`, `_kv_i1` by depth. Methods keep the names Kelvin gave them (`point__area`, P26), since they are the program's, and the runtime's functions and macros keep `kv_` and `KV_`. Kelvin cannot declare names starting with `_kv_`, `kv_` or `KV_` |
| P50 | Details of #39 | `` `n = ${n}, ${name}` `` in a block is `({ KV_TEMPLATE_BUILD(_kv_build0, _kv_template0); KV_TEMPLATE_PART(_kv_build0, "n = "); __auto_type _kv_value0 = ((void)0, (n)); KV_TEMPLATE_VALUE(_kv_build0, 20, _kv_value0); KV_TEMPLATE_PART(_kv_build0, ", "); __auto_type _kv_value1 = ((void)0, (name)); KV_TEMPLATE_VALUE(_kv_build0, KV_TEMPLATE_STR, _kv_value1); KV_TEMPLATE_TAKE(_kv_template0, _kv_build0); })`, with `char _kv_template0[sizeof "n = " ", " + 20 + KV_TEMPLATE_STR];` at the top of the block (P56) | The lexer reads a template's text as C string literals, between which the tokens of each `${...}` come; a `}` closes the `${` when the braces opened inside it are closed, so a value may hold blocks, anonymous functions and other templates. A template without `${...}` is a string literal token (described as a template literal in messages), which also joins adjacent string literals. Escapes are C's, plus `` \` ``, `\$`, `\{`, `\}` and a backslash before a new line, which joins the lines; a new line, CRLF included, is `\n`, a lone CR `\r`, and `?` is written `\?`, so no C trigraph forms. A token after a multi-line template counts its line from the template's last line (#35). Each evaluation builds its text in a buffer of its own, appending the literal parts and each value, evaluated once into a temporary in order, through `KV_TEMPLATE_VALUE` (a `_Generic` over the types `print` takes, sharing `print`'s text functions), and then copies it into the template's storage, so a value may read the earlier text. The storage, at the top of the enclosing block, has no heap and no initializer, so a `switch` or `goto` may jump past it, and lives until the block ends (#44, P56). The text is a `char *`, as a string literal is, so `?:` may choose between templates and literals; for converters and properties it is a `u8^` (`i64(`${n}`)`, `` `...`.size `` is a pointer's size). A Kelvin struct or union is shown by its derived `.cstr`; a function value or name is an error; a C struct is a C type error. Its text is the block's, so returning it, implicitly, with `return` or through `.cstr`, is an error, as is assigning it to a variable of an outer block or a global (but not to the function's own parameters, which end with its body); a global or `static` cannot be initialized with one that has `${...}`. In an anonymous function it uses that function's block, and it may not use the enclosing function's locals |
| P51 | Details of #40 | `#import "lib/shapes.k"` is followed by that file's declarations; `#import <complex.k>` reads `complex.k` from `./modules` or Kelvin's `modules/` (#46) | The lexer takes `#import` of a name ending in `.k`, without `as C`, as a Kelvin file; `as C` or other text after one is an error. Before parsing, kelvinc puts each such file's tokens after its import, and the imports in them in turn, so that its declarations are compiled as if written there: they are the program's, declared before what follows, as in C. A file is brought in once per program, by its device and inode, the main file included, so another import of it, also through another file, another path, a symlink or a hard link, adds nothing; a CRLF may end its line. The import stays, and the end of each imported file is marked, so a declaration ends where a file begins or ends, whatever the numbers of their lines; an unfinished declaration at the end of an imported file is an error there; and `#import` inside a function, a struct or a block is an error at the import, of a C header too. `"x.k"` is relative to the importing file (an absolute path as it is), `<x.k>` is `./modules/x.k`, else `x.k` in Kelvin's `modules/` (P58); a directory is no Kelvin file. A file it cannot find is an error at the import. A `"header.h"` that an imported file imports as C is the one next to that file, as C's `#include` would find it, written with the full path of that file's directory (a symlinked header keeping its own directory; a path that holds a `"` is left as written). kelvinc's messages and the C compiler's (through `#line`) name the imported file and its lines. Imported functions are named by their parameter types in C (P52), except those declared but never defined (C's own); structs and globals keep their names |
| P52 | Details of #41 | `sin(z)` of a `complex64` is `sin__complex64(z)` and `sin(0.5)` is C's `sin(0.5)`; with `twice(n:i64)` and `twice(x:f64)`, `twice(atan2(y, x))` is `({ __auto_type _kv_self0 = ((void)0, (atan2(y, x))); __builtin_choose_expr(KV_NUMBER(_kv_self0) == KV_N_I64, twice__i64, __builtin_choose_expr(KV_NUMBER(_kv_self0) == KV_N_F64, twice__f64, kv_no_such_overload))(_kv_self0); })` | Overloads differ in their parameter types as Kelvin writes them, without a parameter's own qualifiers, an array parameter being a pointer; one with the same types is the same function, a prototype or a definition, with the same result. `main` has one form, and methods dispatch by receiver (P26). An argument has the type of its value, where C's `const` of a `let` is kept (`&v` and an array that is a `let` point to `const`); a literal has its own, also negated (#24: `4` is an `i64`, `-0.5` an `f64`), and a character is a `u8`; a comparison, `&&`, `\|\|`, `!` and `true` are `bool`; an enumerator is its enum; `sizeof` is a `size_t`; and `+`, `-`, `*` and the other arithmetic on numbers kelvinc sees has the type C's promotions and conversions give, a literal there having C's type (an `int` where it fits, so `small * 4` is an `i32`). It fits a parameter exactly (the same type, a function type's array parameters being pointers), by conversion (a number to any number, also to a C typedef, which kelvinc cannot tell from one; a pointer to the same one whose target gains qualifiers, never loses them, the levels below it the same, or to or from `any^`; `nullptr` to a pointer or a function; text to `u8^`, `i8^` or `any^`; an overloaded function's name to a function type one of its overloads has, exactly), or not at all. The overload that all arguments fit exactly is chosen, and two such are a tie. Otherwise the one that fits at least as well as every other on each argument kelvinc sees, and better on one, where both have the same parameter type at each argument only C sees, is chosen; a tie is an error asking for a conversion (an `i32` fits `i64` and `f64` alike, Q14). With none, C's own function of the name is called. A program's one function of a name, also an imported one, is called as C calls it, except where it takes a struct and is given a number, which is for C's own function of the name (`sin(z.real)` inside `sin(z:complex64)`), or a value only C sees, which goes to C's function where the program calls it, and to the function itself otherwise. Where kelvinc cannot see an argument's type (a C function's result, a C struct's field, a macro), C chooses among the overloads left, over each such argument; inside a function the arguments go into temporaries first, a literal cast to its Kelvin type. Structs, pointers and C typedefs are matched by their C type, each in a `_Generic` of its own, so that two types that are the same in C (`size_t` and `uintptr_t`) cannot clash; numbers by `KV_NUMBER`, their Kelvin type, so that C's `long` and `long long` are both `i64` where they have 64 bits, and `char` is `u8`; and then an enum by its C type, which C cannot tell from its integer type. A number of another type goes to the one overload that takes a number there, which C converts it to, and a pointer to the one that takes a pointer, so `char *` and `void *` reach a `u8^` or `any^` parameter; where none does, to the one whose `...` covers that argument; else to C's own function of the name where the program calls it (then every such argument is checked, also where all the overloads left take one type there); and otherwise, as where several do, to `kv_no_such_overload`, a C type error that names it. So that C's function takes the numbers that only C sees whether or not the program calls it, a library declares it, as modules/complex.k declares `let tanh(x:f64):f64`; a function declared and never defined is C's, keeps its name, and is one of the overloads. One overload left with nothing else to choose is called, and C converts or reports. Such a call's result has a type kelvinc sees when all the overloads it may reach have that result and no number may go to C's own function. A function is named by its parameter types in C (`twice__i64`, `twice__const_u8p`: `^` is `p`, `[` is `a`, a space `_`, a function type `F` its parameters `E` its result, `...` is `__va`, and no parameters `__void`) when it has overloads, is imported, or shares its name with a C function the program calls; otherwise it keeps its name, and so do `main` and a function the program declares but never defines. Two functions or methods that would get the same C name are an error naming the other's place. A function's name as a value is the overload of the function type wanted: a typed `let` or `var`, the target of `:=`, a parameter, or a function's result, also of a body that is one expression; where no Kelvin overload has that type, it is C's own function of the name (`let g:(f64):f64 := sqrt` beside `sqrt(v:vec)`); an overloaded name elsewhere is an error. An anonymous function passed to an overloaded function takes its parameter types from the overloads where they all agree, and writes them otherwise. A call sees the overloads declared before it, as C does. `(f)(x)` keeps its parentheses, which call the function rather than a macro of its name. Limits remain: a C function-like macro such as `isnan` cannot take a value only C sees beside an overload of its name; gcc gives a C header's bit-field no type `_Generic` knows; and a Kelvin function of a C function's name that the program neither calls as C's nor declares keeps its name, which conflicts with the C header's, as it would in C |
| P53 | Details of #42 | `let +(a:complex64, b:complex64):complex64 { ... }` is `__attribute__((warn_unused_result)) struct complex64 _kv_add_op__complex64__complex64(const struct complex64 a, const struct complex64 b)`, and `a + b` calls it | `+ - * / % == != < <= > >=` take two values and `-` also one, none variadic; at least one is a Kelvin struct or union (also one declared without its body yet), and the operator has a result. Defining another (`<<`, `!`, `+=`) is an error. A definition is a top-level `let` with the operator's head, `let op(a:T, ...):R` (#45; before, a definition started on a new line, told by its head, and ended a value or a type before it). Operators overload by both operands as functions do (P52), and keep C's precedence. `a op b` with an operand that is a Kelvin struct, also one that a call C chooses gives, calls the operator chosen, and is an error showing how to define one where none fits, with a literal's type; numbers keep C's operators. Where the other operand's type only C sees, `_Generic` chooses as for functions, and what no operator takes goes to `kv_no_such_operator`, a C type error. In C an operator is `_kv_`, a word (`add`, `sub`, `mul`, `div`, `mod`, `eq`, `ne`, `lt`, `le`, `gt`, `ge`, and `neg` for `-a`), `_op` and its types, and its result must be used, so C warns about `m == a;` as a statement (gcc not where C chooses the operator). `x op= y` with an operator a struct defines is `x = x op y`, which evaluates `x` twice, so `x` may not hold a call |
| P54 | Details of #43 | `exp(z)` is `exp__complex64(z)`, `z * w` is `_kv_mul_op__complex64__complex64(z, w)`, and `exp(z.real) * (complex64){cos(z.imag), sin(z.imag)}` in `exp` is `_kv_mul_op__f64__complex64(exp(z.real), (struct complex64){cos(z.imag), sin(z.imag)})`, as `exp` of an `f64` is C's, which the file declares | `struct complex64 { real: f64; imag: f64 }`, and `complex32` with `f32` parts, named by the size of a part. `complex64(re, im)`, `complex64(re)` and `complex64(z)` of a `complex32` make one, as `complex32(...)` does the other way, and so does `polar(r, theta)` (`f64` gives `complex64`, `f32` gives `complex32`); `(complex64){re, im}` works, as for any struct. `+ - * /` take two complex numbers of one kind, or one and a real number of its parts' type, either way round (a whole number converts), plus `-z`, `==` and `!=`; division is Smith's algorithm, in Baudin and Smith's form where the ratio of the divisor's parts is subnormal, scaled where its finite parts pass 1e300; by 0 it is infinite and by an infinity 0, as C's is, and a numerator part near `DBL_MAX` overflows as C's does. Mixing `complex32` and `complex64` is an error: convert one. The functions are `conj`, `abs` (by `hypot`), `arg` (by `atan2`, from -π to π), `norm` (`abs(z)` squared), `exp`, `log`, `sqrt`, `pow` (a complex or real power of a complex or real number), `sin`, `cos`, `tan`, `sinh`, `cosh`, `tanh` and their inverses. The inverses take their principal values, with C99's branch cuts and its signs of zero on them; the circular functions are the hyperbolic ones at `iz`, as C99 defines them. `asin`, `acos` and `acosh` are Kahan's formulas, and beyond 1e300 the asymptotic `log 2z`, `acos` taking its real part from the angle; `atanh` uses `log1p`, and its limits where `z` is far or `y²` would underflow; `log` uses `log1p` where a part is near ±1 and scales a huge or tiny `z`; `tanh` is Kahan's algorithm; `sqrt` scales the sum that gives its larger part where `z` is huge or tiny, forms the other part from `z`, and gives C99's values for an infinite part, also beside a NaN; `exp`, `sinh` and `cosh` split `e^x` where it alone would overflow; `pow(0, w)` is 1 for `w` 0, 0 for a positive real part, infinite for a negative real `w`, and NaN for a NaN. The file declares C's functions of the names it overloads (`let tanh(x:f64):f64`, P52), so that `tanh(atof(s))` is C's `tanh`. So results are accurate near 0, ±1 and ±i, and no step of the elementary functions overflows or loses bits where the result does not, up to parts of `DBL_MAX`; they agree with macOS's libm `<complex.h>` to 1e-13 on the cases tested, which include subnormal, infinite and huge parts. C99's Annex G special values for other infinities and NaNs are not attempted; where Annex G gives `catanh(1 + 0i)` as `inf + 0i`, macOS's libm gives `inf + i pi/4`, and this file follows Annex G. `complex32` computes through `complex64`. A complex number's text is its derived `.cstr`, as `{real: 1, imag: 2}`, also in a template; `print` takes no struct |
| P55 | kelvinc compiles with `-ffp-contract=off` | `a * b + c` is rounded twice | clang (Apple's on arm64 and others) fuses `a * b + c` into one `fma()` by default, while gcc in ISO C mode does not, so the same Kelvin program gave different floating-point results under the two, and in modules/complex.k `z * w` differed from `w * z` and `z * conj(z)` had an imaginary part. kelvinc now asks both for C's unfused arithmetic. `KELVIN_CFLAGS=-ffp-contract=on` brings clang's fusion back (`fast` only with `-O`). With `-O`, clang on macOS may also compute `sin` and `cos` of one value in one call, whose result can differ from theirs in the last bit |
| P56 | Details of #44 | `` `<${s}>` `` with a 399-byte `s` is 258 bytes, ending in `...>`; its storage is `char _kv_template0[sizeof "<" ">" + KV_TEMPLATE_STR];` | A template's storage is a `char` array at the top of the innermost block that holds it, declared with the text properties' buffers (P34, P35) and marked unused (a macro may drop the template, as `assert` does under `NDEBUG`), without an initializer or a cleanup attribute, so a `switch` or `goto` may jump past it and nothing moves to the function's top: text made in a switch's body lives until that body ends. A template with `${...}` in a type, as in an anonymous function's written parameters, is an error. Its size is a C constant: the literal parts with one NUL (`sizeof "a" "b"`), plus each value's longest text as `print` shows it, which kelvinc reckons from the type it sees: `i8` 4, `u8` 3, `i16` 6, `u16` 5, `i32` 11, `u32` 10, `i64` and `u64` 20, `i128` and an enum 40 (gcc gives an enum beyond 64 bits an `__int128` type), `u128` 39, `f32` 15, `f64` 24, `bool` 5, an address `sizeof(void *) * 2 + 2`, a struct's text its `_kv_X_cstr_size - 1`, `.dec`, `.hex`, `.oct` and `.bin` 40, 35, 46 and 131, `.size` and `.addr` 20, a string literal its length, a nested template its own storage's, the longer arm of a `?:` between texts (through a `union`, so that each arm is written once and a chain of `?:` stays as long as it is written), and arithmetic and `?:` as the widest kind of their operands, as C promotes them (any integer 20, `i128` and an enum 40, floats 24). For numbers, C checks the bound against the type it sees (`KV_TEMPLATE_BOUND` in a `_Static_assert`), so a wrong one is a compile error, never an overflow; a text's room comes from the same constants as its buffer, and no writer goes past its room. A byte array (`u8[16]`, also `u8[N]` of a length C computes) is read up to a NUL or its end, never past it, as `sizeof` of the array tells; one whose length is a number of at most `KV_TEMPLATE_STR` has room for all of it, and a longer one, or one whose length kelvinc cannot read, is cut as a string is. Inside a `?:`, C makes an array a pointer, which is read as a string. A string kelvinc cannot see the length of (`u8^`, `cstr`, C's `char *`, a template's text in a variable, `.cstr` of a string, `.typename`) and any value only C sees get `KV_TEMPLATE_STR` bytes, 256 unless a program sets `-DKV_TEMPLATE_STR=n` (at least 64, else an `#error`); a longer string shows its first `n - 3` bytes and `...`, read no further than `n + 1` bytes, and cut at a byte, as in P35. Each evaluation builds its text in a buffer of its own, the size of the storage, inside the statement expression (`KV_TEMPLATE_BUILD`), writing the parts and values in turn, and then copies it into the storage (`KV_TEMPLATE_TAKE`); so ``s := `${s}b` `` stops growing at `KV_TEMPLATE_STR + 1` bytes, each value that reads the earlier text being cut at `KV_TEMPLATE_STR`; every evaluation of one template returns the same storage, and a pointer kept from an earlier one shows the newest text. The stack holds the storage and, while it is built, its copy, and a struct's text is in its `.cstr` buffer too. The writers of libkelvin take the place to write at and a limit, and return the end: `kv_template_str(p, max, s)`, `kv_template_bytes`, `kv_template_copy` and the rest; `kv_template`, `kv_template_take` and `kv_template_free` are gone, and with them libkelvin's only `malloc`, `realloc`, `free` and out-of-memory abort |
| P57 | Details of #45 | `let main():i32 { ... }`, `static let half(n:i64):i64`, `let point.norm():f64` and `let +(a:vec, b:vec):vec`; `main():i32 {` is an error, "a function is declared with let: write 'let main(...)'" | At the top level, `let`, after `static` or `extern` if any, followed by a name and `(`, by a type, `.`, a name and `(`, or by an operator and `(`, declares a function, a method or an operator, a prototype too. Without `let` each is an error that shows where it goes, and so is `var` before one, which also shows `var f:(T):R := g` for a variable holding a function; a name and `(` that no parameters follow (`)`, `...`, `var` or `name:`), as a call or `_Pragma(...)`, is instead a statement out of place, an error that says so. Inside a function, `let f(` or `var f(` before parameters is an error that shows `let f:(T):R := { (a:T):R in ... }` (#32), and a C function-pointer declaration after `let` or `var` gets #31's message, as at the top level. The C is as before: a C function cannot change anyway, so `let` adds no `const`. Since a definition now starts with a keyword, the rule that an operator's head on a new line ended a value or a type before it (#42) is gone; a line that starts with an operator goes on with the line before, as everywhere (#35). Messages that show a function's head show `let` |
| P58 | Details of #46 | `#import <complex.k>` is `./modules/complex.k` if there is one, else `complex.k` in Kelvin's `modules/`; with `./modules/greet.h` and `./modules/libgreet.a`, `#import <greet.h> as C` and `KELVIN_CFLAGS=-lgreet` find them | Kelvin's own `modules/` is the first of `$KELVIN_HOME`, kelvinc's directory (the source tree) and its parent with `modules/kelvin_prelude.h`, or with `lib/kelvin/modules/kelvin_prelude.h` as `make install` lays it out; `libkelvin.a` must be beside it, else an error says to run `make`. `./modules` is relative to the directory kelvinc runs in, not to the program's file. kelvinc gives C `-I./modules -L./modules` where it is a directory other than Kelvin's own, after the `-I` of the `.k` file's directory, and `-isystem` and `-L` of Kelvin's, so C looks for a `<x.h>` next to the `.k` file, then in `./modules`, then in Kelvin's `modules/`, and the prelude's macros raise no warnings. A `./modules` that holds a `kelvin_prelude.h` of its own, another Kelvin's, is `-idirafter` instead, so that the prelude C reads is the one beside the `libkelvin.a` linked. kelvinc links only libkelvin, and `KELVIN_CFLAGS` now come after the program's C file, so that a `-lfoo` there links what the program uses, as GNU ld needs. `make` builds `modules/libkelvin.a` and `modules/libkelvin.so` or `.dylib`; the runtime's sources stay in `runtime/`, compiled with `-Imodules`. `make install` copies `kelvinc` to `$PREFIX/bin`, and the header, the libraries and `modules/*.k` to `$PREFIX/lib/kelvin/modules`, no longer to `$PREFIX/include` and `$PREFIX/lib`; C that uses libkelvin from there takes that directory's `-I` and `-L`. `tests/run.sh` builds a copy of `tests/project/` from inside it, so that its `modules/` is `./modules`, with `libanswer.a` built there from `answer.c` and linked through `KELVIN_CFLAGS=-lanswer`; and it builds `examples/complex.k` from a directory without `./modules`, with Kelvin's `modules/` laid out as `make install` does, by a kelvinc copied to its `bin/` and through `KELVIN_HOME` |
| P59 | Details of #47 | `var z = complex64(0.0, 1.0)` is `struct complex64 z = ...`; `let r := &q` of a let `q:point` is `const struct point *const r`; `let ap := arr` of `arr:i32[3]` is `int32_t *const ap = arr` | A declaration without a type takes the type of its value as overloading sees it (P52), after the rules of #11, #24, #25 and #32: a Kelvin function's or method's result (the overload chosen, or the result all that C may choose have), a variable, a field of a Kelvin struct, `p^`, `a[i]`, `&x` (pointing to `const` where `x` is a let, or a let's field or element), a compound literal, a text property (`.cstr`, `.dec`, `.hex`, `.oct`, `.bin`, `.typename` are `u8^`), a template's text (`u8^`), an enumerator (its enum), a character (`u8`), `sizeof` (`size_t`), a function's name of one overload (its function type), and a `?:` between two values of one type. An array is not copied in C, so its value is the pointer C makes of it, to `const` for a let. Not inferred, so needing a written type: arithmetic and the other operators (`+ - * / % & \| ~ << >>`, unary `- + ~`, `?:` between numbers of two types), whose type is C's promotion of the operands; a string literal (an array or a pointer, Q10); `.size` and `.addr`; and any value only C sees (a C function's result, a C struct's field, a macro, a name from a header). The `=` and `:=` check (#19) then applies to the inferred type: `var t = &x` is an error asking for `:=`. The message names what is and is not inferred |
| P60 | Details of #48 | `let a:i32[3] = [1, 2, 3]`, `var g:bag = {1, [7, 8, 9], {5, 6}}`, `let sp:i64[4] = [[2] = 9, [0] = 1]`, `(i32[])[10, 20, 30]`, `for x in (i32[])[5, 6, 7] { }`; `let m = [[1, 2], [3, 4]]` is `i64[2][2]` | An initializer list written `[...]` is an array's, `{...}` a struct's or union's, in a declaration, a member of a list, or a compound literal; both are C's `{ }`. Where kelvinc sees the type, the wrong brackets are an error with a hint: `{...}` for an array, `[...]` for a struct, a union, a scalar or a pointer. Where only C sees it (a C struct's member, a C typedef), either is accepted. Inside a list, an item that starts with `[` is a nested array unless `=` follows the group, which makes it a designator, `[2] = 5`; `.name =` designators are as in C. A compound literal of an array is `(T[N])[...]` or `(T[])[...]`, told from `(p)[i]` by the parentheses holding a type that ends with `]` (a typedef name alone, `(vec3)[...]`, is read as an index), or a `v.type` kelvinc sees as an array; `sizeof` takes it. `T[]` with `[...]` of no designators is `T[N]` to kelvinc, N the items' count, so that `.size`, `for x in` and templates know it, in a declaration and in a compound literal; with designators, or a string, C counts as before. An array literal infers its type (#47): `T[N]` where every item infers `T`, a nested list `T[M]`, none designated and none a string; `let q := (i32[])[...]` infers the pointer, as any array value does. In an expression, `[...]` is an error that shows the compound literal |
| P16 | `#import` details | `#import "x.h" as C` | Top level only, at the start of a line. A quoted header is searched next to the `.k` file (kelvinc passes `-I<dir of .k>`), since the generated C lives in a temp directory |
| P17 | `as` binds tighter than every binary operator and looser than prefix operators, and chains left to right | `-x as u8` is `(-x) as u8`; `a * b as i64` is `a * (b as i64)`; `x as i64 as i32` | This is where C's cast sits (and Rust's `as`). To index or dereference the result, parenthesize: `(p as u8^)[0]`, because a `[`…`]` or `^` after the type is read as part of the type |
| P18 | `T(v)` only for built-in types (`i8`…`u128`, `f32`, `f64`, `bool`) | `u8(c)`, but `n as size_t` and `p as u8^` | For a typedef name, `size_t(n)` would look exactly like a function call, and suffixes such as `u8^(p)` read poorly. `as` covers every type |
| P19 | Compound literals `(T){...}` stay, for any type (including typedef names with suffixes or qualifiers) and under `sizeof`; an array's is `(T[])[...]` since #48 | `(struct point){.y = 7}`, `(size_t[])[1, 2]`, `(div_t^){NULL}`, `sizeof (i32[])[1, 2, 3]` | They are not casts, although they share C's syntax. A `(...)` followed by `{` can only be a compound literal, because an expression is never followed by `{`, so its contents are read as a type; `(...)` followed by `[` is one where the parentheses hold a type that ends with `]` (P60). A Kelvin spelling is an open question (Q10) |
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
  type from `list`, as `var n:struct node^ := list` currently spells it?
  Today only literals, `bool`s (#24, #25), annotated values (#8, #11,
  #15) and anonymous functions that write their parameters (#32) are
  inferred.
- ~~**Q13: `(p0 - p1).diff`.**~~ Set aside by the user (Dialogue.md
  entry 59): the difference of two pointers as a `.diff` property, a
  `ptrdiff_t`, is not planned for now.
- **Q14: Which conversion is nearer?** An `i32` fits `twice(n:i64)` and
  `twice(x:f64)` alike, so `twice(n)` is an error asking for a
  conversion, as C++ would have it (P52). Should a number prefer a
  parameter of its own kind, an integer an integer and a float a float?
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
  `p:FILE^`.
- `typedef`
- An array of functions, or a pointer to a function type (#31)
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
| `src/lexer.c` | C's lexical rules, template literals (#39), and `#import` of Kelvin files (#40). Kelvin keywords `as`, `i8`…`u128`, `f32`, `f64`, `bool`, `true`, `false`, `String` (shelved), `any`, `nullptr`, `cstr`, `let`, `var`; `..<` and `...` for ranges; `$`, `$0`, `$1`, ... for anonymous functions; `~=`, no `^=`; a number ends before `.name` (P30) |
| `src/parser.c` | Recursive descent over C's grammar with the changes above, template literals included (#39), plus a table of declared names, their types and which are lets: it checks `=` against `:=` (#19), assignments to lets (#27) and what anonymous functions use (#32), infers types (#25, #28, #32), lists the anonymous functions around each top-level declaration, and chooses among overloaded functions and operators by the types it sees (#41, #42) |
| `src/codegen.c` | Prints C: methods and properties become `_Generic` dispatch, every struct gets a derived `.cstr` and its size, property buffers are declared at the top of their block, and anonymous functions become static functions, declared before their declaration and defined after it; template literals build their text in the statement expression and copy it into storage at the top of their block (#39, #44), and everything kelvinc names itself is `_kv_` (#38); a call whose overload only C can tell is a choice over the arguments kelvinc cannot see, by `_Generic` and `__builtin_choose_expr` (#41, #42); postfix and function types become C declarators, `i32` becomes `int32_t` and `f64` becomes `double`, `p^` becomes `(*p)`, `~` becomes `^` |
| `src/main.c` | Driver: puts imported Kelvin files after their imports, from `./modules` or Kelvin's `modules/` for `<x.k>`, marking where each ends (#40, #46), writes the C, finds the runtime in Kelvin's `modules/`, runs `$CC` with `-I<dir of .k>`, `-I` and `-L` of the `modules/` directories, `-ffp-contract=off` (P55) and `libkelvin.a`, and optionally runs the program |
| `modules/kelvin_prelude.h` | The prelude: `print`/`println` as `_Generic` macros, the dispatch tables for `.cstr`, `.dec`, `.hex`, `.oct` and `.bin`, `kv_typename` for `.typename`, the `KV_TEXT_` macros that read numbers from text (#36), and `KV_HEX_DEFAULT` for `.hex` of pointers (#37), `KV_TEMPLATE_BUILD`, `KV_TEMPLATE_VALUE` and `KV_TEMPLATE_BOUND` for template literals (#39, #44), and `KV_NUMBER`, `KV_POINTER`, `kv_no_such_overload` and `kv_no_such_operator` for choosing overloads in C (#41, #42) |
| `runtime/prelude.c` | `print`/`println`, and the text of template literals, which shows values as `print` does (#39), written into the caller's buffer with nothing allocated (#44), built into `libkelvin.{a,so,dylib}` |
| `runtime/string.c` | The text of values: `.cstr`, `.dec`, `.hex` (also of pointers, #37), `.oct` and `.bin`, and numbers from text (#36) |
| `modules/complex.k` | `complex32` and `complex64`, their operators and elementary functions (#43), for `#import <complex.k>` |
| `modules/libkelvin.*` | Built by `make` from `runtime/` (#46) |
| `tests/run.sh` | `tests/run/*.k` check output and, with `// c:` lines, the C written; `tests/project/*.k` check output, built from inside a copy of `tests/project`, whose `modules/` is `./modules`, with a library built into it, and Kelvin's `modules/` as `make install` lays it out is found next to kelvinc and through `KELVIN_HOME` (#46); `tests/error/*.k` check diagnostics, and the Kelvin files both import are in `lib/` next to them; `tests/c/*.c` use libkelvin from C, linked statically and dynamically |

The driver adds `$KELVIN_CFLAGS` to the C compiler command line, after
the program's C, for libraries (`-lcurl`) and other flags. `--emit-c --no-line` shows the
generated C without `#line` directives.
