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
    println(b.f64, " ", b.hex, " ", a < b, " ", a + 1)    // 0.5 (+0x1/+0x2) true (4/3)
    let inf = 1.over(0)                       // no division by zero: an infinity
    let nan = 0.over(0)                       // and a NaN
    println(inf, " ", -inf, " ", nan, " ", nan == nan, " ", inf.isInfinite)   // (1/0) (-1/0) (0/0) false true
    let small = rat8(1, 3)                    // of two i8s; rat16 and rat32 too
    println(small + rat8(1, 6), " ", rat8(1, 15) + rat8(1, 14), " ", rat64(small) + a)   // (1/2) (0/0) (2/3)
    var sum = bigrat(0)                       // of two BigInts: any precision
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
| `bigrat` | `struct bigrat { BigInt num, den; }`, an owner |
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
- **`bigrat`** (#540) is of two `BigInt`s, a fraction of any precision:
  every result fits, so none is a NaN for its size.
  - `1n.over(3n)` makes one, and `1n.over(3)`; so do `bigrat(n, d)` and
    `bigrat(n)`, of `BigInt`s or of integers.
  - It has `rat64`'s arithmetic, with a `BigInt` or an integer on
    either side, its comparisons, its infinities and its NaN.
  - Its text is `(1n/3n)`, its parts as a `BigInt` shows, and
    `(+0x1n/+0x3n)` its `.hex`; it is as long as its digits.
  - `r.f64` is an `f64` of any of them: `inf` or `-inf` past an `f64`'s
    range, and 0 below it.
  - It owns its `BigInt`s, as a struct that holds an owner does: a
    variable owns it, and its block frees it; see
    [bigint.md](bigint.md) and [ownership.md](ownership.md).
  - `bigrat(r)` of a `rat64` or a narrower one is the same value, and
    `rat64(r)` of a `bigrat` the way back, a NaN where it does not fit.
- **Making one:** `n.over(d)` is `(n/d)`, a method of a signed integer:
  of two `i64`s a `rat64`, of two `i32`s a `rat32`, and so on.
  - `rat64(n, d)` is the same, and `rat64(n)` is `(n/1)`; so are
    `rat8(n, d)` and its kin.
  - A literal is an `i64`, so `1.over(3)` is a `rat64`.
- **Arithmetic:** `+`, `-`, `*`, `/` and the prefix `-`, of two
  rationals of one width, and of a rational and an integer on either
  side: `a + 1`, `2 * a`, `1 / a`.
  - `+=` and its kin follow: `acc += 1.over(i)`.
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
  - They reckon as a float's do: `inf + 1` is `inf`, `inf - inf` and
    `inf * 0` are NaN, `1 / inf` is 0, and `a / 0` is an infinity.
  - A NaN equals nothing, itself included, and has no order:
    `nan == nan` is `false` and `nan != nan` is `true`.
  - `r.isNaN`, `r.isInfinite` and `r.isFinite` tell them, as a
    float's do; see [floatingpoint.md](floatingpoint.md).
- **What does not fit is a NaN:** a result whose numerator or
  denominator is past its integer, an `i64` of a `rat64`, is `(0/0)`.
  - `9223372036854775807.over(1) + 1` is a NaN, and so is
    `1.over(3) + 1.over(5000000000000000000)`, small as it is.
  - It is no error and does not round: `r.isNaN` tells.
  - A `bigrat` holds them all.
- **Text:** `(num/den)`, the sign with the numerator: `(1/3)`,
  `(-1/3)`, `(1/0)`, `(0/0)`.
  - `r.hex`, `r.oct` and `r.bin` are `(num.hex/den.hex)` and its kin:
    `(+0x1/+0x3)`.
  - Its text does not paste back: `(1/3)` written in a program is the
    integer division, 0. `1.over(3)` writes the value.
- **`r.f64`** is the nearest `f64`: 0.5 of `(1/2)`, `inf` or `-inf` of
  an infinity, `nan` of a NaN.
- **`r.num` and `r.den`** are its members, read as any struct's.

## Where it lives

A module, modules/Rational.k, a Kelvin source compiled with the program
that imports it, as [math](math.md) is; see [modules.md](modules.md).

- **In C:** `a + b` is the module's `+` of two `rat64`s, a function that
  multiplies in `__int128` and divides by the greatest common divisor;
  each width has its own. A `bigrat`'s are of `BigInt`s, the prelude's
  ([bigint.md](bigint.md)).
- **Written by a script:** tools/gen_rational.py writes the module.
  - Kelvin has no generic struct, so the four widths are one text, written
    out for each; `bigrat` is written once beside them.
  - Change the script and rerun it, not the file it writes; `make` reruns
    it when the script is the newer.
- **kc** builds a program that imports the module too (#542), and it
  prints what kelvinc's build prints.

## Properties and methods

| On | Property or method | Gives |
|---|---|---|
| `i64`, `i32`, `i16`, `i8` | `n.over(d)` | `(n/d)`, a `rat64`, `rat32`, `rat16` or `rat8`, in lowest terms (#539) |
| `rat64`, `rat32`, `rat16`, `rat8` | `rat64(n, d)`, `rat64(n)` | `(n/d)`; `(n/1)` |
| | `rat64(r)`, `rat8(r)` | `r`, a rational of another width or a `bigrat`, converted; a NaN where it does not fit (#539, #540) |
| | `.num`, `.den` | its numerator and its denominator, the denominator 0 or more |
| | `+`, `-`, `*`, `/`, prefix `-` | exact, of two of one width or with an integer; what does not fit is a NaN |
| | `==`, `!=`, `<`, `<=`, `>`, `>=` | by value; a NaN equals nothing and has no order |
| | `.isNaN`, `.isInfinite`, `.isFinite` | whether it is `(0/0)`; `(1/0)` or `(-1/0)`; neither |
| | `.f64` | the nearest `f64`; `inf`, `-inf` or `nan` |
| | `.hex`, `.oct`, `.bin` | `(num.hex/den.hex)` and its kin, a String |
| | `print(r)`, `.cstr`, `${r}` | `(num/den)` |
| `BigInt` | `n.over(d)` | `(n/d)`, a `bigrat`, of a `BigInt` or an integer `d` (#540) |
| `bigrat` | `bigrat(n, d)`, `bigrat(n)`, `bigrat(r)` | of `BigInt`s or integers; of a rational of integers |
| | `.num`, `.den` | its numerator and its denominator, `BigInt`s |
| | `+`, `-`, `*`, `/`, prefix `-`, the comparisons | as `rat64`'s, exact at any size, with a `BigInt` or an integer too |
| | `.isNaN`, `.isInfinite`, `.isFinite` | as `rat64`'s |
| | `.f64` | an `f64` of it; `inf`, `-inf`, 0 or `nan` |
| | `.hex`, `.oct`, `.bin` | `(+0x1n/+0x3n)` and its kin, a String |
| | `print(r)`, `.cstr`, `${r}` | `(1n/3n)`; `.cstr` cut at 256 bytes, as a String's |
