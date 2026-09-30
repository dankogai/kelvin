# Kelvin design notes

## Why the name

C is the symbol for Celsius, and Kelvin succeeds it. The step size is the
same, so C's model of memory, types and cost carries over one to one, but the
scale is absolute and nothing goes below zero. The pun doubles as the design
spec:

- **Same step size.** Kelvin's primitive types, struct layout and calling
  convention are C's. A Kelvin function is a C function, and `extern fn`
  calls C directly without any binding layer.
- **Absolute scale.** No undefined behavior. Where C says "undefined",
  Kelvin either rejects the program at compile time or traps at run time
  with `file:line:col` and a message.
- **Absolute zero overhead.** No garbage collector, no hidden allocation, no
  runtime beyond a trap handler. The only extra costs are checks, and each
  check replaces a case that C leaves undefined.

## Implementation

`kelvinc` is a single-pass-per-stage compiler written in C11:

| stage     | file            | notes                                                  |
|-----------|-----------------|--------------------------------------------------------|
| lexer     | `src/lexer.c`   | nested `/* */` comments, `0x`/`0b`/`0o`, `1_000`       |
| parser    | `src/parser.c`  | recursive descent, AST in `src/kelvin.h`               |
| types     | `src/types.c`   | interned, so identical types are pointer-equal         |
| checker   | `src/sema.c`    | name resolution, type checking, C-name hygiene         |
| codegen   | `src/codegen.c` | emits C11 plus a prelude of checked-arithmetic helpers |
| runtime   | `src/runtime.c` | the trap handler, embedded as C source                 |
| driver    | `src/main.c`    | writes the C out, invokes `$CC`, optionally runs it    |

The runtime is compiled as a separate translation unit, so its `<stdio.h>`
can never clash with a program's own `extern fn printf(...)` declaration.

The generated C is compiled with `-fwrapv -fno-strict-aliasing
-fno-delete-null-pointer-checks` as a backstop. The explicit checks are the
real guarantee.

## The language today (v0.1)

### Declarations

Top-level declarations can appear in any order. There are no forward
declarations and no header files.

```kelvin
extern fn printf(fmt: *u8, ...) -> i32;   // a C function
fn add(a: i32, b: i32) -> i32 { return a + b; }
fn log(msg: *u8) { printf("%s\n", msg); } // no `->` means void
struct Point { x: i32, y: i32 }
var counter: i32 = 0;                     // mutable global
let limit = 100;                          // immutable global
```

`main` is either `fn main()`, `fn main() -> i32` or
`fn main(argc: i32, argv: **u8) -> i32`.

### Types

| Kelvin                  | C                          |
|-------------------------|----------------------------|
| `i8 i16 i32 i64`        | `int8_t` ... `int64_t`     |
| `u8 u16 u32 u64`        | `uint8_t` ... `uint64_t`   |
| `isize usize`           | `ptrdiff_t size_t`         |
| `f32 f64`               | `float double`             |
| `bool`                  | `bool`                     |
| `*T`                    | `T *`                      |
| `[N]T`                  | a struct wrapping `T[N]`   |
| `[]T`                   | `struct { T *ptr; size_t len; }` |

Types read left to right: `*[4]i32` is a pointer to an array of four i32s.

**Arrays are values.** They are assigned, passed and returned by copy, and
they never decay to pointers. `a.len` is the length.

**Slices** are pointer and length pairs, written `a[lo..hi]`, `a[lo..]`,
`a[..hi]` or `a[..]`. You can slice an array (which must be a `var`), a slice,
or a raw pointer (`p[0..n]`, where the upper bound is required). Fields are
`s.len` and `s.ptr`.

### Variables

```kelvin
let x = 5;          // immutable, type inferred (i32)
var y: u64 = 10;    // mutable
var z: [8]u8;       // zero-initialized; there are no uninitialized variables
let x = x + 1;      // shadowing is allowed
```

`let` bindings cannot be assigned, mutated through a field or element, have
their address taken, or be sliced.

### Expressions

- There are no implicit conversions between numeric types. Convert with
  `as`, as in `x as i64` or `f as i32`. Untyped literals adapt to the type
  their context expects, and a literal that does not fit is a compile error.
