# Floating point: `f32` and `f64`

A number with a fraction: C's `float` and `double`, named by their size.

## Synopsis

<!-- fragment -->
```swift
let d = 1.5                         // an f64, inferred
var f:float32 = 1.5                     // no 1.5f: the type is on the declaration
let half = float64(n) / 2               // a converter
let x = float64("0x1.8p1")              // read from text: 3.0
println(0.1, " ", $[1.0, 0.5])      // 0.10000000000000001 [1.0, 0.5]
println(1.5.hex, " ", 3.9.int32)      // +0x1.8p0 3
println(f64.pi, " ", f64.infinity, " ", f64.ulpOfOne)   // 3.1415926535897931 inf 2.2204460492503131e-16
println(1.5.sign, " ", 1.5.exponent, " ", 1.5.significand, " ", f64(1, -1, 3))   // 1 -1 3 1.5: sign * significand * 2 ** exponent
println(f64.random(), " ", f64.random(-1.0, 1.0))       // from 0.0 up to 1.0, and from -1.0 up to 1.0
```

## Description

Kelvin's floats are C's `float` and `double`, named by their size. This
document has the types, their literals, how they convert, read from
text, print and show as text. Integers are in
[integers.md](integers.md) and `bool` in [bool.md](bool.md).

| Kelvin | C |
|--------|---|
| `f32` `f64` | `float`, `double` |
| `float32` `float64` | the same, by their full names (#151) |

- **The types:** `f32` and `f64`, also by their full names `float32`
  and `float64` (#151), the same type by another name, `var x:float64`,
  `float32(n)`, `float64.pi`.
  - C's `float` and `double` are errors that suggest the Kelvin name.
  - `long double` has no Kelvin spelling yet, and `f128` waits too.
  - C99's `_Complex` is left out on purpose (#404); Kelvin's own
    complex numbers, `c64` and `c32`, are in modules/math.k, with the
    functions of `math.h` as functions and methods, `x.sin()`, and the
    constants as attributes of the type, `f64.pi` (#148); see
    [modules.md](modules.md).
- **Literals** are C's: `1.5`, exponents `1e9`, and hex floats `0x1p4`.
  - A `_` among the digits is left out (#671), as an integer's is:
    `1_000.000_1`, `1e1_0`; see [integers.md](integers.md#literals).
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

- **Converting:** `f64(n)` and the property form `n.f64` are
  converters (#513), the nearest value: `i32(3.9)` and `3.9.i32` are 3,
  `i64(1e30)` i64's largest, `i32(NaN)` 0, `f32(1e300)` an infinity;
  `n as f64` and `n:f64` are C's conversion. The rules are in
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
  - `.dec` is the same text with a sign, `+0.10000000000000001`, `+2.0`,
    `-0.0`, and `.hex` C's `%a` with a sign, `+0x1.8p0`.
    - Each pastes back as the float: `+2.0` keeps its point (#558).
    - `.hex`'s exponent has its sign too, `+0x1.8p+1` and
      `-0x1.8p-2`, but an exponent of 0, which has none: `+0x1p0`,
      where C's `%a` writes `p+0` (#603). Both read back.
    - The text is Kelvin's own, on every system (#607), where it was
      the C library's `%a`: a subnormal is written as any other
      number, by its first 1, `5e-324.hex` is `+0x1p-1074`, as a
      `BigFloat`'s is. glibc's `%a` writes it
      `0x0.0000000000001p-1022`, which is read still.
    - A NaN has no sign: `nan`.
  - `.oct` and `.bin` of a float are errors.
  - A float inside a value shows as alone, `[11.0]`, `{x: 1.0}`,
    `some(1.0)` (#258). See [properties.md](properties.md).
- **Arithmetic** is C's, with C's promotions: an `f32` and an `f64` make
  an `f64`.
  - kelvinc compiles with `-ffp-contract=off`, so clang computes
    `a * b + c` with two roundings, as gcc does, and the results are
    the same with both.
- **`x.abs`** is the magnitude, of its type, C's `fabs` or `fabsf`
  (#381), with no import: `(-2.5).abs` is 2.5, and `(-0.0).abs` 0.0.
  - `x.abs()`, math's method, is the same.
- **`x.sign`** is -1 or 1, an `i64`, by its sign bit (#597), with no
  import: -1 for negative, 1 for positive.
  - It is the bit, so a zero and a NaN have theirs: `0.0.sign` is 1
    and `(-0.0).sign` -1.
    - An integer's is -1, 0 or 1, as it has one zero.
  - So `x.abs * x.sign as f64 == x` of any number but a NaN.
  - **`x.sign = s`** sets the bit, in the var that holds `x`:
    `x.sign = -1` makes it negative, zeros and NaN too.
    - `x.sign *= -1` flips it, and `x.sign = y.sign` is C's
      `copysign`.
    - It is set with -1 or 1: another integer written out is an error,
      a `bool` too, and one worked out ends the program, `kelvin:
      '.sign' of an f64 is -1 or 1, and this set is neither`.
  - It was a `bool?`, `none` of NaN (#383).
  - A rational and a `BigFloat` have it too, -1 or 1
    ([rational.md](rational.md), [bigfloat.md](bigfloat.md)).
- **`x.exponent`** and **`x.significand`** are the two integers `x` is
  with its sign (#598), `i64`s, with no import: `x` is `x.sign *
  x.significand * 2 ** x.exponent`.
  - The significand is odd, so a number has one form: `1.0` is 1 times
    `2^0`, `1.5` is 3 times `2^-1`, and `8.0` 1 times `2^3`.
    - `1.0.exponent` is 0, `1.5.exponent` -1, and `3.0.exponent` 0, as
      3 is odd: it is not the exponent of the leading bit.
    - A zero's are 0 and 0.
  - A `BigFloat` is the same three, its mantissa and its exponent
    ([bigfloat.md](bigfloat.md)).
  - An infinity reads as 1 times `2^0` and a NaN as 0, as a `BigFloat`
    keeps them: `x.isInfinite` and `x.isNaN` tell them.
  - Of an `f64` the significand is below `2^53` and the exponent from
    -1074 to 1023; of an `f32`, below `2^24` and from -149 to 127.
  - **`x.exponent = e`** and **`x.significand = s`** set `x`, in the
    var that holds it, to the number of its sign and the other of the
    two: `x.exponent += 1` doubles it.
    - An exponent past the greatest makes an infinity, and one below
      the least a zero.
  - They were IEEE 754's raw fields, the exponent biased, `1.0`'s 1023
    (#383).
- **`f64(sign, exponent, significand)`** makes the number of the three
  (#598), integers all: `f64(1, -1, 3)` is 1.5, and `f32(1, -1, 3)` an
  `f32`.
  - `f64(x.sign, x.exponent, x.significand)` is `x`, of any finite `x`,
    a negative zero and a subnormal too.
  - The significand need not be odd: `f64(1, 0, 6)` is 6.0. A negative
    one's sign is taken with the sign's, and a zero has the sign's,
    `f64(-1, 0, 0)` is -0.0.
  - It is the nearest number, a tie to the even one, rounded once:
    `f64(1, 0, 9007199254740993)` is 9007199254740992.0.
    - Past the greatest it is an infinity, and below the least a zero.
  - A sign that is neither -1 nor 1 makes a NaN.
  - An infinity and a NaN are `f64.infinity` and `f64.nan`.
  - `BigFloat`, `BigRat` and `rat64` are made so too
    ([bigfloat.md](bigfloat.md), [rational.md](rational.md)).
- **The others are read**: `x.abs = y`, `x.isNaN = b` and the like are
  errors that say they are worked out of the value.
- **`x.isNaN`** is whether it is NaN, a `bool` (#382), with no import:
  `(0.0 / 0.0).isNaN` is true; an integer has none.
  - `<math>`'s `x.isnan` is the same.
- **`x.isInfinite`** is whether it is `inf` or `-inf`, and
  **`x.isFinite`** whether it is neither infinite nor NaN, `bool`s, as
  Swift's (#384), with no import: `(1e308 * 10.0).isInfinite` is true.
  - `<math>`'s `x.isinf` and `x.isfinite` are the same.
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
  - Of `c64` and `c32` it is `<math>`'s `**` ([math.md](math.md)).
- **The constants of the type** (#546) are Swift's `FloatingPoint`'s,
  attributes of `f64` and of `f32`, with no import:
  - `f64.nan` and `f64.signalingNaN`, a quiet NaN and a signaling one;
    `f64.infinity`.
  - `f64.zero`, 0.0 (#596): with `.infinity` and `.nan`, the three that
    every number of the family has, a rational's and a `BigFloat`'s
    too ([rational.md](rational.md), [bigfloat.md](bigfloat.md)).
  - `f64.greatestFiniteMagnitude`, the greatest finite number, C's
    `DBL_MAX`.
  - `f64.leastNormalMagnitude`, the least normal number above 0, C's
    `DBL_MIN`, and `f64.leastNonzeroMagnitude`, the least above 0, a
    subnormal, `0x1p-1074`.
  - `f64.ulpOfOne`, the gap from 1.0 to the next number, C's
    `DBL_EPSILON`.
  - `f64.pi`; an `f32`'s is the `f32` nearest it, 3.14159274, where
    Swift's is the one below.
  - `f64.radix` is 2, an `i64`.
  - Each but `radix` is of its type, `f32.ulpOfOne` an `f32`, and each
    is a constant, which goes where one goes: a global's value, a
    `static_assert`.
  - A type attribute of your own of the name wins. math, the
    prelude's (#591), has the rest, by C's names: `f64.tau`, `f64.e`, `f64.epsilon`, `f64.max`
    and `f64.min` ([math.md](math.md)).
  - An integer type's `T.min` and `T.max` are in
    [integers.md](integers.md).
- **`T.random()`** is a number from 0.0 up to 1.0, without it (#547),
  as Swift's `T.random(in: 0..<1)`, of `f64` or of `f32`, with no
  import.
  - **`T.random(lim)`** is from 0.0 up to `lim`, and
    **`T.random(start, lim)`** from `start` up to `lim`, each without
    the limit: `f64.random(-1.0, 1.0)`.
  - The bounds are numbers, converted to the type: `f32.random(10)`.
  - An `f64`'s is one of 2^53 numbers evenly spaced, each as likely,
    and an `f32`'s one of 2^24, scaled to the bounds.
  - A start not below its limit, a NaN, or bounds too far apart to
    tell their distance, as the least and the greatest, has no number
    to give, and ends the program, said.
  - The bits are the system's, with no seed, as an integer type's
    are: [integers.md](integers.md).

## Where it lives

The core. `f32` and `f64` are kelvinc's own, written as C's types, with nothing linked. Their text (`.cstr`, `.dec`, `.hex`), printing them, and reading them from text (`f64("1.5")`) are the prelude's, `libkelvin`, linked without an import. Complex numbers of Kelvin's own come with `#import <math>`.

## Properties and methods

| On | Property | Gives |
|---|---|---|
| `f32.`, `f64.` | `.nan`, `.signalingNaN`, `.infinity`, `.pi` | the type's constants, of the type, with no import (#546) |
| | `.zero` | 0.0, of the type (#596) |
| | `.greatestFiniteMagnitude`, `.leastNormalMagnitude`, `.leastNonzeroMagnitude`, `.ulpOfOne` | its limits and the gap at 1.0, of the type (#546) |
| | `.radix` | 2, an `i64` (#546) |
| | `T.random()` | a number from 0.0 up to 1.0, without it, by the system's random bits (#547) |
| | `T.random(lim)`, `T.random(start, lim)` | from 0.0, or from `start`, up to `lim`, without it (#547) |
| `f32`, `f64` | `.size` | `sizeof`, a `size_t` |
| | `.align` | `alignof` of its type, a `size_t` (#395) |
| | `.type`, `.typename` | the type, where a type goes; its name as text |
| | `.cstr` | the text `print` shows, every digit with a point, `1.0`, `0.10000000000000001` (#258, #259), in the block's buffer |
| | `.dec`, `.hex` | its text, `+2.0`, and its hex float, as C's `%a`, each with a sign; `.hex`'s exponent has its sign, but of 0, `+0x1p0` (#603), and a subnormal's is by its first 1, `+0x1p-1074` (#607) |
| | `x ** y` | C's `pow` or `powf`, the operands converted as `*` converts them (#380) |
| | `.abs` | the magnitude, `fabs` or `fabsf`, of its type (#381) |
| | `.sign` | -1 or 1, an `i64`, by its sign bit: a zero's and a NaN's too (#597) |
| | `.sign = s` | sets the sign bit, with -1 or 1 (#383, #597) |
| | `.exponent`, `.exponent = e` | the power of 2 its significand is times, an `i64`, read and set (#598) |
| | `.significand`, `.significand = s` | the odd integer it is times that power, 0 of a zero, an `i64`, read and set (#598) |
| | `f64(sign, exponent, significand)`, `f32(...)` | `sign * significand * 2 ** exponent`, of three integers, the nearest; a NaN where the sign is neither -1 nor 1 (#598) |
| | `.isNaN` | whether it is NaN, a `bool` (#382) |
| | `.isInfinite`, `.isFinite` | whether it is `inf` or `-inf`; whether it is neither infinite nor NaN, `bool`s (#384) |
| | `.i8` ... `.u64`, `.f32`, `.f64`, `.bool` | a conversion, `i64(v)` written after the value |
| text | `.f64`, `.f32` | read a number from text, `f64("1.5")` |

The details are in [properties.md](properties.md).
