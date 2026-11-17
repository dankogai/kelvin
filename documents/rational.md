# Rational numbers: `#import <Rational>`

A numerator over a denominator, each a signed integer or a `BigInt`:
`1.over(3)` is `(1/3)`.

## Synopsis

```swift
#import <Rational>

let main():int32 {
    let a = 1.over(3)                         // a rat64: (1/3)
    let b = a + 1.over(6)                     // (1/2), in lowest terms
    println(a, " ", b, " ", a * b, " ", a / b, " ", -a)   // (1/3) (1/2) (1/6) (2/3) (-1/3)
    println(b.f64, " ", b.hex, " ", a < b, " ", a + 1)    // 0.5 (+0x1/0x2) true (4/3)
    let inf = 1.over(0)                       // no division by zero: an infinity
    let nan = 0.over(0)                       // and a NaN
    println(inf, " ", -inf, " ", nan, " ", nan == nan, " ", inf.isInfinite)   // (1/0) (-1/0) (0/0) false true
    let small = rat8(1, 3)                    // of two i8s; rat16 and rat32 too
    println(small + rat8(1, 6), " ", rat8(1, 15) + rat8(1, 14), " ", rat64(small) + a)   // (1/2) (0/0) (2/3)
    println(rat64("8/-12"), " ", rat64(b.hex, 16), " ", BigRat("(-2n/3n)"))   // (-2/3) (1/2) (-2n/3n): of its text
    println(rat64("1.5"), " ", rat64("2.5/1.5"), " ", rat64("0.1"), " ", rat64("5x"))   // (3/2) (5/3) (1/10) (0/0): read exactly, and all of it
    var sum = BigRat(0)                       // of two BigInts: any precision
    for i in 1...30 { sum = sum + 1n.over(i) }
    println(sum, " ", sum.f64)                // (9304682830147n/2329089562800n) 3.994987130920391
    return 0
}
```

## Description

A rational number is a fraction of two integers, exact where a
floating-point number rounds: `1.over(3) + 1.over(6)` is `(1/2)`. It is
`#import <Rational>`'s (#538), and no part of the core.

| Kelvin | C |
|--------|---|
| `rat64` | `struct rat64 { int64_t num, den; }` |
| `rat32`, `rat16`, `rat8` | the same of `int32_t`, `int16_t` and `int8_t` |
| `BigRat` | `struct BigRat { BigInt num, den; }`, an owner |
| `1.over(3)` | `(struct rat64){1, 3}`, in lowest terms |

- **`rat64`** is a struct of two `i64`s, `num` and `den`.
  - It is kept in lowest terms, its denominator 0 or more: `2.over(4)`
    is `(1/2)`, and `3.over(-6)` is `(-1/2)`.
  - 0 is `(0/1)`, and a whole number `n` is `(n/1)`.
