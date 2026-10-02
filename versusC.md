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
| `int x = 0;` | `x: i32 = 0;` |
| `long n = 42;` | `n = 42;` (inferred as `i64`) |
| `long *buf = malloc(n);` | `buf := malloc(n):i64^;` (`:=` for references) |
| `p = q;` (pointers) | `p := q;` |
| `double d = 1.5;` | `d = 1.5;` (inferred as `f64`) |
| `unsigned long v = 10UL;` | `v: u64 = 10;` |
| `float f = 1.5f;` | `f: f32 = 1.5;` |
| `1UL << 40` | `1:u64 << 40` |
| `uint16_t u = 0xdead;` | `u = 0xdead:u16;` (inferred as `u16`) |
| `char *s;` | `s: u8^;` or `s: cstr;` |
| `int *a[4];` | `a: i32^[4];` *(provisional)* |
| `int (*p)[4];` | `p: i32[4]^;` *(provisional)* |
| `const char *const s;` | `s: const u8^ const;` |
| `long add(long a, long b) { ... }` | `add(a: i64, b: i64): i64 { ... }` |
| `void f(void);` | `f();` |
| `void *p = NULL;` | `p: any^;` (a reference is `nullptr` until assigned) |
| `(void *)0`, `NULL` | `nullptr` |
| `static int g(void);` | `static g(): i32;` |
| `int main(int argc, char **argv)` | `main(argc: i32, argv: u8^^): i32` |
| `struct p { int x, y; };` | `struct p { x: i32, y: i32; };` |
| `*p` | `p^` |
| `**pp` | `pp^^` |
| `*p++` | `p++^` |
| `p->m` | `p^.m` |
| `a ^ b`, `a ^= b` | `a ~ b`, `a ~= b` |
| `(unsigned char)c` | `u8(c)` or `c as u8` |
| `(int *)malloc(n)` | `malloc(n) as i32^` |
| `(size_t)n` | `n as size_t` |
| `sizeof(long)` | `sizeof(i64)` |
| `#include <stdio.h>` | `#import <stdio.h> as C` |
| `printf("%" PRId64 "\n", n)` | `println(n)` (prelude, no import) |
| `snprintf(buf, sizeof buf, "%lld", n)` | `n.cstr` (`cstr` text on the stack) |
| `sizeof x` | `x.size` |
| `snprintf(buf, sizeof buf, "0x%x", n)`, `n` unsigned | `n.hex` (`u8^` text on the stack; a signed `n` gives `+0x2a` or `-0x2a`) |
| `double area(struct shape s)` | `shape.area(): f64 { ... self ... }`, called as `s.area()` |

## Declarations

Every declaration is written `name: type`, with the name first and the type
after a colon.

- **Variables** are written `x: i32;` or `x: i32 = 0;`. There is no
  keyword. `a: i32 = 1, b: u8^;` declares several at once, each with its
  own complete type, so C's `int a, *b` split cannot happen
  *(provisional P7)*.
- **Assigning to a name that is not declared yet declares it**, with the
  type inferred from the value: `i = 42;` declares `i: i64`. If `i` is
  already declared in this scope or an enclosing one, it is an ordinary
  assignment, as in C. See "Type inference" below.
- **`name: T` wins over a label.** `again: n = 0;` declares `again` with
  type `n`, in case `n` is a C typedef. To label a statement like that,
  write `again: ; n = 0;`. Labels before calls, `if`, `for` and so on
  work as in C.
