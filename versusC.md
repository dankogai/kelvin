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
| `int x = 0;` | `var x:i32 = 0` |
| `const int k = 42;` | `let k:i32 = 42` (#27) |
| `long n = 42;` | `var n = 42` (inferred as `i64`) |
| `long *buf = malloc(n);` | `var buf := malloc(n):i64^` (`:=` for references) |
| `p = q;` (pointers) | `p := q` |
| `double d = 1.5;` | `let d = 1.5` (inferred as `f64`) |
| `unsigned long v = 10UL;` | `var v:u64 = 10` |
| `float f = 1.5f;` | `var f:f32 = 1.5` |
| `1UL << 40` | `1:u64 << 40` |
| `uint16_t u = 0xdead;` | `var u = 0xdead:u16` (inferred as `u16`) |
| `char *s;` | `var s:u8^` or `var s:cstr` |
| `int *a[4];` | `var a:i32^[4]` *(provisional)* |
| `int (*p)[4];` | `var p:i32[4]^` *(provisional)* |
| `const char *const s = t;` | `let s:const u8^ := t` |
| `long add(long a, long b) { ... }` | `add(a:i64, b:i64):i64 { ... }` (parameters are lets) |
| `void f(void);` | `f()` |
| `void *p = NULL;` | `var p:any^` (a reference is `nullptr` until assigned) |
| `(void *)0`, `NULL` | `nullptr` |
| `static int g(void);` | `static g():i32` |
| `int main(int argc, char **argv)` | `main(argc:i32, argv:u8^^):i32` |
| `struct p { int x, y; };` | `struct p { x: i32, y: i32 }` |
| `struct p q;`, `typedef struct p p;` | `var q:p` (a tag is a type by its bare name, #29) |
| `*p` | `p^` |
| `**pp` | `pp^^` |
| `*p++ = *q++;` | `p^ = q^; p := p.next; q := q.next` (no `++`, #26) |
| `i++`, `--n` | `i += 1`, `n -= 1` (statements) |
| `x = 1; y = 2;` on two lines | `x = 1` and `y = 2`: a line ends a statement (#35) |
| `long square(long x) { return x * x; }` | `square(x:i64):i64 { x * x }` (#35) |
| `for (int i = 0; i < n; i++)` | `for i in 0..<n { ... }` (#28) |
| `for (int i = 1; i <= n; i++)` | `for i in 1...n { ... }` |
| `for (p = s; *p; p++) { c = *p; ... }` | `for c in s { ... }` (#30) |
| `for (n = head; n; n = n->next)` | `for n in head { ... }` |
| `p->m` | `p^.m` |
| `a ^ b`, `a ^= b` | `a ~ b`, `a ~= b` |
| `(unsigned char)c` | `u8(c)` or `c as u8` |
| `(int *)malloc(n)` | `malloc(n) as i32^` |
| `(size_t)n` | `n as size_t` |
| `strtol(s, NULL, 8)`, `atof(s)` | `i64(s, 8)`, `f64(s)` or `s.f64` (#36) |
| `snprintf(buf, n, "%s: %d", name, n)` | `` `${name}: ${n}` `` (#39) |
| `(uintptr_t)p`, `printf("%p", p)` | `p.addr`, `print(p.hex)` (#37) |
| `sizeof(long)` | `sizeof(i64)` |
| `#include <stdio.h>` | `#import <stdio.h> as C` |
| `printf("%" PRId64 "\n", n)` | `println(n)` (prelude, no import) |
| `snprintf(buf, sizeof buf, "%lld", n)` | `n.cstr` (`cstr` text on the stack) |
| `sizeof x` | `x.size` |
| `__typeof__(x) y;` | `var y:x.type` (#34) |
| `snprintf(buf, sizeof buf, "0x%x", n)`, `n` unsigned | `n.hex` (`u8^` text on the stack; a signed `n` gives `+0x2a` or `-0x2a`) |
| `double area(struct shape s)` | `shape.area():f64 { ... self ... }`, called as `s.area()` |
| `int (*cmp)(const void *, const void *);` | `var cmp:(const any^, const any^):i32` (#31) |
| a `static` function written only to be passed | `sort(xs, n) { $0 < $1 }` (an anonymous function, #32) |

## Declarations

A variable is declared with `let` or `var`, and the type follows the name
after a colon (#27):

```kelvin
let k = 42                 // a let never changes: C's const
var n:i32 = 0              // a var may change
var buf := malloc(n):u8^   // := for references (see References)
let a:i32 = 1, b:u8^ := p
static var calls:i32
```

- **`let` never changes.** `let i = 42; i += 1` is an error, and in the
  generated C a `let` is `const`. A let pointer is fixed, but what it
  points to may change: `let p:i32^ := &x; p^ = 7` is fine. A let array
  or struct cannot change its elements or fields. A `let` needs a value,
  except in an `extern` declaration.
- **`var` may change.** `var p:any^` without a value is `nullptr` (#20).
- **A list** shares the keyword: `let a:i32 = 1, b:u8^ := p` declares
  both, each with its own complete type, so C's `int a, *b` split cannot
  happen *(provisional P7)*.
- **A plain `x = 0` assigns**, and never declares. `x:i32 = 0` without
  `let` or `var` is an error that suggests them, and `again: n = 0` is a
  label before a statement, as in C.
- **Functions** have no keyword. The return type follows the parameter
  list after a colon: `add(a:i64, b:i64):i64 { ... }`.
  - A prototype ends with `;` or the end of its line instead of a body.
  - With no `: type`, the function returns nothing (C's `void`)
    *(provisional P5)*.
  - Empty parentheses mean no parameters, i.e. C's `(void)` *(provisional P4)*.
- **Parameters** are lets unless written `var`: in `f(p:u8^)`, `p` cannot
  change, while `f(var p:u8^) { p := p.next }` may move `p`. A method's
  `self` is a mutable copy. Parameters must be named: C's unnamed
  `f(int)` is not available yet.
- **Struct and union members** are written `name: type`, ended by `;` or
  a new line, with no keyword: `struct p { x: i32; y: i32 }`
  *(provisional P8)*.
- **A struct, union or enum is a type by its bare name** (#29), as if C
  had `typedef struct point point;`: `var p:point`, `next: node^` inside
  `struct node`, `sizeof(point)`, `(point){1, 2}`, `c:color` for
  `enum color`. `struct point` still works too. kelvinc resolves the name
  itself and writes `struct point` in the C, so a variable or function
  may share the name; in an expression the name is that variable, from
  its own declarator on, as in C. In `sizeof(name)`, a function of the
  same name does not count (`sizeof(node)` inside a constructor `node()`
  is the struct's size). A struct from a C header has a bare name once
  Kelvin declares it, as in `struct timespec`, but in `sizeof` write
  `sizeof(struct timespec)`, since headers give such names to functions
  and variables too (`stat`, `timezone`) *(provisional P41)*.
- **Storage classes** go in front: `static f():i32`, `static var n:i32`,
  `extern var e:i32` *(provisional P9)*.
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
`let s:u8^ := "hi"` and passing a `u8^` to `strlen` just work. kelvinc
silences C's pointer-sign warnings about the mix, and emits `main`'s `argv`
as `char **`, because C requires that.

### Pointers and arrays are postfix

- `T^` is a pointer to `T`. `*` only means multiplication.
- `T[N]` is an array of N `T` *(provisional P1)*. Suffixes read left to
  right: `i32^[4]` is an array of four pointers, and `i32[4]^` is a pointer
  to an array. A run of brackets keeps C's order, so `i32[2][3]` indexes as
  `m[1][2]` *(provisional P2)*.
- C's hardest declarators become readable. A function returning a pointer to
  an array of four ints, `int (*f(void))[4]`, is `f():i32[4]^`.

### Qualifiers

`const` and `volatile` apply to whatever is on their left. A leading
qualifier applies to the base type, which is C's own rule
*(provisional P6)*. `u8 const^` and `const u8^` are both `const uint8_t *`,
and `u8^ const` is `uint8_t *const`.

### C typedef names

After a colon, any identifier is accepted as a type, so typedefs from
imported headers work: `let f:FILE^ := stdout` and
`let n:size_t = strlen(s)`. The same holds after `as`: `n as size_t`,
`p as FILE^`.

### Type inference

A declaration without a type, `let name = value` or `var name = value`,
infers the type from the value:

- an integer literal is `i64`: `let i = 42`, `var m = -1`
- a floating literal is `f64`: `let d = 1.5`, `let e = 1e9`
- a `bool` is `bool`: `var done = false`, `let ok = a < b`,
  `let both = ok && f(x)` (#24, #25), as is a `bool` variable or the
  `bool` result of a Kelvin function or method
- a value with a written type is that type: `let u = 0xdead:u16`,
  `let u = 0xdead as u16` and `let c = u8(300)` are all `u16`/`u8`
- an anonymous function that writes its parameters is its function type:
  `let mul := { (a:i64, b:i64):i64 in a * b }` (#32)

Anything else needs a written type, including `let y = x + 1`,
`let s = "hi"` and a `bool` from a C function, which kelvinc cannot see
(`let ok:bool = isdigit(c) != 0` is fine, `let ok = is_even(4)` from a
header is not). A written type is always what you get: `let b:u8 = 42`
is a `u8`.

A declaration cannot be the body of a `for` or follow a label (as in C),
so `for (;;) var x = 1` is an error. Names from C headers, such as
`optind`, are assigned with a plain `optind = 1`, as in C.

## Literals

Literals carry no size or type hints. C's suffixes `u`, `l`, `ll` and `f`
(`10UL`, `10u`, `1.5f`, `1.5L`) are errors. The type belongs on the
declaration, or on the value as an annotation (`10:u64`):

| C | Kelvin |
|---|--------|
| `unsigned long v = 10UL;` | `var v:u64 = 10` |
| `float f = 1.5f;` | `var f:f32 = 1.5` |
| `long long n = 10LL;` | `var n = 10` (or `var n:i64 = 10`) |

Everything else about literals is C's: hex `0xff`, octal `017`, binary
`0b101`, exponents `1e9`, hex floats `0x1p4`, character constants `'a'`,
and adjacent strings. A literal inside an expression still has C's type, so
a bare `1` is C's `int` (an `i32`). Where C would write `1UL << 40`, Kelvin
writes `1:u64 << 40`.

## References: `:=` and `=`

Assigning a pointer (a reference) uses `:=`, and `=` is for values:

```kelvin
var buffer := malloc(8 * 1024):i64^   // declares buffer: i64^
buffer[0] = 42                        // a value, through the reference
var p:i32^ := &x                      // typed declarations too
p := &y                               // reassigning the reference
p^ = 7                                // assigning the value it refers to
for (var n:node^ := list; n != nullptr; n := n^.next) { ... }
```

- `=` on a reference and `:=` on a value are errors, wherever kelvinc can
  see the target's type: variables, parameters, `self`, fields of Kelvin
  structs, `p^` and `a[i]`. Targets it cannot see, such as C typedef
  types, fields of C structs and call results, are not checked
  *(provisional P32)*.
- Pointer arithmetic is unchanged (`p + 1`, `p += 1`, `p - q`), and a
  pointer steps by one element with `p.next` and `p.prev` (#26).
- An array is a value, even an array of pointers:
  `let refs:i32^[2] = {p, q}`. An array parameter, though, is a pointer,
  as in C: in `f(var a:i32[4])`, write `a := a + 1`.
- `:=` is printed as C's `=`. Like `=`, it is a statement (#26), usable
  in a `for` clause and after `let` or `var`.

## No `void`: `any^` and `nullptr`

Kelvin has no `void` type:

- **`any^` is C's `void *`.** `any` exists only behind `^`, so `any^`,
  `any^^` and `const any^` are fine, but `var p:any` is an error.
- **`nullptr` is C's `(void *)0`**, typed `any^`: `p := nullptr`, and
  `var r := nullptr` infers `any^`.
- **A reference declared without a value is `nullptr`**, so `var p:any^`
  means `var p:any^ := nullptr`. This applies to every pointer
  declaration (`var q:i32^`), local or global, but not to `extern` ones
  *(provisional P33)*.
- **A function without a result** omits `: type`, as before.
- **To discard a value**, write it as a statement. There is no `(void)x`,
  and C may warn about an unused value *(provisional P33)*.

`void` is rejected with a hint wherever it is written: `f():void`,
`var p:void^`, `(void)x`, `x as void`.

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
`?:`, `,`, compound literals and designated initializers, except that
conditions are `bool` (see Conditions), assignment is a statement and
there is no `++` or `--` (see Assignment).

## Conversions (no C casts)

C's `(T)v` does not exist in Kelvin. There are two ways to convert, and
both mean exactly what the C cast means (`i32(3.9)` is 3, `u8(300)` is 44),
except that a converter of text reads the number in it (#36), while
`s as i64` and `s:i64` stay C's cast:

- **`T(v)`**, a converter, for built-in types: `i32(x)`, `u8(c)`,
  `f64(n) / 2`, `bool(flags & 4)` *(provisional P18)*. Of text, it reads
  the number (#36, below).
- **`v:T`**, a type annotation, means exactly `v as T`: `0xdead:u16`,
  `1:u64 << 40`, `n:size_t`. In the middle of a ternary (`c ? a : b`)
  and in a `case` label, a bare name after `:` is the separator, so
  annotate with a typedef there by using parentheses or `as`.
- **`v as T`**, for any type, including pointers and C typedef names:
  `malloc(n) as i32^`, `p as any^`, `n as size_t`.

### Numbers from text

A converter reads a number from text (#36): `i64("42")`, `f64("1.5")`,
and with a base from 2 to 36 for an integer type, `i32("755", 8)`. The
property form is the same converter: `"42".i64` is `i64("42")`, and
`n.u8` is `u8(n)` for a number. Text is a string, `cstr`, `u8^`, `i8^`,
an array of `u8` or `i8`, the text of a property such as `n.hex`, or C's
`char *`. Every other value converts as before. Where kelvinc cannot
see the type, C's `_Generic` makes the choice.

The text is read as C's `strtol` and `strtod` read it *(provisional
P47)*:

| Kelvin | Value | Why |
|--------|-------|-----|
| `i64("  +12")` | 12 | leading spaces and a sign |
| `i64("42abc")` | 42 | the longest number is taken |
| `i64("abc")`, `i64("")` | 0 | no number |
| `i64("0755")` | 755 | base 10 unless one is given |
| `i64("ff", 16)`, `i64("0xff", 16)` | 255 | |
| `i64(n.oct, 8)`, `i64(n.bin, 2)` | `n` | Kelvin's `0o` and `0b` too |
| `i8("300")`, `u8("-1")` | 127, 0 | clamped to the type's limits, with `errno` set to `ERANGE` |
| `f64("0x1.8p1")` | 3.0 | `strtod`'s hex floats, so `f64(x.hex)` is `x` |

Every integer type reads text, `i128` and `u128` too. `bool` reads
none: `bool(p)` of a pointer tells it from `nullptr`, as in C, and of a
string, which is never `nullptr`, it is an error. A base is for text
only: after a number it is an error, from kelvinc where it sees the
number and from C (naming `kv_base_needs_text`) where only `_Generic`
does. A `?:` of texts is text (`i32(argc > 1 ? argv[1] : "8")`).

Floats are `strtod`'s and `strtof`'s own: out of range is an infinity,
`errno` is `ERANGE` also when the result is tiny, and the decimal point
is the one of the C locale in use.

As for `.size`, a field named like a type wins over the property where
kelvinc cannot see that the value is no struct, so `o.via.i64` of a C
struct is its field: there, `i64(v)` converts. `.i64` takes no base:
write `i64(s, 16)`.

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

- `size_t * p = &n;` suggests `var p:size_t^`, and `size_t n = 0;`
  suggests `var n:size_t`.
- `const u8 *s` suggests `var s:const u8^`, and `size_t a[3];` suggests
  `var a:size_t[3]`.
- `static size_t m;` suggests `static var m:size_t`, and
  `size_t f(void);` points to function syntax.

An expression that only looks similar, such as `n * f(x) == 4 || g()`, is
left alone.
One shape cannot be caught, because Kelvin cannot see typedefs: a statement
`name(x)` or `name(x) = v` is a call or a function-like macro, but if
`name` is a C typedef, C reads it as a declaration of `x`. To convert to a
typedef type, write `x as size_t`, never `size_t(x)`.

A converter takes one value, and for text, a base after it
(`i32("755", 8)`); a base after a number is an error. A statement may
start with a converter.

A converter groups its whole argument, so `i32(TOTAL)` is right even if a
header defines `TOTAL` as `1.5 + 2.5` without parentheses. `TOTAL as i32`,
like C's `(int)TOTAL`, converts only the `1.5`.

Compound literals are not casts, and they work as in C for any type,
including typedef names with suffixes, and under `sizeof`:
`(point){.y = 7}`, `(div_t){.quot = 3, .rem = 1}`,
`(size_t[2]){1, 2}`, `sizeof (i32[3]){1, 2, 3}` *(provisional P19)*.

## Statements

Declarations start with `let` or `var` (see Declarations), also in
`for (var i = 0; ...)`, and references take `:=` (see References).

`if`, `while` and `do` take their condition without parentheses, and
their bodies are blocks (#23):

```kelvin
if n > 0 {
    println("positive")
} else if n == 0 {
    println("zero")
} else {
    println("negative")
}
while fgets(line, line.size, stdin) != nullptr {
    print(line)
}
do {
    n -= 1
} while n > 0
```

- Parentheses around a condition are only grouping now: `if (n > 0) { ... }`
  still works, while C's `if (n > 0) n = 0;` is an error, since the body
  must be a block. `else` is followed by a block or by `if`.
- `switch (...)` keeps C's parentheses for now, and so does C's `for`,
  whose body may still be a single statement *(provisional P37)*. To
  count, prefer a range (see Ranges).
- `case`, `goto` and labels are C's.

### Lines end statements; one expression is the result

As in Swift, a `;` may be left out at the end of a line (#35):

```kelvin
let total:i64 = price
    * count               // goes on: price * count
println(total)
(p as i64^)^ = 1          // a new statement
let a = 1; let b = 2      // ; between statements on one line
square(x:i64):i64 { x * x }
```

- A new line ends a statement, a declaration, a struct member or a
  prototype once what is written is complete. An operator, `.member`,
  `[`, `?`, `:` or `as` at the start of the next line goes on with it,
  and so does any line after one that ends with an operator or a `,`. At
  the top level of a statement, a `(` or `{` at the start of a line
  starts the next statement; inside brackets, lines do not matter. A
  line that starts with `*p =` (a `*` touching what it assigns) is C's
  dereference, an error; `* x` goes on with a product.
- After the head of a function, a method, `if`, `while`, `for` or a
  struct, a `{` on the next line is still its body.
- A `;` still ends a statement anywhere, and separates statements on one
  line, where it is needed; `for (...; ...; ...)` keeps its own.
- A function or method whose body is one expression returns it, as an
  anonymous function does: `square(x:i64):i64 { x * x }`. There, an
  assignment, or a call kelvinc sees has no value such as `println`, is
  an error. `main` is the exception: its end returns 0 as in C, so its
  one expression is a statement, and `main():i32 { printf("hi\n") }`
  exits 0.
- A body with more than that uses `return`. kelvinc reports one that
  ends, on any path, in a value it drops: one with no effect, as in
  `if x < 0 { -1 } else { 1 }`, or a call it sees has a result (in
  `main`, only the first kind).
- In a function with a result, `return` at the end of a line takes the
  expression on the next line, as in Swift. In one without a result
  there is nothing to return, so `return` ends at its line, and a
  statement after it in the same block is an error, unless it is a
  `case`, a `default` or a label, or a block holding one, which `goto`
  may reach. `return;` is C's and is not checked.

## Ranges: `for i in a..<b`

`for i in a..<b { ... }` counts from `a` up to `b`, without `b`, and
`for i in a...b { ... }` up to and with `b` (#28):

```kelvin
for i in 0..<count {          // C: for (int i = 0; i < count; i++)
    println(i)
}
for i in 1...n { ... }     // C: for (int i = 1; i <= n; i++)
for _ in 0..<3 { ... }     // a loop that needs no counter
for b:u8 in 250...255 { }  // ends, where C's b <= 255 never would
```

- `i` is a `let` in the body, and `a` and `b` are evaluated once.
- `i`'s type is written, as in `for i:u8 in`, or comes from the bounds:
  the upper bound's type if kelvinc sees it (`0..<n` with `n:i32` gives
  `i32`), else the lower one's, else `i64` for literals. A range is of
  integers *(provisional P40)*.
- A bound is an expression down to the shifts, so `0..<n - 1` stops before
  `n - 1`. `continue` and `break` work as in any loop.
- Ranges exist only in `for` for now: there are no range values, and no
  reversed or stepped ranges yet.

## Sequences: `for x in s`

`for x in s { ... }` walks a sequence that ends at a terminator, as C's
strings and lists do (#30). What `x` is depends on `s`'s type:

```kelvin
for c in s { ... }          // s:cstr: each byte, up to the NUL
for arg in argv { ... }     // argv:u8^^: each string, up to nullptr
for n in list.head { ... }  // n:node^: each node along next, up to nullptr
for x in xs { ... }         // xs:i32[8]: up to 8 elements, or the first 0
```

- **A pointer to numbers or pointers** gives `s^`, `s.next^`, ... up to
  the first 0 or `nullptr`. A `nullptr` `s` is empty.
- **A pointer to a struct with a `next` field** is a list: `x` is each
  node's pointer, so `x^.value` reads it and may change it. The next
  pointer is read before the body runs, so the body may `free(x)`.
- **An array of known length** gives its elements, stopping early at a 0
  or `nullptr`; an array of structs gives all of them.
- **An array parameter** is a pointer in C. A let one, `xs:i32[4]`, is
  walked up to its declared length; a `var` one may have moved, so it is
  walked like a pointer.
- **A pointer kelvinc cannot see**, such as `getenv("PATH")`'s, is walked
  like a pointer.
- `x` is a `let`, `s` is evaluated once and does not move, and
  `for _ in s` names no variable. `for b:u8 in xs` converts each element
  for `b`. A number, `any^`, an array of arrays, a C struct whose fields
  kelvinc cannot see, or an array in a value that a call returns
  (`make().xs`, which C discards before the loop runs) is an error
  *(provisional P42)*.

## Assignment is a statement

Assignment has no value in Kelvin, and `++` and `--` are gone (#26), as
in Swift:

| C | Kelvin |
|---|--------|
| `i++;`, `--n;` | `i += 1`, `n -= 1` |
| `*p++ = *q++;` | `p^ = q^; p := p.next; q := q.next` |
| `a = b = 0;` | `a = 0; b = 0` or `a = 0, b = 0` |
| `while ((c = getchar()) != EOF) { ... }` | `var c:i32 = getchar(); while c != EOF { ...; c = getchar() }` |
| `a[i++] = x;` | `a[i] = x; i += 1` |

- `=`, `:=` and the compound assignments (`+=`, `~=`, ...) appear only as
  a statement of their own, or in a `for` clause. Both take a comma list,
  run left to right: `for (var i = 0, j = 10; i < j; i += 1, j -= 1)`,
  `x = 1, y = 2` *(provisional P38)*. A list either declares, after
  `let` or `var`, or assigns.
- So nothing can be changed inside `[...]`, a condition or an argument,
  except by a function call.
- `p.next` is `p + 1` and `p.prev` is `p - 1`, for a pointer kelvinc can
  see; `any^` has neither. On anything else, `.next` is a field, so a list
  still walks with `n := n^.next`.

## Conditions are `bool`

Every condition is a `bool`: those of `if`, `while`, `do` and `for`, the
condition of `?:`, and the operands of `&&`, `||` and `!` (#23). There is
no truthiness, so compare instead:

| C | Kelvin |
|---|--------|
| `if (n)` | `if n != 0` |
| `while (p)` | `while p != nullptr` |
| `if (!p)` | `if p == nullptr` |
| `while (fgets(buf, n, f))` | `while fgets(buf, n, f) != nullptr` |
| `while (1)` | `while true` |

- Comparisons, `&&`, `||` and `!` give a `bool`, not C's `int`, so
  `println(a == b)` prints `true` and `sizeof(a < b)` is 1.
- A `bool` variable, field or function result is a condition as it is, as
  is `bool(x)` or `x as bool`.
- kelvinc reports a non-`bool` condition it can see, with a hint
  (`'x != 0'`, `'p != nullptr'`). Where it cannot see the type, as for C
  functions and macros, the C compiler reports it, naming
  `kv_condition_is_not_bool`: `while fgets(...)` fails that way, and so
  does `if isdigit(c)` (an `int`), which needs `!= 0`.

## The prelude: `print` and `println`

Every Kelvin program can use `print` and `println` without an import:

```kelvin
main():i32 {
    let n:i64 = -42
    println("n = ", n, ", half = ", n / 2.0)   // n = -42, half = -21.0
    println()                                  // just a newline
    return 0
}
```

- `print(a, b, ...)` prints up to 16 values with no separators, and
  `println(...)` adds a newline.
- Each value prints according to its C type *(provisional P21)*:
  - integers of every size in decimal, so `i64` needs no `PRId64`
  - floats in the shortest text that reads back the same, always with a
    `.` or an exponent. As in Swift, they are plain from 0.0001 up to
    2^53 (2^24 for `f32`), where every integer is exact (`10.0`, `0.1`,
    `9007199254740992.0`), and have an exponent otherwise (`1e+16`,
    `1e-05`, `1e+300`)
  - `bool` as `true`/`false`
  - `u8^` and string literals as strings (`(null)` for a null pointer)
  - other pointers as addresses
- Comparisons, `&&`, `||` and `!` produce a `bool` (#23), so
  `println(a == b)` prints `true` or `false`, as do `true` and `false`
  themselves *(provisional P23)*.
- `print` and `println` cannot be redefined.
- The prelude lives in `libkelvin`, which kelvinc links statically
  *(provisional P22)*. The same library works from C:
  `#include <kelvin_prelude.h>` and link `-lkelvin`.

## Function types: `(T, U):R`

A function type is written as a function's head without names (#31), as
Swift writes `(T, U) -> R`. In C it is a pointer to a function:

```kelvin
fold(xs:i64^, n:size_t, f:(i64, i64):i64):i64 { ... f(acc, xs[i]) ... }
pick(product:bool):(i64, i64):i64 { ... }   // returns a function

var f:(i64, i64):i64       // C: int64_t (*f)(int64_t, int64_t) = 0;
f := add                   // a reference: assigned with :=
let t:() := tick           // no parameters, no result
```

- `(T)` has no result, as a function without `:R` has none, and `...`
  ends a variadic one: `(i32, ...):i64`. The parameters are types
  without names.
- A function type is a reference (P32): it is assigned with `:=`, is
  `nullptr` until assigned, and is compared with `nullptr`
  (`if f != nullptr`). A `let` one is a `const` pointer.
- The result takes every suffix after it, so `(i64):i64^` returns a
  pointer; an array of functions, or a pointer to a function type, has no
  spelling yet, and kelvinc says so.
- A Kelvin function's name has its function type, so `let g:(i64):i64 := f`
  works, `if f {` asks for a comparison, and `f.size` is a pointer's size.
  `?:` between functions is a function too.
- Where kelvinc sees a function, its `.cstr`, `.next` and `.prev`, and
  `print` or `println` of it (or of `&f`), are errors. In a struct's
  derived text, a function member is its address.
- A C function with `char` parameters does not match a Kelvin function
  type with `u8^` ones: C's `char` and `unsigned char` make incompatible
  function types, so `let p:(const u8^, ...):i32 := printf` fails. Wrap
  it instead: `let cmp:(cstr, cstr):i32 := { strcmp($0, $1) }`
  *(provisional P43)*.

## Anonymous functions: `{ ... }`

An anonymous function is `{ ... }` (#32). It encloses nothing, since C has
no closures: kelvinc makes it a `static inline` function of its own
(#33), declared before the declaration around it and defined after it.
With `kelvinc -O`, the C compiler may then inline it where it is called,
as in a Kelvin `sort` that calls its `before`; one passed to a C
function such as `qsort` stays a function, whose address C needs.

```kelvin
sort(xs, 8) { $0 < $1 }                 // the last argument, after the call
sort(xs, 8, { $[0] > $[1] })            // or inside the parentheses
each(xs, 3) { total += $0 }             // no result: one assignment is fine
let inc:(i64):i64 := { $0 + 1 }
qsort(names, 4, sizeof(cstr)) { (a:const any^, b:const any^):i32 in
    strcmp((a as const cstr^)^, (b as const cstr^)^)
}
```

- **Its parameters** are `$0`, `$1`, ..., also written `$[0]`, `$[1]`,
  where kelvinc sees their types: from the parameter of a Kelvin function,
  method or function value it is passed to, a declared variable, a
  member of a struct in an initializer list (`{ $0 - $1 }` for a member
  `sub:(i64, i64):i64`), an assignment's target, or the result of the
  function it is returned from. Elsewhere, such as for C's `qsort`,
  whose types kelvinc cannot see, it writes them:
  `{ (a:T, b:U):R in ... }`. Without either, it has none, as for
  `atexit() { println("bye") }`. `$[k]` takes a decimal number, and `$`
  works only in an anonymous function.
- **In a declaration without a type**, `{` starts an initializer list, so
  an anonymous function there writes its parameters, even none:
  `let hi := { () in println("hi") }`. One that writes them may stand
  anywhere a value may, and be called there:
  `c ? { (x:i64):i64 in x + 1 } : dec`, `{ (a:i64):i64 in a * 2 }(3)`.
  In an initializer list, kelvinc follows the members in order and
  designators of one member. A string fills an array member and a value
  of a struct's type fills a struct member; after C's brace elision or
  `.a.b = ...`, an anonymous function writes its parameters.
- **A list is not a value:** where C expects a value, as for
  `memcpy(buf, {'a', 'b'}, 2)` or `show({1, 2})`, write a compound
  literal, `(u8[2]){'a', 'b'}`. kelvinc says so, rather than taking the
  list for a function.
- **A body of one expression** is the result: `{ $0 < $1 }`. Without a
  result, it must do something: a call or an assignment, as in
  `{ total += $0 }`; with one, it may not be an assignment or a call
  kelvinc sees has no value. Any other body is statements, with
  `return`. The
  text of `.hex` and friends lives in the function's own buffer, so
  returning it, as in `{ $0.hex }`, `{ $0.hex + 2 }` or
  `{ return $0.hex }`, is an error.
- **It encloses nothing:** using a local, a parameter or `self` of the
  function around it is an error, also in its parameter types; globals,
  functions and C's names are fine, as are the global it initializes and
  the ones before it. It may call the function around it. A parameter
  type that comes from elsewhere keeps its array lengths when they are
  made of numbers and globals. A length that names another function's
  local or parameter means something else here: the outer array becomes
  a pointer, as C makes it, and such a length anywhere else is an error
  that asks for written parameters.
- **Trailing:** after a call's `)`, `{ ... }` is the last argument. At
  the top level of a statement it starts on the line of the `)`, since a
  `{` on the next line starts a block there. Like any
  statement, one that ends with it needs no `;` at the end of a line
  (#35); another statement on the same line needs one. In the
  head of `if`, `while` or `for`, where a body follows, a `{` after a call
  starts the body, so pass the function inside the parentheses there:
  `if some(xs, { $0 > 3 }) {`. Inside any parentheses, an initializer
  list, or the condition of `do ... while`, it stays an argument.
- Written parameters let a declaration infer its type:
  `let mul := { (a:i64, b:i64):i64 in a * b }` *(provisional P44)*.

## Methods

Every type can have methods. You define them Swift-style on a struct or
union, or on a built-in type, with an implicit `self` (passed by value):

```kelvin
struct point { x: i32; y: i32 }

point.dist2():i64 { self.x * self.x + self.y * self.y }
f64.half():f64 { self / 2 }

main():i32 {
    let p:point = {3, 4}
    println(p.dist2(), " ", p.cstr, " ", 3.0.half())   // 25 {x: 3, y: 4} 1.5
    return 0
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
  `printf(fmt:const u8^, ...):i32`.
- **Dispatch** is chosen by the C compiler (`_Generic`), which brings these
  rules *(provisional P26)*:
  - As in C, declare a method before calling it. A prototype is
    `point.area():f64`. A method may call itself.
  - A method call cannot appear in a global initializer.
  - Enums cannot have methods.
  - C typedef names cannot be receivers, and neither can `cstr` or `any`.
  - `x.name(...)` is a method call only if some type in the file has a
    method `name`. Otherwise it calls through a field, as in C.

## Properties: `.size`, `.type`, `.typename`, `.cstr`, `.dec`, `.hex`, `.oct`, `.bin`, `.addr`

Properties are written without parentheses:

```kelvin
let c:i32 = 42
let b:u8 = 255
let p:point = {3, 4}
println(c.size, " ", c.cstr, " ", p.cstr)   // 4 42 {x: 3, y: 4}
println(c.dec, " ", c.hex, " ", c.bin)      // +42 +0x2a +0b101010
println(b.dec, " ", b.hex, " ", b.oct)      // 255 0xff 0o377
println(3.141592653589793.hex)              // +0x1.921fb54442d18p+1
```

- **`x.size`** is `sizeof(x)`. A function's `.size`, and its `sizeof`,
  are a pointer's size, since its name is a function value (#31).
- **`v.type`** is `v`'s type, written where a type goes (#34): after `:`
  and `as`, in `sizeof(...)`, in compound literals and in function types.
  `v` is a variable or `$k`, possibly followed by `.member`, `^` and
  `[i]`, as in `var w:k.type = 4`, `let p := &w as w.type^` or
  `pp^.y.type`.
  - It is the type kelvinc sees `v` declared with, so a `let`'s own
    `const` does not come along (`var w:k.type` can change). A `const`
    written before it, as in `const xs.type`, applies to an array's
    elements, as in C.
  - Where kelvinc cannot see the type (a name from a C header), or the
    type holds something C would evaluate again (a length that is not a
    number, as in a variable length array), it is C's `__typeof__(v)`,
    which keeps `v`'s own length and also a `let`'s `const`. For a C
    function, that is C's function type; `f.type^` is its pointer.
  - In `sizeof(x.type)` and `(x.type)`, where an expression could stand
    too, `.type` is a field when `x` has one, is a C struct, or has a type
    kelvinc cannot see; write `x.type` after `:` or `as` there. In other
    expressions, `x.type` is a field if `x` may have one, and otherwise an
    error, as a type is not a value.
  - A result type cannot name a parameter (C writes the result first),
    and `point.type` of a type or `i64.type` asks for the type itself.
  - A variable used only for its `.type` or `.typename` is unused as far
    as C sees (`-Wunused-variable` under `-Wall`) *(provisional P45)*.
- **`v.typename`** is the text of `v`'s type as Kelvin writes it, a `cstr`:
  `"i64"`, `"point"`, `"u8^"`, `"i32[4]"`, `"(i64):i64"`,
  `"((i64):i64)^"`. Where kelvinc cannot see the type, or it holds a
  `__typeof__`, C's `_Generic` gives the Kelvin name of a built-in type
  (`getenv("X").typename` is `"u8^"`), and anything else is `"?"`. A
  literal is C's: `42.typename` is `"i32"`, as `42.size` is 4, and
  `nullptr.typename` is `"any^"`. Through `_Generic`, an array is a
  pointer, an enum its integer type, and a bit-field may differ between
  compilers. `v` is not evaluated, as for `sizeof`.
- **`x.cstr`** is the text of any value, as `cstr` (#22):
  - **Numbers** are plain decimal (`42`, `-7`), including 128-bit ones.
    Floats are lossless: `0.1.cstr` is `0.10000000000000001` (`%.17g`;
    `%.9g` for `f32`), while `print` keeps the shortest form, `0.1`.
  - **`bool`** is `true` or `false`. **Complex numbers** are `1+2i`.
  - **A string** (`cstr`, `u8^`, `i8^`, a literal) is its own text:
    `s.cstr` is `s` itself, still `const` if `s` was. Other pointers are
    addresses (`0x0` for null), but a function has no text (#31).
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
    `(q, p).cstr`, the C compiler reports `kv_cstr_unseen_struct`;
    assign the value to a variable first. kelvinc does see variables,
    fields, `v as T`, what Kelvin functions and methods return, and a
    `?:` between two values of one type (#34) *(provisional P35)*.
- **`cstr`** is a built-in name for `u8^` (C's `uint8_t *`), as if declared
  `typedef u8^ cstr`. It is a reference, so assign it with `:=`, and
  `cstr const` is a constant pointer *(provisional P36)*.
- **Integers** have `.dec`, `.hex`, `.oct` and `.bin`. Each returns `u8^`
  text with a prefix of `0x`, `0o` or `0b`. Signed integers always carry a
  sign (`+42`, `-0x2a`) and unsigned ones never do, so the text tells
  `i32` from `u32`.
- **`f32`/`f64`** have `.dec` (lossless, like `.cstr`) and `.hex`
  (C's `%a`), always signed.
- **Pointers and functions** have `.addr` and `.hex` (#37). `p.addr` is
  the address as a number, a `uintptr_t` (C's unsigned integer as wide
  as a pointer), and `p.hex` its text: `0x` and all the digits, 16 on a
  64-bit target (`0x000000016ee86888`), with no sign, so every address
  has the same width and `u64(p.hex, 16)` is `p.addr`. This covers
  every `T^`, `any^`, `cstr`, string literal, `nullptr` and function
  value, `&x`, the text of a property (`n.hex.addr`), a pointer stepped
  with `+` or `-`, and a `?:` of pointers. Where only C's `_Generic`
  sees that a value is a pointer (`getenv("X")`), `.hex` still works,
  but `.addr` is a field there, as `.size` is: write `x as uintptr_t`.
  An array is no pointer: write `(&a[0]).addr`. Through `_Generic`,
  though, an array kelvinc cannot see (a C struct's `char` array field)
  is a pointer, so its `.hex` is its first element's address. Pointers
  have no `.dec`, `.oct` or `.bin`, and `.cstr` is as before: a string's
  own text, another pointer's `%p`-like text (`0x16ee86888`), and none
  for a function *(provisional P48)*.
- **The text lives on the caller's stack**, in a buffer sized in advance:
  for `.dec` and friends, to fit the text of any type (at most 132 bytes,
  for `.bin`); for `.cstr`, from the receiver's struct, or 64 bytes for
  one value. There is no heap and nothing to free. The text lasts until the enclosing block
  ends, also when it was made in a brace-less `for` body or among
  a method call's arguments. Do not return it from a function
  *(provisional P34)*.
- **Fields win.** A field with the same name wins, in a Kelvin struct and
  in a C struct from a header. When kelvinc cannot see whether the
  receiver is a struct, `.size`, `.type`, `.addr` and the converters
  such as `.i64` are fields (write `sizeof(x)`, `var y:x.type`,
  `x as uintptr_t` or `i64(x)` there), while `.cstr`/`.dec`/`.hex`/`.oct`/`.bin` are
  properties. `.typename` is a property also of a C struct, since C++
  reserves the word and C headers rarely name a field so (#34).
- **Errors.** `.hex` on a bool or struct, `.dec`, `.oct` or `.bin` on a
  pointer, and `.oct` or `.bin` on a float, are errors. Where kelvinc
  cannot see the type, as in `getenv("HOME").oct` or `div(7, 2).hex`,
  the C compiler reports it, naming `kv_no_such_property`.
- **Enums** follow C's types. An enumerator such as `BLUE` is an `int`,
  so `BLUE.dec` is `+2`. A variable of an enum type has the integer type
  the C compiler picks, `unsigned int` on gcc and clang when no
  enumerator is negative, so its `.dec` is `2`.
- **C bit-fields** from a header are converted first, as in
  `u32(b.flags).hex`: gcc's `_Generic` does not match a bit-field's type.

## Template literals: `` `a${x}b` ``

A template literal, between backquotes, may span lines, and each
`${expression}` in it becomes the expression's text, as `print` shows it
(#39):

```kelvin
let name:cstr := "Kelvin"
let n:i64 = 42
println(`Hello, ${name}! ${n} / 4.0 = ${n / 4.0}`)   // Hello, Kelvin! 42 / 4.0 = 10.5
let card:cstr := `name: ${name}
  answer: ${n}`
```

- **The text** is a `cstr`, typed as a string literal is, so
  `` c ? `${n} items` : `none` `` works. It lives until the enclosing
  block ends, as `.cstr` text does, and is freed then, also on `return`,
  `break` or `goto` (it is on the heap, so it may be of any length).
  Returning it is an error, and so is keeping it in a variable of an
  outer block or a global: make it in that variable's block, or copy it
  (`strdup`). Each evaluation makes the text again and frees the earlier
  one, which its values may still read, as in ``s := `${s}b` ``.
- **Values** are evaluated once each, left to right, and shown as
  `print` shows them: numbers as `println(n)` does, floats in their
  shortest form (`0.1`), `bool` as `true`/`false`, strings as their text
  (`(null)` for `nullptr`), other pointers as addresses. A struct
  kelvinc sees shows its `.cstr` text (`{x: 3, y: 4}`), which `print`
  itself does not; a function has no text. A value may be any
  expression, a template too.
- **Escapes** are C's, plus `` \` `` for a backquote, `\$`, `\{` and
  `\}` for `$`, `{` and `}` (so `\${x}` stays as written), and a
  backslash at the end of a line, which joins the lines. A new line in
  the template is a new line in the text, also in a file with CRLF line
  ends, and `"` needs no escape; text such as `??!` is taken as written,
  never as a C trigraph.
- **Without `${...}`** a template is a plain string literal, so it also
  works where C needs a constant. With one, it is made at run time, so a
  global or a `static` cannot be initialized with it *(provisional
  P50)*.

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
  `printf(fmt:const u8^, ...):i32`. Don't do both, because a
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
*(provisional P11)*, `as` (#14), and `let` and `var` (#27). `in` is a
keyword only in `for i in ...` and in an anonymous function's
`{ (a:T) in ... }`, so C names called `in` still work. It
also rejects C compiler keywords beyond C11, such as `__extension__`,
`__real__`, `__alignof__`, `typeof`, `_BitInt`, `__signed__` and `__int128`
(use `i128`), because in C they can act as casts or prefix operators
*(provisional P20)*. Names starting with `_kv_` belong to the C that
kelvinc writes, and `kv_` and `KV_` ones to its runtime, so Kelvin cannot
declare them *(provisional P44)*. kelvinc names what it writes after the source,
as in `_kv_n_text` for the text buffer of `n.hex`, `_kv_i_count` for the
counter of `for i in`, and `_kv_main_fn` for an anonymous function in
`main`; a repeat gets 1, 2, ..., and with no name to derive from, a
number from 0, as in `_kv_text0` (#38). `__asm__(...)` and `__attribute__((...))` remain
usable, and `_Pragma("...")` works as a statement. `fn` is not reserved.

## Not available yet

These are C features without a Kelvin spelling so far:

- `typedef`
- an array of functions, or a pointer to a function type: `(i64):i64[4]`
  is a function returning an array, which C rejects
- bit-fields
- unnamed parameters
- nested or local struct/union/enum definitions
- `long double`
- string prefixes (`L"..."`)
- `inline`, `restrict`, `_Alignas`, `_Static_assert`, `_Generic`
- literal suffixes (on purpose: see Literals)
- the preprocessor beyond `#import`
- statements of the form `name(x)` where `name` is a C typedef: C reads
  them as declarations, and Kelvin cannot tell (see Conversions)
- `alignof` and `typeof` (reserved C compiler keywords, P20; `v.type` is
  Kelvin's `typeof`, #34)
- `__asm__ __volatile__ (...)` (two names in a row; `__asm__(...)` works)
- `sizeof` of a typedef-based type with a suffix, such as `sizeof(FILE^)`
  (Kelvin reads `FILE^` as a dereference; `sizeof(size_t)` and `sizeof p`
  work)

## Diagnostics

The C compiler checks Kelvin programs, and `#line` directives make its
errors and warnings point at your `.k` file and line. Kelvin's own syntax
errors also carry hints for C habits, such as `*p`, `p->m`, `int x;`,
`long`, `10UL` or `(int)x`.