- Any pointer converts implicitly to `*void`, but not the other way. `null`
  converts to any pointer.
- Conditions must be `bool`, and `!` only applies to `bool`.
- Bitwise operators bind tighter than comparisons, so `x & 1 == 0` means
  `(x & 1) == 0`. Comparisons cannot be chained.
- Wrapping arithmetic is explicit: `+%`, `-%` and `*%` (plus the `+%=`
  forms).
- Assignment is a statement, not an expression, so `if x = 0` cannot be
  written. There is no `++`; write `+= 1`.
- A statement whose value is discarded must be a function call.
- Postfix operators are `f(x)`, `a[i]`, `a[i..j]` and `s.field`. Field
  access through a pointer auto-dereferences, so `p.x` works where C would
  need `p->x`.
- Other forms are `sizeof(T)`, struct literals `Point { x: 1 }` (omitted
  fields are zero), array literals `[1, 2, 3]`, character literals `'a'`,
  and adjacent string literals, which concatenate.

### Statements

`if`/`else if`/`else`, `while`, `for i in lo..hi` (half-open, and `i` is
immutable), `break`, `continue`, `return`, blocks, and `defer`.

`defer stmt;` or `defer { ... }` runs when the enclosing block exits, whether
it falls off the end or leaves through `return`, `break` or `continue`.
Deferred statements run in reverse order. A `return` value is evaluated
before the defers run. You cannot `return` from inside a defer.

## Safety: what replaces C's undefined behavior

| C undefined behavior                    | Kelvin                                      |
|-----------------------------------------|---------------------------------------------|
| signed overflow in `+ - *`              | trap (also for unsigned; use `+%` to wrap)  |
| `x / 0`, `x % 0`                        | trap                                        |
| `INT_MIN / -1`, `INT_MIN % -1`, `-INT_MIN` | trap                                     |
| shift by a negative amount or by >= width | trap                                      |
| left shift of a negative value          | defined: two's-complement bits               |
| out-of-range float-to-int conversion, NaN | trap                                      |
| array out-of-bounds access              | trap (arrays and slices)                    |
| null pointer dereference                | trap                                        |
| reading an uninitialized variable       | impossible: everything is zero-initialized  |
| falling off the end of a non-void function | trap                                     |
| `if (x = 0)` typos, `a < b < c`         | compile error                               |
| implicit narrowing and signedness conversion | compile error                          |
| strict-aliasing violations via pointer casts | disabled (`-fno-strict-aliasing`)      |

A trap prints `file:line:col: kelvin trap: <message>` to stderr, flushes
stdout, and exits with status 134. Set `KELVIN_ABORT=1` to `abort()`
instead, which gives you a core dump or a debugger stop.

## Known holes (not yet closed)

These are honest gaps between the metaphor and the implementation:

- **Raw pointers.** Indexing and slicing a raw pointer is null-checked but
  not bounds-checked. There is no lifetime tracking, so `&local` can dangle,
  and use-after-free through C's `free` is still possible.
- **Writing to string literals.** Literals are typed `*u8`, and writing
  through one is not caught. A `*const` type is needed.
- **Evaluation order.** Operands and arguments are evaluated in C's
  unspecified order. This is not undefined behavior, but it is not
  deterministic either. Kelvin should define left-to-right.
- **Data races** and anything to do with concurrency.
- **Stack overflow** from deep recursion crashes rather than trapping cleanly.
- `f32` casts of out-of-range `f64` values rely on IEEE 754 (Annex F)
  behavior.

## Roadmap

In rough order:

1. Enums and `switch`/`match` with exhaustiveness checking.
2. `const` declarations and constant expressions for array sizes.
3. Function pointers (`fn(i32) -> i32` types).
4. Modules and `import`, and C header import (`import c "stdio.h"`) to
   replace hand-written `extern fn`.
5. Optional types (`?*T`), with non-null `*T` by default.
6. Error values (`!T`) with `try`, replacing errno-style returns.
7. Defined left-to-right evaluation order.
8. `*const T`, and read-only string literals.
9. Generics, simple and monomorphized.
10. Self-hosting: rewrite `kelvinc` in Kelvin.