- **Functions** have no keyword. The return type follows the parameter
  list after a colon: `add(a: i64, b: i64): i64 { ... }`.
  - A prototype ends with `;` instead of a body.
  - With no `: type`, the function returns nothing (C's `void`)
    *(provisional P5)*.
  - Empty parentheses mean no parameters, i.e. C's `(void)` *(provisional P4)*.
- **Parameters** must be named: `f(n: i32)`. C's unnamed `f(int)` is not
  available yet.
- **Struct and union members** follow the same form and end with `;`:
  `struct p { x: i32; y: i32; };` *(provisional P8)*.
- **Storage classes** go in front: `static f(): i32`, `static n: i32`,
  `extern e: i32` *(provisional P9)*.
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
`s: u8^ := "hi";` and passing a `u8^` to `strlen` just work. kelvinc
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
imported headers work: `f: FILE^ := stdout;` and
`n: size_t = strlen(s);`. The same holds after `as`: `n as size_t`,
`p as FILE^`.

### Type inference

A declaration without a type, `name = value`, infers the type from the
value:

- an integer literal is `i64`: `i = 42;`, `m = -1;`
- a floating literal is `f64`: `d = 1.5;`, `e = 1e9;`
- a value with a written type is that type: `u = 0xdead:u16;`,
  `u = 0xdead as u16;` and `c = u8(300);` are all `u16`/`u8`

Anything else needs a written type, including `y = x + 1;`, `s = "hi";`
and `b = true;`. A written type is always what you get: `b: u8 = 42;`
is a `u8`.

`for (i = 0; i < n; i++)` declares `i` for the loop when `i` is not
declared yet. In a list such as `for (i = 0, n = 0; ...)`, each name that
already exists is assigned rather than redeclared. A declaration cannot be the body of `if`, `while`, `for` or
`do`, or follow a label (as in C), so `if (c) x = 1;` with an undeclared
`x` is an error.

**Beware C globals from headers.** Kelvin does not see what a header
declares, so `optind = 1;` would declare a new local `optind` instead of
assigning the one from `<unistd.h>`. Tell Kelvin about such a global first,
with `extern optind: i32;` at the top level.

## Literals

Literals carry no size or type hints. C's suffixes `u`, `l`, `ll` and `f`
(`10UL`, `10u`, `1.5f`, `1.5L`) are errors. The type belongs on the
declaration, or on the value as an annotation (`10:u64`):

| C | Kelvin |
|---|--------|
| `unsigned long v = 10UL;` | `v: u64 = 10;` |
| `float f = 1.5f;` | `f: f32 = 1.5;` |
| `long long n = 10LL;` | `n = 10;` (or `n: i64 = 10;`) |

Everything else about literals is C's: hex `0xff`, octal `017`, binary
`0b101`, exponents `1e9`, hex floats `0x1p4`, character constants `'a'`,
and adjacent strings. A literal inside an expression still has C's type, so
a bare `1` is C's `int` (an `i32`). Where C would write `1UL << 40`, Kelvin
writes `1:u64 << 40`.

## References: `:=` and `=`

Assigning a pointer (a reference) uses `:=`, and `=` is for values:

```kelvin
buffer := malloc(8 * 1024):i64^;    // declares buffer: i64^
buffer[0] = 42;                     // a value, through the reference
p: i32^ := &x;                      // typed declarations too
p := &y;                            // reassigning the reference
p^ = 7;                             // assigning the value it refers to
for (n: struct node^ := list; n; n := n^.next) { ... }
```

- `=` on a reference and `:=` on a value are errors, wherever kelvinc can
  see the target's type: variables, parameters, `self`, fields of Kelvin
  structs, `p^` and `a[i]`. Targets it cannot see, such as C typedef
  types, fields of C structs and call results, are not checked
  *(provisional P32)*.
- Pointer arithmetic is unchanged: `p += 1`, `p++`.
- An array is a value, even an array of pointers: `refs: i32^[2] = {p, q};`.
  An array parameter, though, is a pointer, as in C: in `f(a: i32[4])`,
  write `a := a + 1`.
- `:=` is an ordinary assignment operator (C's `=`), so it works inside
  expressions, and like `=` it declares a name that is not declared yet.

## No `void`: `any^` and `nullptr`

Kelvin has no `void` type:

- **`any^` is C's `void *`.** `any` exists only behind `^`, so `any^`,
  `any^^` and `const any^` are fine, but `p: any` is an error.
- **`nullptr` is C's `(void *)0`**, typed `any^`: `p := nullptr`, and
  `r := nullptr` infers `any^`.
- **A reference declared without a value is `nullptr`**, so `p: any^;`
  means `p := nullptr`. This applies to every pointer declaration
  (`q: i32^;`), local or global, but not to `extern` ones
  *(provisional P33)*.
- **A function without a result** omits `: type`, as before.
- **To discard a value**, write it as a statement. There is no `(void)x`,
  and C may warn about an unused value *(provisional P33)*.

`void` is rejected with a hint wherever it is written: `f(): void`,
`p: void^`, `(void)x`, `x as void`.

## Expressions

| C | Kelvin | Note |
|---|--------|------|
| `*p` | `p^` | Postfix, so it chains left to right: `p^[i]` is `(*p)[i]` |
| `p->m` | `p^.m` | `->` is an error with a hint |
| `a ^ b` | `a ~ b` | `~` keeps its C precedence slot for XOR |
| `a ^= b` | `a ~= b` | `p^ = x` is always an assignment through `p` |
| `~a` | `~a` | Unary `~` is still bitwise NOT |
| `(int)x` | `i32(x)` or `x as i32` | See Conversions below |

Everything else is C's, including precedence, so `6 & 3 == 3` is still
`6 & (3 == 3)`. The same goes for integer promotion, implicit conversions,
truthiness, `?:`, `,`, `++`/`--`, compound literals and designated
initializers.

## Conversions (no C casts)

C's `(T)v` does not exist in Kelvin. There are two ways to convert, and
both mean exactly what the C cast means (`i32(3.9)` is 3, `u8(300)` is 44):

- **`T(v)`**, a converter, for built-in types: `i32(x)`, `u8(c)`,
  `f64(n) / 2`, `bool(flags & 4)` *(provisional P18)*.
- **`v:T`**, a type annotation, means exactly `v as T`: `0xdead:u16`,
  `1:u64 << 40`, `n:size_t`. In the middle of a ternary (`c ? a : b`)
  and in a `case` label, a bare name after `:` is the separator, so
  annotate with a typedef there by using parentheses or `as`.
- **`v as T`**, for any type, including pointers and C typedef names:
  `malloc(n) as i32^`, `p as any^`, `n as size_t`.

`as` binds like C's cast. It is tighter than every binary operator and
looser than prefix operators, and it chains left to right
*(provisional P17)*:

| Kelvin | Means | C |
|--------|-------|---|
| `-x as u8` | `(-x) as u8` | `(uint8_t)-x` |
| `a * b as i64` | `a * (b as i64)` | `a * (int64_t)b` |
| `x as i64 as i32` | `(x as i64) as i32` | `(int32_t)(int64_t)x` |
| `(p as u8^)[0]` | index the converted pointer | `((uint8_t *)p)[0]` |

Parenthesize to index or dereference the result of `as`. `p as u8^[0]`
would read `u8^[0]` as a type. Writing a C cast, whether `(i64)x`,
`(u8^)p` or `(size_t)n`, is an error that suggests `v as T` or `T(v)`.
`as` binds tighter than `*` too, so `malloc(n as size_t * sizeof(i32))`
means `malloc((n as size_t) * sizeof(i32))`.

C casts to typedef names are caught as well. `(size_t)n` and `(FILE *)p`
get the Kelvin hint. `(size_t)-1`, `(size_t)(n + 1)` and `(int32_t)*p` look
like arithmetic or a call to Kelvin, so they reach the C compiler, which
rejects them with "expected expression" at your line. They never compile
as a cast.

C-style declarations at the start of a statement get the Kelvin spelling as
a hint:

- `size_t * p = &n;` suggests `p: size_t^`, and `size_t n = 0;`
  suggests `n: size_t`.
- `const u8 *s` suggests `s: const u8^`, and `size_t a[3];` suggests
  `a: size_t[3]`.
- `static size_t m;` suggests `static m: size_t`, and
  `size_t f(void);` points to function syntax.

An expression that only looks similar, such as `n * f(x) == 4 || g();`, is
left alone.
One shape cannot be caught, because Kelvin cannot see typedefs: a statement
`name(x);` or `name(x) = v;` is a call or a function-like macro, but if
`name` is a C typedef, C reads it as a declaration of `x`. To convert to a
typedef type, write `x as size_t`, never `size_t(x)`.

A converter takes exactly one value (`i32(a, b)` is an error), and a
statement may start with one.

A converter groups its whole argument, so `i32(TOTAL)` is right even if a
header defines `TOTAL` as `1.5 + 2.5` without parentheses. `TOTAL as i32`,
like C's `(int)TOTAL`, converts only the `1.5`.

Compound literals are not casts, and they work as in C for any type,
including typedef names with suffixes, and under `sizeof`:
`(struct point){.y = 7}`, `(div_t){.quot = 3, .rem = 1}`,
`(size_t[2]){1, 2}`, `sizeof (i32[3]){1, 2, 3}` *(provisional P19)*.

## Statements

Only declarations and assignments differ: `x: i32 = 0;` or `x = 0;` (see
Declarations), also in `for (i: i32 = 0; ...)` and `for (i = 0; ...)`, and
references take `:=` (see References). `if`, `while`,
`do`, `for`, `switch`, `case`, `goto` and labels are C's.

## The prelude: `print` and `println`

Every Kelvin program can use `print` and `println` without an import:

```kelvin
main(): i32
{
    n: i64 = -42;
    println("n = ", n, ", half = ", n / 2.0);   // n = -42, half = -21.0
    println();                                  // just a newline
    return 0;
}
```

- `print(a, b, ...)` prints up to 16 values with no separators, and
  `println(...)` adds a newline.
- Each value prints according to its C type *(provisional P21)*:
  - integers of every size in decimal, so `i64` needs no `PRId64`
  - floats in the shortest text that reads back the same, always with a
    `.` or an exponent (`1.0`, `0.1`, `1e+300`)
  - `bool` as `true`/`false`
  - `u8^` and string literals as strings (`(null)` for a null pointer)
  - other pointers as addresses
- Comparisons and `!` produce C's `int`, so `println(a == b)` prints `1`
  or `0`. Write `bool(a == b)` to print `true`/`false`. `true` and `false`
  themselves are `bool`s *(provisional P23)*.
- `print` and `println` cannot be redefined.
- The prelude lives in `libkelvin`, which kelvinc links statically
  *(provisional P22)*. The same library works from C:
  `#include <kelvin_prelude.h>` and link `-lkelvin`.

## Methods

Every type can have methods. You define them Swift-style on a struct or
union, or on a built-in type, with an implicit `self` (passed by value):

```kelvin
struct point { x: i32; y: i32; };

point.dist2(): i64 { return self.x * self.x + self.y * self.y; }
f64.half(): f64 { return self / 2; }

main(): i32
{
    p: struct point = {3, 4};
    println(p.dist2(), " ", p.cstr, " ", 3.0.half());  // 25 {x: 3, y: 4} 1.5
    return 0;
}
```

- **Literals** take methods and properties too: `2.cstr`, `1.5.hex`,
  `(7:i64).inc()` *(provisional P30)*. Hex floats like `0x1.f4p+9` are
  still numbers. Annotated values need parentheses: `(0.1:f32).cstr`.
- **`toString()`, `fmt()` and `String` are shelved** until Kelvin has a
  true string type (#22). Calling or defining the methods `x.toString()`
  and `x.fmt(...)`, or naming the type `String`, is an error that points
  at `.cstr` *(provisional P36)*. Plain functions, variables and
  parameters may still be named `toString` or `fmt`, as in
  `printf(fmt: const u8^, ...): i32;`.
- **Dispatch** is chosen by the C compiler (`_Generic`), which brings these
  rules *(provisional P26)*:
  - As in C, declare a method before calling it. A prototype is
    `point.area(): f64;`. A method may call itself.
  - A method call cannot appear in a global initializer.
  - Enums cannot have methods.
  - C typedef names cannot be receivers, and neither can `cstr` or `any`.
  - `x.name(...)` is a method call only if some type in the file has a
    method `name`. Otherwise it calls through a field, as in C.

## Properties: `.size`, `.cstr`, `.dec`, `.hex`, `.oct`, `.bin`

Properties are written without parentheses:

```kelvin
c: i32 = 42;
b: u8 = 255;
p: struct point = {3, 4};
println(c.size, " ", c.cstr, " ", p.cstr);          // 4 42 {x: 3, y: 4}
println(c.dec, " ", c.hex, " ", c.bin);              // +42 +0x2a +0b101010
println(b.dec, " ", b.hex, " ", b.oct);              // 255 0xff 0o377
println(3.141592653589793.hex);                      // +0x1.921fb54442d18p+1
```

- **`x.size`** is `sizeof(x)`.
- **`x.cstr`** is the text of any value, as `cstr` (#22):
  - **Numbers** are plain decimal (`42`, `-7`), including 128-bit ones.
    Floats are lossless: `0.1.cstr` is `0.10000000000000001` (`%.17g`;
    `%.9g` for `f32`), while `print` keeps the shortest form, `0.1`.
  - **`bool`** is `true` or `false`. **Complex numbers** are `1+2i`.
  - **A string** (`cstr`, `u8^`, `i8^`, a literal) is its own text:
    `s.cstr` is `s` itself, still `const` if `s` was. Other pointers are
    addresses (`0x0` for null).
  - **Structs** get derived text, `{x: 3, y: 4}`, with nested structs and
    arrays (`[a, b]`); a string field shows at most 60 bytes, and a longer
    one is cut with `...` *(provisional P35)*. A union is `<union name>`.
    It cannot be overridden for now.
  - **Arrays** have no `.cstr` (C arrays are not values); index them, or
    put them in a struct.
  - **C structs and unions** from headers have no `.cstr` of their own.
    Inside a Kelvin struct they show as `{...}`, as do other C types
    kelvinc cannot print: arrays other than `char` text, and pointers
    behind a typedef other than byte strings and `void *` (a function
    pointer, `pthread_t` on macOS). A struct whose flexible array member
    is declared through a C typedef has no `.cstr`.
  - **Where kelvinc cannot see that a value is a struct**, as in
    `(c ? p : q).cstr`, the C compiler reports `kv_cstr_unseen_struct`;
    assign the value to a variable first. kelvinc does see variables,
    fields, `v as T`, and what Kelvin functions and methods return
    *(provisional P35)*.
- **`cstr`** is a built-in name for `u8^` (C's `uint8_t *`), as if declared
  `typedef u8^ cstr`. It is a reference, so assign it with `:=`, and
  `cstr const` is a constant pointer *(provisional P36)*.
- **Integers** have `.dec`, `.hex`, `.oct` and `.bin`. Each returns `u8^`
  text with a prefix of `0x`, `0o` or `0b`. Signed integers always carry a
  sign (`+42`, `-0x2a`) and unsigned ones never do, so the text tells
  `i32` from `u32`.
- **`f32`/`f64`** have `.dec` (lossless, like `.cstr`) and `.hex`
  (C's `%a`), always signed.
- **The text lives on the caller's stack**, in a buffer sized in advance:
  for `.dec` and friends, to fit the text of any type (at most 132 bytes,
  for `.bin`); for `.cstr`, from the receiver's struct, or 64 bytes for
  one value. There is no heap and nothing to free. The text lasts until the enclosing block
  ends, also when it was made in a brace-less `if` or `for` body or among
  a method call's arguments. Do not return it from a function
  *(provisional P34)*.
- **Fields win.** A field with the same name wins, in a Kelvin struct and
  in a C struct from a header. When kelvinc cannot see whether the
  receiver is a struct, `.size` is a field (write `sizeof(x)` there), while
  `.cstr`/`.dec`/`.hex`/`.oct`/`.bin` are properties.
- **Errors.** `.hex` on a pointer, bool or struct, and `.oct` or
  `.bin` on a float, are errors. Where kelvinc cannot see the type, as in
  `getenv("HOME").hex`, the C compiler reports it, naming
  `kv_no_such_property`.
- **Enums** follow C's types. An enumerator such as `BLUE` is an `int`,
  so `BLUE.dec` is `+2`. A variable of an enum type has the integer type
  the C compiler picks, `unsigned int` on gcc and clang when no
  enumerator is negative, so its `.dec` is `2`.
- **C bit-fields** from a header are converted first, as in
  `u32(b.flags).hex`: gcc's `_Generic` does not match a bit-field's type.

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

A header macro that expands to nothing or to an operator can change how C
reads the code around it. Kelvin cannot see macro definitions and treats
every macro as an ordinary name. `_Pragma("...")` is allowed only as a
statement of its own.

## Reserved words

`print` and `println` belong to the prelude and cannot be redefined.
The type name `String` is shelved until Kelvin has a true string type,
and stays reserved, as do the method names `toString` and `fmt` (#22).
Kelvin reserves all of C's keywords, plus `i8` … `u128`, `f32`, `f64`,
`bool`, `true`, `false`, `String`, `any`, `nullptr` and `cstr`
*(provisional P11)*, and `as` (#14). It
also rejects C compiler keywords beyond C11, such as `__extension__`,
`__real__`, `__alignof__`, `typeof`, `_BitInt`, `__signed__` and `__int128`
(use `i128`), because in C they can act as casts or prefix operators
*(provisional P20)*. `__asm__(...)` and `__attribute__((...))` remain
usable, and `_Pragma("...")` works as a statement. `fn` is not reserved.

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
- literal suffixes (on purpose: see Literals)
- the preprocessor beyond `#import`
- statements of the form `name(x);` where `name` is a C typedef: C reads
  them as declarations, and Kelvin cannot tell (see Conversions)
- `alignof` and `typeof` (reserved C compiler keywords, P20)
- `__asm__ __volatile__ (...)` (two names in a row; `__asm__(...)` works)
- function pointer types
- `sizeof` of a typedef-based type with a suffix, such as `sizeof(FILE^)`
  (Kelvin reads `FILE^` as a dereference; `sizeof(size_t)` and `sizeof p`
  work)

## Diagnostics

The C compiler checks Kelvin programs, and `#line` directives make its
errors and warnings point at your `.k` file and line. Kelvin's own syntax
errors also carry hints for C habits, such as `*p`, `p->m`, `int x;`,
`long`, `10UL` or `(int)x`.
