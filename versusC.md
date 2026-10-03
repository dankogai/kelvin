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
| `int x = 0;` | `var x:i32 = 0;` |
| `const int k = 42;` | `let k:i32 = 42;` (#27) |
| `long n = 42;` | `var n = 42;` (inferred as `i64`) |
| `long *buf = malloc(n);` | `var buf := malloc(n):i64^;` (`:=` for references) |
| `p = q;` (pointers) | `p := q;` |
| `double d = 1.5;` | `let d = 1.5;` (inferred as `f64`) |
| `unsigned long v = 10UL;` | `var v:u64 = 10;` |
| `float f = 1.5f;` | `var f:f32 = 1.5;` |
| `1UL << 40` | `1:u64 << 40` |
| `uint16_t u = 0xdead;` | `var u = 0xdead:u16;` (inferred as `u16`) |
| `char *s;` | `var s:u8^;` or `var s:cstr;` |
| `int *a[4];` | `var a:i32^[4];` *(provisional)* |
| `int (*p)[4];` | `var p:i32[4]^;` *(provisional)* |
| `const char *const s = t;` | `let s:const u8^ := t;` |
| `long add(long a, long b) { ... }` | `add(a:i64, b:i64):i64 { ... }` (parameters are lets) |
| `void f(void);` | `f();` |
| `void *p = NULL;` | `var p:any^;` (a reference is `nullptr` until assigned) |
| `(void *)0`, `NULL` | `nullptr` |
| `static int g(void);` | `static g():i32;` |
| `int main(int argc, char **argv)` | `main(argc:i32, argv:u8^^):i32` |
| `struct p { int x, y; };` | `struct p { x:i32, y:i32; };` |
| `struct p q;`, `typedef struct p p;` | `var q:p;` (a tag is a type by its bare name, #29) |
| `*p` | `p^` |
| `**pp` | `pp^^` |
| `*p++ = *q++;` | `p^ = q^; p := p.next; q := q.next;` (no `++`, #26) |
| `i++`, `--n` | `i += 1;`, `n -= 1;` (statements) |
| `for (int i = 0; i < n; i++)` | `for i in 0..<n { ... }` (#28) |
| `for (int i = 1; i <= n; i++)` | `for i in 1...n { ... }` |
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
| `double area(struct shape s)` | `shape.area():f64 { ... self ... }`, called as `s.area()` |

## Declarations

A variable is declared with `let` or `var`, and the type follows the name
after a colon (#27):

```kelvin
let k = 42;                // a let never changes: C's const
var n:i32 = 0;             // a var may change
var buf := malloc(n):u8^;  // := for references (see References)
let a:i32 = 1, b:u8^ := p;
static var calls:i32;
```

- **`let` never changes.** `let i = 42; i += 1;` is an error, and in the
  generated C a `let` is `const`. A let pointer is fixed, but what it
  points to may change: `let p:i32^ := &x; p^ = 7;` is fine. A let array
  or struct cannot change its elements or fields. A `let` needs a value,
  except in an `extern` declaration.
- **`var` may change.** `var p:any^;` without a value is `nullptr` (#20).
- **A list** shares the keyword: `let a:i32 = 1, b:u8^ := p;` declares
  both, each with its own complete type, so C's `int a, *b` split cannot
  happen *(provisional P7)*.
- **A plain `x = 0;` assigns**, and never declares. `x:i32 = 0;` without
  `let` or `var` is an error that suggests them, and `again: n = 0;` is a
  label before a statement, as in C.
- **Functions** have no keyword. The return type follows the parameter
  list after a colon: `add(a:i64, b:i64):i64 { ... }`.
  - A prototype ends with `;` instead of a body.
  - With no `: type`, the function returns nothing (C's `void`)
    *(provisional P5)*.
  - Empty parentheses mean no parameters, i.e. C's `(void)` *(provisional P4)*.
- **Parameters** are lets unless written `var`: in `f(p:u8^)`, `p` cannot
  change, while `f(var p:u8^) { p := p.next; }` may move `p`. A method's
  `self` is a mutable copy. Parameters must be named: C's unnamed
  `f(int)` is not available yet.
- **Struct and union members** are written `name:type;`, with no
  keyword: `struct p { x:i32; y:i32; };` *(provisional P8)*.
- **A struct, union or enum is a type by its bare name** (#29), as if C
  had `typedef struct point point;`: `var p:point;`, `next:node^` inside
  `struct node`, `sizeof(point)`, `(point){1, 2}`, `c:color` for
  `enum color`. `struct point` still works too. kelvinc resolves the name
  itself and writes `struct point` in the C, so a variable or function
  may share the name; in an expression the name is that variable, from
  its own declarator on, as in C. In `sizeof(name)`, a function of the
  same name does not count (`sizeof(node)` inside a constructor `node()`
  is the struct's size). A struct from a C header has a bare name once
  Kelvin declares it, as in `struct timespec;`, but in `sizeof` write
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
`let s:u8^ := "hi";` and passing a `u8^` to `strlen` just work. kelvinc
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
imported headers work: `let f:FILE^ := stdout;` and
`let n:size_t = strlen(s);`. The same holds after `as`: `n as size_t`,
`p as FILE^`.

### Type inference

A declaration without a type, `let name = value` or `var name = value`,
infers the type from the value:

- an integer literal is `i64`: `let i = 42;`, `var m = -1;`
- a floating literal is `f64`: `let d = 1.5;`, `let e = 1e9;`
- a `bool` is `bool`: `var done = false;`, `let ok = a < b;`,
  `let both = ok && f(x);` (#24, #25), as is a `bool` variable or the
  `bool` result of a Kelvin function or method
- a value with a written type is that type: `let u = 0xdead:u16;`,
  `let u = 0xdead as u16;` and `let c = u8(300);` are all `u16`/`u8`

Anything else needs a written type, including `let y = x + 1;`,
`let s = "hi";` and a `bool` from a C function, which kelvinc cannot see
(`let ok:bool = isdigit(c) != 0;` is fine, `let ok = is_even(4);` from a
header is not). A written type is always what you get: `let b:u8 = 42;`
is a `u8`.

A declaration cannot be the body of a `for` or follow a label (as in C),
so `for (;;) var x = 1;` is an error. Names from C headers, such as
`optind`, are assigned with a plain `optind = 1;`, as in C.

## Literals

Literals carry no size or type hints. C's suffixes `u`, `l`, `ll` and `f`
(`10UL`, `10u`, `1.5f`, `1.5L`) are errors. The type belongs on the
declaration, or on the value as an annotation (`10:u64`):

| C | Kelvin |
|---|--------|
| `unsigned long v = 10UL;` | `var v:u64 = 10;` |
| `float f = 1.5f;` | `var f:f32 = 1.5;` |
| `long long n = 10LL;` | `var n = 10;` (or `var n:i64 = 10;`) |

Everything else about literals is C's: hex `0xff`, octal `017`, binary
`0b101`, exponents `1e9`, hex floats `0x1p4`, character constants `'a'`,
and adjacent strings. A literal inside an expression still has C's type, so
a bare `1` is C's `int` (an `i32`). Where C would write `1UL << 40`, Kelvin
writes `1:u64 << 40`.

## References: `:=` and `=`

Assigning a pointer (a reference) uses `:=`, and `=` is for values:

```kelvin
var buffer := malloc(8 * 1024):i64^;  // declares buffer: i64^
buffer[0] = 42;                       // a value, through the reference
var p:i32^ := &x;                     // typed declarations too
p := &y;                              // reassigning the reference
p^ = 7;                               // assigning the value it refers to
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
  `let refs:i32^[2] = {p, q};`. An array parameter, though, is a pointer,
  as in C: in `f(var a:i32[4])`, write `a := a + 1`.
- `:=` is printed as C's `=`. Like `=`, it is a statement (#26), usable
  in a `for` clause and after `let` or `var`.

## No `void`: `any^` and `nullptr`

Kelvin has no `void` type:

- **`any^` is C's `void *`.** `any` exists only behind `^`, so `any^`,
  `any^^` and `const any^` are fine, but `var p:any` is an error.
- **`nullptr` is C's `(void *)0`**, typed `any^`: `p := nullptr`, and
  `var r := nullptr` infers `any^`.
- **A reference declared without a value is `nullptr`**, so `var p:any^;`
  means `var p:any^ := nullptr`. This applies to every pointer
  declaration (`var q:i32^;`), local or global, but not to `extern` ones
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

- `size_t * p = &n;` suggests `var p:size_t^`, and `size_t n = 0;`
  suggests `var n:size_t`.
- `const u8 *s` suggests `var s:const u8^`, and `size_t a[3];` suggests
  `var a:size_t[3]`.
- `static size_t m;` suggests `static var m:size_t`, and
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
`(point){.y = 7}`, `(div_t){.quot = 3, .rem = 1}`,
`(size_t[2]){1, 2}`, `sizeof (i32[3]){1, 2, 3}` *(provisional P19)*.

## Statements

Declarations start with `let` or `var` (see Declarations), also in
`for (var i = 0; ...)`, and references take `:=` (see References).

`if`, `while` and `do` take their condition without parentheses, and
their bodies are blocks (#23):

```kelvin
if n > 0 {
    println("positive");
} else if n == 0 {
    println("zero");
} else {
    println("negative");
}
while fgets(line, line.size, stdin) != nullptr {
    print(line);
}
do {
    n -= 1;
} while n > 0;
```

- Parentheses around a condition are only grouping now: `if (n > 0) { ... }`
  still works, while C's `if (n > 0) n = 0;` is an error, since the body
  must be a block. `else` is followed by a block or by `if`.
- `switch (...)` keeps C's parentheses for now, and so does C's `for`,
  whose body may still be a single statement *(provisional P37)*. To
  count, prefer a range (see Ranges).
- `case`, `goto` and labels are C's.

## Ranges: `for i in a..<b`

`for i in a..<b { ... }` counts from `a` up to `b`, without `b`, and
`for i in a...b { ... }` up to and with `b` (#28):

```kelvin
for i in 0..<count {          // C: for (int i = 0; i < count; i++)
    println(i);
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

## Assignment is a statement

Assignment has no value in Kelvin, and `++` and `--` are gone (#26), as
in Swift:

| C | Kelvin |
|---|--------|
| `i++;`, `--n;` | `i += 1;`, `n -= 1;` |
| `*p++ = *q++;` | `p^ = q^; p := p.next; q := q.next;` |
| `a = b = 0;` | `a = 0; b = 0;` or `a = 0, b = 0;` |
| `while ((c = getchar()) != EOF) { ... }` | `var c:i32 = getchar(); while c != EOF { ...; c = getchar(); }` |
| `a[i++] = x;` | `a[i] = x; i += 1;` |

- `=`, `:=` and the compound assignments (`+=`, `~=`, ...) appear only as
  a statement of their own, or in a `for` clause. Both take a comma list,
  run left to right: `for (var i = 0, j = 10; i < j; i += 1, j -= 1)`,
  `x = 1, y = 2;` *(provisional P38)*. A list either declares, after
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
    let n:i64 = -42;
    println("n = ", n, ", half = ", n / 2.0);  // n = -42, half = -21.0
    println();                                 // just a newline
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
- Comparisons, `&&`, `||` and `!` produce a `bool` (#23), so
  `println(a == b)` prints `true` or `false`, as do `true` and `false`
  themselves *(provisional P23)*.
- `print` and `println` cannot be redefined.
- The prelude lives in `libkelvin`, which kelvinc links statically
  *(provisional P22)*. The same library works from C:
  `#include <kelvin_prelude.h>` and link `-lkelvin`.

## Methods

Every type can have methods. You define them Swift-style on a struct or
union, or on a built-in type, with an implicit `self` (passed by value):

```kelvin
struct point { x:i32; y:i32; };

point.dist2():i64 { return self.x * self.x + self.y * self.y; }
f64.half():f64 { return self / 2; }

main():i32 {
    let p:point = {3, 4};
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
  `printf(fmt:const u8^, ...):i32;`.
- **Dispatch** is chosen by the C compiler (`_Generic`), which brings these
  rules *(provisional P26)*:
  - As in C, declare a method before calling it. A prototype is
    `point.area():f64;`. A method may call itself.
  - A method call cannot appear in a global initializer.
  - Enums cannot have methods.
  - C typedef names cannot be receivers, and neither can `cstr` or `any`.
  - `x.name(...)` is a method call only if some type in the file has a
    method `name`. Otherwise it calls through a field, as in C.

## Properties: `.size`, `.cstr`, `.dec`, `.hex`, `.oct`, `.bin`

Properties are written without parentheses:

```kelvin
let c:i32 = 42;
let b:u8 = 255;
let p:point = {3, 4};
println(c.size, " ", c.cstr, " ", p.cstr);  // 4 42 {x: 3, y: 4}
println(c.dec, " ", c.hex, " ", c.bin);     // +42 +0x2a +0b101010
println(b.dec, " ", b.hex, " ", b.oct);     // 255 0xff 0o377
println(3.141592653589793.hex);             // +0x1.921fb54442d18p+1
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
  ends, also when it was made in a brace-less `for` body or among
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
  `printf(fmt:const u8^, ...):i32;`. Don't do both, because a
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
keyword only in `for i in ...`, so C names called `in` still work. It
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
