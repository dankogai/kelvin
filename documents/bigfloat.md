# BigFloat: `#import <BigFloat>`

A floating-point number of any precision, a `BigInt` times a power of 2: `BigFloat(1) / 3` is a third to 128 bits.

## Synopsis

```swift
#import <BigFloat>

let main():int32 {
    let third = BigFloat(1) / 3                 // to 128 bits, the nearest
    println(third.f64, " ", (third * 3).f64)    // 0.33333333333333331 1.0
    println(BigRat(third.round(8)))             // (171n/512n): at 8 bits, its value exactly
    println(BigRat(third.round(4, BigFloat.up)), " ", BigRat(third.round(4, BigFloat.down)))   // (11n/32n) (5n/16n)
    let x = BigFloat(1.5) * 3 - BigFloat(1n.over(4n))   // of an f64, an integer and a rational
    println(BigRat(x), " ", x > third, " ", x.mantissa, " ", x.exponent)   // (17n/4n) true 17n -2
    BigFloat.precision = 256                    // the bits of every result from here
    println((BigFloat(2) / 3).mantissa.bits.count - 1)   // 256
    BigFloat.precision = 128
    let inf = BigFloat(1) / 0                   // no division by zero: an infinity
    println(inf.f64, " ", (inf - inf).isNaN, " ", (inf / -2).f64)   // inf true -inf
    return 0
}
```

## Description

A `BigFloat` is a float whose mantissa is a `BigInt`: as an `f64`, but
of as many bits as a program asks. It is `#import <BigFloat>`'s (#576),
and no part of the core.

| Kelvin | C |
|--------|---|
| `BigFloat` | `struct BigFloat { BigInt mantissa; int64_t exponent; int64_t special; }`, an owner |
| `BigFloat.precision` | `BigFloat__precision`, an `int64_t`, 128 |
| `BigFloat.up` | `BigFloat__up`, a `struct RoundingRule` |

- **Its value** is `mantissa * 2^exponent`.
  - The mantissa is odd, or 0 with an exponent of 0, so a value has
    one form: `BigFloat(6)` is 3 times `2^1`.
  - `x.mantissa` and `x.exponent` are its members, read as any
    struct's.
- **Every result is rounded** to `BigFloat.precision` significant
  bits, the bits of the mantissa wherever the point is.
  - It is 128 where a program sets no other, some 38 decimal digits:
    `BigFloat.precision = 256`.
    - One below 1 is 1.
  - So of `+ - * /` and of the making of one, to the nearest, and of
    two as near to the even one, as an `f64`'s are to its 53 bits.
  - It never grows, as a `BigRat` does: a product of two of 128 bits
    has 128.
  - It is seldom exact: `BigFloat(1) / 3` is not a third, though
    `BigFloat(1) / 3 * 3` is 1, rounded.
- **Making one:** `BigFloat(n)` of an integer or a `BigInt`,
  `BigFloat(x)` of an `f64`, `BigFloat(r)` of a `BigRat`.
  - Each is the nearest of `BigFloat.precision` bits; an `f64` and an
    `i64` fit 128 exactly.
  - `BigFloat(0.1)` is the `f64`'s value, which is not a tenth;
    `BigFloat(1n.over(10n))` is a tenth to 128 bits.
  - With a precision after it, it is the nearest of that many bits:
    `BigFloat(big, 256)`, `BigFloat(1n.over(3n), 4)`.
    - So `BigFloat(1, 3)` is 1, at 3 bits: no fraction, as
      `BigRat(1, 3)` is.
- **`x.round(precision)`** is `x` at that many significant bits.
  - A number of no more bits is itself, and so are an infinity and a
    NaN.
  - `x.round(precision, rule)` rounds by one of six rules, each
    `BigFloat`'s:

    | Rule | Rounds to |
    |---|---|
    | `BigFloat.nearestEven` | the nearest, and of two as near the one whose last bit is 0: IEEE 754's, and the one where none is written |
    | `BigFloat.nearestAway` | the nearest, and of two as near the one away from 0 |
    | `BigFloat.up` | the one above, toward the greater |
    | `BigFloat.down` | the one below, toward the less |
    | `BigFloat.towardZero` | the one nearer 0 |
    | `BigFloat.awayFromZero` | the one farther from 0 |

  - A rule is a `RoundingRule`, a value: `let rule = BigFloat.up`.
