# Floating point: `f32` and `f64`

Kelvin's floats are C's `float` and `double`, named by their size. This
document has the types, their literals, how they convert, read from
text, print and show as text. Integers are in
[integers.md](integers.md) and `bool` in [bool.md](bool.md).

**Where it lives:** the core. `f32` and `f64` are kelvinc's own, written as C's types, with nothing linked. Their text (`.cstr`, `.dec`, `.hex`), printing them, and reading them from text (`f64("1.5")`) are the prelude's, `libkelvin`, linked without an import. Complex numbers of Kelvin's own come with `#import <math>`.

<!-- fragment -->
```swift
let d = 1.5                         // an f64, inferred
var f:float32 = 1.5                     // no 1.5f: the type is on the declaration
let half = float64(n) / 2               // a converter, as C's cast
let x = float64("0x1.8p1")              // read from text: 3.0
println(0.1, " ", $[1.0, 0.5])      // 0.10000000000000001 [1.0, 0.5]
println(1.5.hex, " ", 3.9.int32)      // +0x1.8p+0 3
```

| Kelvin | C |
|--------|---|
| `f32` `f64` | `float`, `double` |
| `float32` `float64` | the same, by their full names (#151) |
| `f32 _Complex` `f64 _Complex` | C's complex types |

- **The types:** `f32` and `f64`, also by their full names `float32`
  and `float64` (#151), the same type by another name, `var x:float64`,
  `float32(n)`, `float64.pi`.
  - C's `float` and `double` are errors that suggest the Kelvin name.
  - `long double` has no Kelvin spelling yet, and `f128` waits too.
  - `f32 _Complex` and `f64 _Complex` are C's complex types; Kelvin's
    own `c64` and `c32` are in modules/math.k, with the
    functions of `math.h` as functions and methods, `x.sin()`, and the
    constants as attributes of the type, `f64.pi` (#148); see
    [modules.md](modules.md).
- **Literals** are C's: `1.5`, exponents `1e9`, and hex floats `0x1p4`.
  - C's suffixes `f` and `L` (`1.5f`, `1.5L`) are errors. The type
    belongs on the declaration, or on the value as an annotation:
    `var f:f32 = 1.5`, `1.5:f32`.
  - A floating literal is an `f64`: `let d = 1.5`, `let e = 1e9`; see
    [grammar.md](grammar.md).

| C | Kelvin |
|---|--------|
| `float f = 1.5f;` | `var f:f32 = 1.5` |

- **Converting** is C's cast: `f64(n)`, `n as f64`, `n:f64`, and the
  property form `n.f64`; `i32(3.9)` and `3.9.i32` are 3. The rules are in
  [integers.md](integers.md#conversions-no-c-casts).
- **From text**, a converter reads the number as C's `strtod` and
  `strtof` read it (#36): `f64("1.5")`, `"1.5".f64`, and hex floats,
  `f64("0x1.8p1")` is 3.0, so `f64(x.hex)` is `x`.
  - Out of range is an infinity, and `errno` is `ERANGE` also when the
    result is tiny.
  - The decimal point is the one of the C locale in use.
  - A base is for integer types only. The table of what is read is in
    [integers.md](integers.md#numbers-from-text).
- **Printing:** `print` shows every digit the type holds, as `%.17g`
  does for an `f64` and `%.9g` for an `f32`, always with a `.` or an
  exponent (#259): what the value is, `0.1` being
  `0.10000000000000001`, `+0x1.999999999999ap-4`.
  - Trailing zeros go: `1.0`, `2.5`, not `2.5000000000000000`.
  - As in Swift, it is plain from 0.0001 up to 2^53 (2^24 for `f32`),
    where every integer is exact (`10.0`, `9007199254740992.0`), and
    has an exponent otherwise (`1e+16`, `1.0000000000000001e-05`).
  - The point is `.` whatever the C locale's, which `printf` would
    follow. See [printing.md](printing.md).
- **Text** is what `print` shows (#258, #259): every digit, with a
  point, `0.10000000000000001`, `1.0`, so that it pastes back into
  Kelvin as the value.
  - `.cstr`, `${x}` and `print` agree, and so does a float inside a
    value: a struct's member, an Array's element, an Optional's value.
  - `.dec` is the same digits with a sign, `+0.10000000000000001`, and
    `.hex` C's `%a` with a sign, `+0x1.8p+0`.
  - `.oct` and `.bin` of a float are errors.
  - A float inside a value shows as alone, `[11.0]`, `{x: 1.0}`,
    `some(1.0)` (#258). See [properties.md](properties.md).
- **Arithmetic** is C's, with C's promotions: an `f32` and an `f64` make
  an `f64`.
  - kelvinc compiles with `-ffp-contract=off`, so clang computes
    `a * b + c` with two roundings, as gcc does, and the results are
    the same with both *(provisional P55)*.

## Properties and methods

| On | Property | Gives |
|---|---|---|
| `f32`, `f64` | `.size` | `sizeof`, a `size_t` |
| | `.type`, `.typename` | the type, where a type goes; its name as text |
| | `.cstr` | the text `print` shows, every digit with a point, `1.0`, `0.10000000000000001` (#258, #259), in the block's buffer |
| | `.dec`, `.hex` | `%+.17g` and C's `%a`, each with a sign |
| | `.i8` ... `.u64`, `.f32`, `.f64`, `.bool` | a conversion, `i64(v)` written after the value |
| text | `.f64`, `.f32` | read a number from text, `f64("1.5")` |

The details are in [properties.md](properties.md).
