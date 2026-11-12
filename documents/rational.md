# Rational numbers: `#import <Rational>`

A numerator over a denominator, each an integer: `1.over(3)` is `(1/3)`.

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
| `1.over(3)` | `(struct rat64){1, 3}`, in lowest terms |

- **`rat64`** is a struct of two `i64`s, `num` and `den`.
  - It is kept in lowest terms, its denominator 0 or more: `2.over(4)`
    is `(1/2)`, and `3.over(-6)` is `(-1/2)`.
  - 0 is `(0/1)`, and a whole number `n` is `(n/1)`.
- **Making one:** `n.over(d)` of two `i64`s is `(n/d)`, a method of an
  integer.
  - `rat64(n, d)` is the same, and `rat64(n)` is `(n/1)`.
  - A literal is an `i64`, so `1.over(3)` is a `rat64`.
- **Arithmetic:** `+`, `-`, `*`, `/` and the prefix `-`, of two
  rationals, and of a rational and an integer on either side:
  `a + 1`, `2 * a`, `1 / a`.
  - `+=` and its kin follow: `acc += 1.over(i)`.
  - The result is exact, reckoned in 128 bits and brought to lowest
    terms.
- **Comparing:** `==`, `!=`, `<`, `<=`, `>` and `>=`, by value.
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
  denominator is past an `i64` is `(0/0)`.
  - `9223372036854775807.over(1) + 1` is a NaN, and so is
    `1.over(3) + 1.over(5000000000000000000)`, small as it is.
  - It is no error and does not round: `r.isNaN` tells.
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
  multiplies in `__int128` and divides by the greatest common divisor.
- **kc** does not read the module yet: a method of an integer and a
  module's source are past its subset.

## Properties and methods

| On | Property or method | Gives |
|---|---|---|
| integer | `n.over(d)` | `(n/d)`, a `rat64` of two `i64`s, in lowest terms |
| `rat64` | `rat64(n, d)`, `rat64(n)` | `(n/d)`; `(n/1)` |
| | `.num`, `.den` | its numerator and its denominator, the denominator 0 or more |
| | `+`, `-`, `*`, `/`, prefix `-` | exact, of two or with an integer; what does not fit is a NaN |
| | `==`, `!=`, `<`, `<=`, `>`, `>=` | by value; a NaN equals nothing and has no order |
| | `.isNaN`, `.isInfinite`, `.isFinite` | whether it is `(0/0)`; `(1/0)` or `(-1/0)`; neither |
| | `.f64` | the nearest `f64`; `inf`, `-inf` or `nan` |
| | `.hex`, `.oct`, `.bin` | `(num.hex/den.hex)` and its kin, a String |
| | `print(r)`, `.cstr`, `${r}` | `(num/den)` |