- **Arithmetic:** `+`, `-`, `*`, `/`, prefix `-` and `+`, of two
  BigFloats, or of one and a `BigInt` or an integer, either way
  round.
  - An `f64` is made one first, `x * BigFloat(0.5)`, so that its
    rounding is seen.
  - `x += y` and its kin are the operators'.
- **Comparisons:** `==`, `!=`, `<`, `<=`, `>`, `>=`, by value.
- **Like an `f64`,** it has infinities and a NaN, and never divides by
  zero.
  - `x / 0` is an infinity by the sign of `x`, and `0 / 0` a NaN;
    `inf - inf` and `inf * 0` are NaNs, and `1 / inf` is 0.
  - An infinity divided has the quotient's sign, `inf / -2` is the
    negative one, and by 0 its own.
  - A NaN equals nothing, itself included, and has no order.
  - `x.isNaN`, `x.isInfinite` and `x.isFinite` tell them.
  - It has one 0, with no sign, as a rational: `BigFloat(-0.0)` is
    `BigFloat(0)`.
  - An exponent past an `i64` is an infinity, and one below it 0.
- **`x.f64`** is the nearest `f64`, of two as near the even one.
  - Past an `f64`'s range it is `inf` or `-inf`, and below it 0; a
    number below `2^-1022` has the fewer bits an `f64` has there.
- **`BigRat(x)`** is its value exactly, the mantissa over a power of
  2: `BigRat(BigFloat(0.1))` is
  `(3602879701896397n/36028797018963968n)`.
  - An infinity is `(1n/0n)` or `(-1n/0n)`, and a NaN `(0n/0n)`.
- **print** shows its members, as any struct's.

## Where it lives

A module, modules/BigFloat.k, a Kelvin source compiled with the program
that imports it, as [math](math.md) is; see [modules.md](modules.md).

- **It imports `<Rational>`,** so a program that imports it has
  `BigRat` and the rationals too ([rational.md](rational.md)).
- **In C:** `a * b` is the module's `*`, which multiplies two
  `BigInt`s, the prelude's ([bigint.md](bigint.md)), adds the
  exponents and rounds.
  - A sum shifts no farther than the precision: a number all below
    the other's last bit only tells which side of it the sum is.
  - A quotient is two bits longer than asked, with one more that says
    whether anything is left, which the rounding reads.
- **`BigFloat(x:f64)` and `x.f64`** would both be `BigFloat__f64` in
  C: the function is `_kv_fn_BigFloat__f64` (#575).
- **kc** builds a program that imports the module too, and it prints
  what kelvinc's build prints.

## Properties and methods

| On | Property or method | Gives |
|---|---|---|
| `BigFloat` | `BigFloat(n)`, `BigFloat(x)`, `BigFloat(r)` | of an `i64` or a `BigInt`, of an `f64`, of a `BigRat`: the nearest of `BigFloat.precision` bits (#576) |
| | `BigFloat(n, precision)`, `BigFloat(x, precision)`, `BigFloat(r, precision)` | the nearest of `precision` bits |
| | `BigFloat.precision` | the significant bits of every result, 128; a variable |
| | `.mantissa`, `.exponent` | its mantissa, a `BigInt`, odd or 0, and the power of 2 it is times |
| | `.round(precision)` | itself at `precision` significant bits, to the nearest and the even one |
| | `.round(precision, rule)` | by a rule |
| | `BigFloat.nearestEven`, `.nearestAway`, `.up`, `.down`, `.towardZero`, `.awayFromZero` | the six rules, each a `RoundingRule` |
| | `+`, `-`, `*`, `/`, prefix `-` and `+` | rounded to `BigFloat.precision` bits; of two, or with a `BigInt` or an integer on either side |
| | `==`, `!=`, `<`, `<=`, `>`, `>=` | by value; a NaN equals nothing and has no order |
| | `.isNaN`, `.isInfinite`, `.isFinite` | whether it is a NaN; an infinity; neither |
| | `.f64` | the nearest `f64`; `inf`, `-inf`, 0 or `nan` |
| `BigRat` | `BigRat(x)` | the value of a `BigFloat`, exactly |
