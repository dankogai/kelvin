# Printing: `print`, `println` and template literals

`print` and `println` come from the prelude, with no import, and show a
value by its type; a template literal joins text and values the same
way. This document has both. The text of a single value, `n.cstr`, is in
[properties.md](properties.md), and C strings in
[strings.md](strings.md).

**Where it lives:** the prelude. `print`, `println` and the text a template makes are `libkelvin`'s, declared by `kelvin_prelude.h` and linked without an import.

## The prelude: `print` and `println`

Every Kelvin program can use `print` and `println` without an import:

```kelvin
let main():i32 {
    let n:i64 = -42
    println("n = ", n, ", half = ", n / 2.0)   // n = -42, half = -21.0
    println()                                  // just a newline
    return 0
}
```

- `print(a, b, ...)` prints up to 16 values with no separators (a 17th
  is an error that says to write two calls), and
  `println(...)` adds a newline.
- Each value prints according to its C type *(provisional P21)*:
  - integers of every size in decimal, so `i64` needs no `PRId64`
  - floats in the shortest text that reads back the same, always with a
    `.` or an exponent
    - As in Swift, they are plain from 0.0001 up to 2^53 (2^24 for
      `f32`), where every integer is exact (`10.0`, `0.1`,
      `9007199254740992.0`), and have an exponent otherwise (`1e+16`,
      `1e-05`, `1e+300`).
    - The point is `.` whatever the C locale's, which `printf` would
      follow
  - `bool` as `true`/`false`
  - `u8^` and string literals as strings (`(null)` for a null pointer)
  - other pointers as addresses
  - a struct, a union, an enum with values, an Optional, a Result, an
    `Array`, a `Dictionary` and a `Set` whole, on one line (#122, #123):
    see [Values whole](#values-whole-print-and-pretty) below
- Comparisons, `&&`, `||` and `!` produce a `bool` (#23), so
  `println(a == b)` prints `true` or `false`, as do `true` and `false`
  themselves *(provisional P23)*.
- `print` and `println` cannot be redefined.
- **`f.print(...)`** and **`f.println(...)`** (#83) show the same values
  the same way to an IO, a file or `IO.stderr`; see [io.md](io.md).
- The prelude lives in `libkelvin`, which kelvinc links statically
  *(provisional P22)*. The same library works from C:
  `#include <kelvin_prelude.h>` and link `-lkelvin`, both in Kelvin's
  `modules/` (#46).

## Values whole: `print` and `.pretty`

`print` and `println` show a value with brackets whole, on one line, and
`v.pretty` shows it indented, a line for each item (#123, #124):

```kelvin
struct point { x: i64; y: i64 }
var xs = $[1, 2, 3]
var ages = ${"ann": 31, "bob": 42}
var p:point = {1, 2}
var r:Result<point, String> = err($"bad")
println(xs, " ", ages, " ", p, " ", r)   // [1, 2, 3] {"ann": 31, "bob": 42} {x: 1, y: 2} err("bad")
println(ages.pretty)                     // {
                                         //   "ann": 31,
                                         //   "bob": 42
                                         // }
var text = ages.pretty                   // a String, where print does not show it
```

- **The text** of each kind:
  - A struct is `{x: 1, y: 2}`, the derived text, or the type's own
    `T.cstr()` where it defines one (#53).
  - An enum with values is `n(v)` or `none`; an Optional `some(v)` or
    `none`; a Result `ok(v)` or `err(e)`.
  - An `Array` is `[a, b]`, a `Dictionary` `{"k": v}` and a `Set`
    `{a, b}`, in the order added; an empty one `[]` or `{}`.
  - A union is `<union name>`, an IO `<IO>`.
- **Text inside a value is quoted** (#123): a `String`, a `Bytes` or a
  `cstr` there is `"text"`, escaped as `\"`, `\\`, `\n`, `\r`, `\t`,
  and other control characters as `\u00XX`.
  - A `Bytes` shows each byte past ASCII as `\xNN`, so the text stays
    UTF-8.
  - A value on its own is not quoted: `println(s)` of a String is its
    text.
  - The same quoting is in `.cstr` and in a template's `${v}`.
- **`print` shows everything**, at any length and depth, by a printer
  kelvinc writes for each type; `.cstr` and `${v}` are cut to their
  room, and show an Array inside a struct as `[...]`.
- **`v.pretty`** (#124) is the same text indented: each item of a `[]`
  or `{}` on a line of its own, two spaces a level.
  - A case's `()` holds one value and stays on its line; what it holds
    breaks if it is a `[]` or a `{}`: `some({` ... `})`.
  - An empty `[]` or `{}` stays as it is, and a type's own `T.cstr()`
    is its text on one line.
  - Where `print`, `println` or `f.println` shows it, it is printed
    where it stands.
  - Elsewhere it is a `String`, bound as any owner is:
    `var text = cfg.pretty`.
  - It is of a struct, an enum with values, an Optional, a Result, an
    Array, a Dictionary or a Set; a number's or a String's text is
    `.cstr`.
- **An owner an expression gives** is not printed, since nothing would
  free it: bind it first, as `var xs = make(); println(xs)`.
- **A template** shows an Array, a Dictionary or a Set by the same
  printer (#125): `${xs}` is `[1, 2, 3]`.
  - In `` `...` ``, whose room is bounded, its text is cut as a string
    value's is, past 256 bytes, with `...`.
  - In `` $`...` ``, a String, it is whole.
  - One that an expression gives is bound first, as for `print`.

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
  `` c ? `${n} items` : `none` `` works.
  - It is kept without the heap, in a buffer at the top of the
    enclosing block, as `.cstr` text is, and lives until the block ends
    (#44).
  - Returning it is an error, and so is keeping it in a variable of an
    outer block or a global: make it in that variable's block, or copy
    it (`strdup`).
  - Each evaluation makes the text again in the same buffer, and its
    values may still read the earlier text, as in ``s := `${s}b` ``; a
    pointer kept from an earlier evaluation shows the newest text.
- **Room** for each value's longest text is made in advance, so
  numbers, bools, addresses, a struct's text, the number properties
  (`.dec`, `.hex`, `.oct`, `.bin`, `.size`, `.addr`), string literals and
  nested templates are shown whole.
  - A byte array (`[u8](16)`) is read up to a NUL or its end, never
    past it, and shown whole up to 256 bytes.
  - Other strings (`.cstr` of a string too), and values only C sees,
    show at most 256 bytes: a longer one shows its first 253 and `...`,
    and ``s := `${s}b` `` stops growing at 257 *(provisional P56)*.
    - `KELVIN_CFLAGS=-DKV_TEMPLATE_STR=4096` raises the limit (it is at
      least 64); for longer text, use `print` or C's `snprintf`.
    - Each such value takes that much stack, twice while its text is
      built, which counts in a deep recursion; a struct's text, three
      times.
- **`` $`a${x}b` ``** (#67) builds the same text as a `String` on the
  heap, with no bound on its length: each value's text is appended as it
  comes, a String's whole, a `uchr` as its character.
  - It is an owner, so bind it to a variable (`var s = $`...``), which
    frees it when its block ends; see [strings.md](strings.md).
- **Values** are evaluated once each, left to right, and shown as
  `print` shows them: numbers as `println(n)` does, floats in their
  shortest form (`0.1`), `bool` as `true`/`false`, strings as their text
  (`(null)` for `nullptr`), other pointers as addresses.
  - A struct kelvinc sees shows its `.cstr` text (`{x: 3, y: 4}`), as
    `print` does (#122); one it cannot see, as a call that C chooses
    among overloads with different results, is a C error, so assign it
    to a variable first.
  - A function has no text.
  - A value may be any expression, a template too.
- **Escapes** are C's, plus `` \` `` for a backquote, `\$`, `\{` and
  `\}` for `$`, `{` and `}` (so `\${x}` stays as written), and a
  backslash at the end of a line, which joins the lines.
  - A new line in the template is a new line in the text, also in a
    file with CRLF line ends, and `"` needs no escape; text such as
    `??!` is taken as written, never as a C trigraph.
  - The other ways to quote text, `"..."`, `"""..."""` as written, and
    the `$` forms, are in [grammar.md](grammar.md#quoting-text).
- **Without `${...}`** a template is a plain string literal, so it also
  works where C needs a constant.
  - With one, it is made at run time, so a global or a `static` cannot
    be initialized with it *(provisional P50)*.
