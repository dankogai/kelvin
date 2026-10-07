# Grammar: declarations, expressions and statements

Kelvin keeps C's grammar where it can. This document has what changed in
the shape of a program: how things are declared, how a type is inferred,
the operators that moved, and how lines end statements. The types
themselves are in [integers.md](integers.md), [pointers.md](pointers.md)
and [arrays.md](arrays.md); the statements that control flow are in
[flow-controls.md](flow-controls.md).

## Declarations

A variable is declared with `let` or `var`, and the type follows the name
after a colon (#27):

```kelvin
let k = 42                 // a let never changes: C's const
var n:i32 = 0              // a var may change
var buf := malloc(n):u8^   // := for references (see pointers.md)
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
- **Storage classes** go in front: `static let f():i32`, `static var n:i32`,
  `extern var e:i32` *(provisional P9)*.
- There is no C-style declaration. `int x;` is an error, and so is `int`
  itself (see [integers.md](integers.md)).

- **Functions** are declared with `let` (#45), as a value that never
  changes is; methods and operators too. See [functions.md](functions.md).
- **Struct and union members** are written `name: type`, and a struct,
  union or enum is a type by its bare name (#29). See
  [structs.md](structs.md) and [unions.md](unions.md).

### Qualifiers

`const` and `volatile` apply to whatever is on their left. A leading
qualifier applies to the base type, which is C's own rule
*(provisional P6)*. `u8 const^` and `const u8^` are both `const uint8_t *`,
and `u8^ const` is `uint8_t *const`.

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
- an array literal is an array of its items' type (#48), as
  [arrays.md](arrays.md) says
- any other value whose type kelvinc sees is that type (#47): a Kelvin
  function's or method's result (`var z = complex64(0.0, 1.0)`,
  `let n = p.norm()`), a variable (`var q = p`), a field, `p^`, `a[i]`,
  `&x` (`let r := &q`, which points to `const` when `q` is a let), a
  compound literal, a text property (`let s := n.cstr` is a `u8^`), a
  template, an enumerator (its enum), a character (`u8`), `sizeof`
  (`size_t`), and a `?:` between two values of one type. An array is not
  copied, so `let ap := arr` is the pointer C makes of it.

Anything else needs a written type: arithmetic (`let y = x + 1`), whose
type is C's promotion of its operands (`small + 1` is an `i32`, not an
`i8`); `let s = "hi"`; `.size` and `.addr`; and any value only C sees,
such as a C function's result (`let n = strlen(s)`), a macro, or a
`bool` from a C function (`let ok:bool = isdigit(c) != 0` is fine,
`let ok = is_even(4)` from a header is not). A written type is always
what you get: `let b:u8 = 42` is a `u8`.

A declaration cannot be the body of a `for` or follow a label (as in C),
so `for (;;) var x = 1` is an error. Names from C headers, such as
`optind`, are assigned with a plain `optind = 1`, as in C.

## Expressions

| C | Kelvin | Note |
|---|--------|------|
| `*p` | `p^` | Postfix, so it chains left to right: `p^[i]` is `(*p)[i]` |
| `p->m` | `p^.m` | `->` is an error with a hint |
| `a ^ b` | `a ~ b` | `~` keeps its C precedence slot for XOR |
| `a ^= b` | `a ~= b` | `p^ = x` is always an assignment through `p` |
| `~a` | `~a` | Unary `~` is still bitwise NOT |
| `(int)x` | `i32(x)` or `x as i32` | See [integers.md](integers.md) |

Everything else is C's, including precedence, so `6 & 3 == 3` is still
`6 & (3 == 3)`. The same goes for integer promotion, implicit conversions,
`?:`, `,`, compound literals and designated initializers, except that
conditions are `bool` (see [flow-controls.md](flow-controls.md)), assignment
is a statement and so are `p++` and `p--`, for pointers only (below).

### Lines end statements; one expression is the result

As in Swift, a `;` may be left out at the end of a line (#35):

```kelvin
let total:i64 = price
    * count               // goes on: price * count
println(total)
(p as i64^)^ = 1          // a new statement
let a = 1; let b = 2      // ; between statements on one line
let square(x:i64):i64 { x * x }
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
  anonymous function does: `let square(x:i64):i64 { x * x }`. There, an
  assignment, or a call kelvinc sees has no value such as `println`, is
  an error. `main` is the exception: its end returns 0 as in C, so its
  one expression is a statement, and `let main():i32 { printf("hi\n") }`
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

## Assignment is a statement

Assignment has no value in Kelvin, as in Swift, and `++` and `--` are
statements too, for pointers only (#26, #51):

| C | Kelvin |
|---|--------|
| `i++;`, `--n;` | `i += 1`, `n -= 1` |
| `p++;`, `p--;` (pointers) | `p++`, `p--`, or `p := p.next` |
| `*p++ = *q++;` | `p^ = q^; p++; q++` |
| `a = b = 0;` | `a = 0; b = 0` or `a = 0, b = 0` |
| `while ((c = getchar()) != EOF) { ... }` | `var c:i32 = getchar(); while c != EOF { ...; c = getchar() }` |
| `a[i++] = x;` | `a[i] = x; i += 1` |

- `=`, `:=`, the compound assignments (`+=`, `~=`, ...) and `p++`
  appear only as a statement of their own, or in a `for` clause. Both take a comma list,
  run left to right: `for (var i = 0, j = 10; i < j; i += 1, j -= 1)`,
  `x = 1, y = 2` *(provisional P38)*. A list either declares, after
  `let` or `var`, or assigns.
- So nothing can be changed inside `[...]`, a condition or an argument,
  except by a function call.
## C habits kelvinc catches

C-style declarations at the start of a statement get the Kelvin spelling as
a hint:

- `size_t * p = &n;` suggests `var p:size_t^`, and `size_t n = 0;`
  suggests `var n:size_t`.
- `const u8 *s` suggests `var s:const u8^`, and `size_t a[3];` suggests
  `var a:[size_t](3)`.
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