- **`rat32`, `rat16` and `rat8`** (#539) are the same of two `i32`s,
  `i16`s and `i8`s, with the same arithmetic, comparisons and text.
  - They are small: a `rat8` holds no denominator past 127, so
    `rat8(1, 15) + rat8(1, 14)`, 29/210, is a NaN. `rat64` is the one
    of use.
  - **Only signed integers** are a rational's parts, a bit of the
    denominator unused: an unsigned integer has no `.over`.
- **`BigRat`** (#540) is of two `BigInt`s, a fraction of any precision:
  every result fits, so none is a NaN for its size.
  - `1n.over(3n)` makes one, and `1n.over(3)`; so do `BigRat(n, d)` and
    `BigRat(n)`, of `BigInt`s or of integers.
  - It has `rat64`'s arithmetic, with a `BigInt` or an integer on
    either side, its comparisons, its infinities and its NaN.
  - Its text is `(1n/3n)`, its parts as a `BigInt` shows, and
    `(+0x1n/0x3n)` its `.hex`; it is as long as its digits.
    `BigRat(text)` reads it back (#565).
  - `r.f64` is an `f64` of any of them: `inf` or `-inf` past an `f64`'s
    range, and 0 below it.
  - It owns its `BigInt`s, as a struct that holds an owner does: a
    variable owns it, and its block frees it; see
    [bigint.md](bigint.md) and [ownership.md](ownership.md).
  - `BigRat(r)` of a `rat64` or a narrower one is the same value, and
    `rat64(r)` of a `BigRat` the way back, a NaN where it does not fit.
- **Making one:** `n.over(d)` is `(n/d)`, a method of a signed integer:
  of two `i64`s a `rat64`, of two `i32`s a `rat32`, and so on.
  - `rat64(n, d)` is the same, and `rat64(n)` is `(n/1)`; so are
    `rat8(n, d)` and its kin.
  - A literal is an `i64`, so `1.over(3)` is a `rat64`.
- **Arithmetic:** `+`, `-`, `*`, `/` and the prefix `-`, of two
  rationals of one width, and of a rational and an integer on either
  side: `a + 1`, `2 * a`, `1 / a`.
  - `+=` and its kin follow: `acc += 1.over(i)`.
  - `+a`, the prefix, is `a`'s value, as of any type with a unary `-`
    (#563); of a `BigRat` variable it is a new one.
  - The result is exact, reckoned in 128 bits and brought to lowest
    terms.
- **Comparing:** `==`, `!=`, `<`, `<=`, `>` and `>=`, by value.
- **Two widths do not mix:** `rat8(1, 3) + rat32(1, 6)` is an error.
  - `rat64(r)`, `rat32(r)`, `rat16(r)` and `rat8(r)` of a rational of
    another width convert it: the same value where it fits, and a NaN
    where the narrower does not hold it.
- **Like a floating-point number,** which a rational can also stand
  for, it has infinities and a NaN, and never divides by zero.
  - A denominator of 0 is an infinity: `1.over(0)` is `(1/0)`, and
    `(-7).over(0)` is `(-1/0)`.
  - `0.over(0)` is `(0/0)`, a NaN.
  - `rat64.infinity` and `rat64.nan` are those two, and `rat64.zero`
    is `(0/1)` (#596), as `f64` has the three: of each width, and
    `BigRat.zero`, `BigRat.infinity` and `BigRat.nan` of a `BigRat`.
    - A `BigRat`'s is a new one at each read, the reader's own, as it
      owns its two `BigInt`s (#595).
    - The other infinity is `-rat64.infinity`.
  - `r.sign` is -1 or 1, an `i64`, as a floating-point number's (#597):
    -1 where `r` is negative, `(-1/0)` too, and 1 of all else, as a
    rational has one 0 and one NaN, with no sign.
  - They reckon as a float's do: `inf + 1` is `inf`, `inf - inf` and
    `inf * 0` are NaN, `1 / inf` is 0, and `a / 0` is an infinity.
  - An infinity divided has the quotient's sign (#574): `inf / -2`
    is `(-1/0)` and `-inf / -2` is `(1/0)`.
    - So of every width and of a `BigRat`, by a rational or an
      integer, and of `r /= d`.
    - By an infinity it is a NaN, and by 0 itself, `inf / 0` is
      `(1/0)`: a rational's 0 has no sign.
  - A NaN equals nothing, itself included, and has no order:
    `nan == nan` is `false` and `nan != nan` is `true`.
  - `r.isNaN`, `r.isInfinite` and `r.isFinite` tell them, as a
    float's do; see [floatingpoint.md](floatingpoint.md).
- **What does not fit is a NaN:** a result whose numerator or
  denominator is past its integer, an `i64` of a `rat64`, is `(0/0)`.
  - `9223372036854775807.over(1) + 1` is a NaN, and so is
    `1.over(3) + 1.over(5000000000000000000)`, small as it is.
  - It is no error and does not round: `r.isNaN` tells.
  - A `BigRat` holds them all.
- **Text:** `(num/den)`, the sign with the numerator: `(1/3)`,
  `(-1/3)`, `(1/0)`, `(0/0)`.
  - `r.hex`, `r.oct` and `r.bin` are `(num.hex/den.hex)` and its kin:
    `(+0x1/0x3)`.
    - The sign is the numerator's alone: the denominator, 0 or more,
      has none (#565).
  - `r.string` is the text, a String; print and `.cstr` show it.
- **From text** (#565): the type reads its own text back, so
  `rat64("(1/3)")` is `(1/3)`, as `i64("42")` is 42.
  - `rat64("8/-12")` is `(-2/3)`: a sign on either part, and the
    value in lowest terms, as `rat64(8, -12)` is.
  - Spaces and a `(` may come first, and a `)` ends what a `(`
    began; a whole number may end in a `BigInt`'s `n`; with no `/`
    the denominator is 1, so `rat64("5")` is `(5/1)`.
  - A part is a number as an `f64`'s text is written, read exactly
    (#568):
    - A point: `rat64("1.5")` is `(3/2)`, `rat64("2.5/1.5")` is
      `(5/3)`, and `rat64("0.1")` is `(1/10)`, which no `f64` holds.
    - An exponent, in base 10: `rat64("1.5e-3")` is `(3/2000)`.
    - Nothing is rounded: `rat64("9007199254740993")` is that
      integer, and a `BigRat` reads digits without end.
  - `rat64(text, base)` reads in a base from 2 to 36:
    `rat64(r.hex, 16)`, `rat64(r.oct, 8)` and `rat64(r.bin, 2)` are
    `r`.
    - A point is read in any base: `rat64("0x1.8", 16)` is `(3/2)`.
    - An exponent is base 10's alone, as `e` is a digit of base 16:
      `rat64("1e3", 16)` is `(483/1)`.
  - The text is a `cstr`, or a `String` by reference, `rat64(&s)`.
  - `"1/0"` is an infinity and `"0/0"` a NaN; a part that does not
    fit the width makes a NaN, as elsewhere.
  - Text that is no rational is an error, and gives a NaN, `(0/0)`:
    - With no number: `rat64("abc")` and `rat64("")` (#567).
    - With more than a number: `rat64("5x")` and `rat64("1/2/3")`
      (#568). All of the text is read; spaces may end it.
    - With a `/` and a part left out: `rat64("1/")` and
      `rat64("/3")`. The denominator is left out only with its `/`,
      as in `rat64("1")`, `(1/1)`.
  - `BigRat(text)` and `BigRat(text, base)` are the same, of any
    size: `BigRat("8/-12")` is `(-2n/3n)`.
  - Written in a program, `(1/3)` is the integer division, 0:
    `1.over(3)` writes the value there.
- **`r.f64`** is the nearest `f64`: 0.5 of `(1/2)`, `inf` or `-inf` of
  an infinity, `nan` of a NaN.
- **`r.num` and `r.den`** are its members, read as any struct's.
- **With `<BigNum>`** (#590, [bignum.md](bignum.md)) a program has
  `CBR` too (#552), a complex number of two BigRats, and `r.i` of a
  BigRat is `CBR(0, r)`: see [bignum.md](bignum.md).
  - And math's functions take a BigRat (#553), each to a precision in
    bits: `sqrt(BigRat(2), 64)`, `x.exp()`, `BigRat.pi(256)`.
  - And `BigFloat(r)` is the nearest float of 128 bits (#576), and
    `BigRat(x)` a BigFloat's value exactly: see
    [bigfloat.md](bigfloat.md).
  - `<Rational>` alone has none of these: a `BigRat` and its
    arithmetic, exact, and no function of math. They came with
    `<math>` beside it before, by an overlay (#551).

## Where it lives

A module, modules/Rational.k, a Kelvin source compiled with the program
that imports it; see [modules.md](modules.md).

- **In C:** `a + b` is the module's `+` of two `rat64`s, a function that
  multiplies in `__int128` and divides by the greatest common divisor;
  each width has its own. A `BigRat`'s are of `BigInt`s, the prelude's
  ([bigint.md](bigint.md)).
- **Written by a script:** tools/gen_rational.py writes the module.
  - Kelvin has no generic struct, so the four widths are one text, written
    out for each; `BigRat` is written once beside them.
  - Change the script and rerun it, not the file it writes; `make` reruns
    it when the script is the newer.
- **kc** builds a program that imports the module too (#542), and it
  prints what kelvinc's build prints.

## Properties and methods

| On | Property or method | Gives |
|---|---|---|
| `i64`, `i32`, `i16`, `i8` | `n.over(d)` | `(n/d)`, a `rat64`, `rat32`, `rat16` or `rat8`, in lowest terms (#539) |
| `rat64`, `rat32`, `rat16`, `rat8` | `rat64(n, d)`, `rat64(n)` | `(n/d)`; `(n/1)` |
| | `rat64(r)`, `rat8(r)` | `r`, a rational of another width or a `BigRat`, converted; a NaN where it does not fit (#539, #540) |
| | `rat64(text)`, `rat64(text, base)` | of its text, `"8/-12"`, `"(-2/3)"`, `r.hex` with 16; a `cstr` or a `String` by reference; a part may have a point, `"1.5"`, `"2.5/1.5"`, and in base 10 an exponent, `"1.5e-3"`, read exactly; `"abc"`, `""`, `"5x"`, `"1/"` and `"/3"` are NaNs (#565, #567, #568) |
| | `.num`, `.den` | its numerator and its denominator, the denominator 0 or more |
| | `+`, `-`, `*`, `/`, prefix `-` and `+` (#563) | exact, of two of one width or with an integer; what does not fit is a NaN; an infinity by a negative number is the other infinity, `(1/0) / -2` is `(-1/0)` (#574) |
| | `==`, `!=`, `<`, `<=`, `>`, `>=` | by value; a NaN equals nothing and has no order |
| | `.isNaN`, `.isInfinite`, `.isFinite` | whether it is `(0/0)`; `(1/0)` or `(-1/0)`; neither |
| | `rat64.zero`, `rat64.infinity`, `rat64.nan` | `(0/1)`, `(1/0)` and `(0/0)`, of each width (#596) |
| | `.sign` | -1 where it is negative, else 1, an `i64` (#597) |
| | `.f64` | the nearest `f64`; `inf`, `-inf` or `nan` |
| | `.hex`, `.oct`, `.bin` | `(num.hex/den.hex)` and its kin, a String; the denominator has no sign (#565) |
| | `print(r)`, `.cstr`, `${r}`, `.string` | `(num/den)`; `.string` a String (#565) |
| `BigInt` | `n.over(d)` | `(n/d)`, a `BigRat`, of a `BigInt` or an integer `d` (#540) |
| `BigRat` | `BigRat(n, d)`, `BigRat(n)`, `BigRat(r)` | of `BigInt`s or integers; of a rational of integers |
| | `BigRat(text)`, `BigRat(text, base)` | of its text, `"8/-12"`, `"(-2n/3n)"`, `"0.1"`, `r.hex` with 16; text that is no rational is a NaN (#565, #567, #568) |
| | `.num`, `.den` | its numerator and its denominator, `BigInt`s |
| | `+`, `-`, `*`, `/`, prefix `-` and `+`, the comparisons | as `rat64`'s, exact at any size, with a `BigInt` or an integer too; `BigRat(1, 0) / BigRat(-2)` is `(-1n/0n)` (#574) |
| | `.isNaN`, `.isInfinite`, `.isFinite` | as `rat64`'s |
| | `BigRat.zero`, `BigRat.infinity`, `BigRat.nan` | `(0n/1n)`, `(1n/0n)` and `(0n/0n)`, a new one at each read (#596) |
| | `.sign` | as `rat64`'s (#597) |
| | `.f64` | an `f64` of it; `inf`, `-inf`, 0 or `nan` |
| | `.hex`, `.oct`, `.bin` | `(+0x1n/0x3n)` and its kin, a String |
| | `print(r)`, `.cstr`, `${r}` | `(1n/3n)`; `.cstr` cut at 256 bytes, as a String's |
| | `.i`, with `<BigNum>` (#552) | `CBR(0, r)`, a complex number of two BigRats ([bignum.md](bignum.md)) |
| | `.sqrt()`, `.exp(p)`, `.sin()`, ..., with `<BigNum>` (#553) | math's functions, within `2^-p`, or to 128 bits ([bignum.md](bignum.md)) |
