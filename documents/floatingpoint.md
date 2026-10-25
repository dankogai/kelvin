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
  - **`nan` and `inf`** are literals of `f64` too (#261), in any case,
    `inf` also `infinity`: `$/nan/i` and `$/inf(inity)?/i`. So what
    `print` shows of a NaN or an infinity, `nan`, `-inf`, reads back.
    - `nan:f32` converts one, as `(0.0 / 0.0) as f32` does.
    - A name the program declares is its own, `var inf = 2`; `nan(...)`
      is C's function; `Self.infinity` a member.

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
- **`x.abs`** is the magnitude, of its type, C's `fabs` or `fabsf`
  (#381), with no import: `(-2.5).abs` is 2.5, and `(-0.0).abs` 0.0.
  - With `<math>`, `x.abs()`, its method, is the same.
- **`x.sign`** is a `bool?`, by its sign bit (#382, #383), with no
  import: `true` for positive, `false` for negative, `none` of NaN.
  - So `0.0.sign` is `some(true)` and `(-0.0).sign` `some(false)`;
    `x.sign ?? true` reads it as a `bool`.
  - **`x.sign = b`** sets the bit, a `bool`, in the var that holds `x`:
    `x.sign = false` makes it negative, zeros and NaN too; `x.sign =
    none` is an error.
- **`x.exponent`** and **`x.significand`** are IEEE 754's two other
  fields of its bits, as `i64`s (#383), with no import.
  - The exponent is biased, as stored: 0 to 2047 of an `f64`, 0 to 255
    of an `f32`, `1.0.exponent` 1023.
  - The significand is the fraction's bits, without the leading 1: 0 to
    2^52 - 1 of an `f64`, 0 to 2^23 - 1 of an `f32`, `1.5.significand`
    2^51.
  - With the sign they make the bits, every one: 0 for zeros and
    subnormals, the most for infinities and NaN.
  - **`x.exponent = e`** and **`x.significand = s`** set them, in the
    var that holds `x`, as `x += e` sets it: `x.exponent += 1` doubles
    a normal `x`.
  - A value outside its field is an error, written so, and ends the
    program otherwise: `kelvin: '.exponent' of an f64 is 0 to 2047, and
    this set is past it`.
- **The others are read**: `x.abs = y` and `x.isNaN = b` are errors that
  say they are worked out of the value.
- **`x.isNaN`** is whether it is NaN, a `bool` (#382), with no import:
  `(0.0 / 0.0).isNaN` is true; an integer has none.
  - `<math>`'s `x.isnan` is the same.
- **`x ** y`** is C's `pow`, where either is a floating-point number
  (#380), with no import: `2.0 ** 0.5` is 1.4142135623730951, and
  `2.0 ** -1` 0.5.
  - The operands convert as `*` converts them: an `f64` where either is
    one, or a floating-point literal, so `powf` only where each is an
    `f32` or an integer, `f ** 3` of an `f32` an `f32`.
  - It binds tighter than a prefix on its left and groups right to
    left, as Python's: `-x ** 2` is `-(x ** 2)`. See
    [operators.md](operators.md).
  - Two literals are worked out by kelvinc, with C's `pow`, so a
    global's value may be one, `let root2:f64 = 2.0 ** 0.5`.
  - `x **= y` is `x = x ** y`.
  - Of C's `_Complex` it is `cpow`; of `c64` and `c32`, `<math>`'s
    `**` ([math.md](math.md)).

## Properties and methods

| On | Property | Gives |
|---|---|---|
| `f32`, `f64` | `.size` | `sizeof`, a `size_t` |
| | `.type`, `.typename` | the type, where a type goes; its name as text |
| | `.cstr` | the text `print` shows, every digit with a point, `1.0`, `0.10000000000000001` (#258, #259), in the block's buffer |
| | `.dec`, `.hex` | `%+.17g` and C's `%a`, each with a sign |
| | `x ** y` | C's `pow` or `powf`, the operands converted as `*` converts them (#380) |
| | `.abs` | the magnitude, `fabs` or `fabsf`, of its type (#381) |
| | `.sign` | a `bool?` by its sign bit: `true` positive, `false` negative, `none` of NaN (#382, #383) |
| | `.sign = b` | sets the sign bit, a `bool` (#383) |
| | `.exponent`, `.exponent = e` | the biased exponent field, an `i64`, 0...2047 or 0...255, read and set (#383) |
| | `.significand`, `.significand = s` | the fraction's bits, an `i64`, 0...2^52 - 1 or 0...2^23 - 1, read and set (#383) |
| | `.isNaN` | whether it is NaN, a `bool` (#382) |
| | `.i8` ... `.u64`, `.f32`, `.f64`, `.bool` | a conversion, `i64(v)` written after the value |
| text | `.f64`, `.f32` | read a number from text, `f64("1.5")` |

The details are in [properties.md](properties.md).
