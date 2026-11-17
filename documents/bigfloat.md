# BigFloat: `#import <BigNum>`

A floating-point number of any precision, a `BigInt` times a power of 2: `BigFloat(1) / 3` is a third to 128 bits, `0.333333333333333333333333333333333333334`.

## Synopsis

```swift
#import <BigNum>

let main():int32 {
    let third = BigFloat(1) / 3                 // to 128 bits, the nearest
    println(third, " ", third * 3)              // 0.333333333333333333333333333333333333334 1.0
    println(third.round(8), " ", BigRat(third.round(8)))   // 0.333984375 (171n/512n): at 8 bits, and its value exactly
    println(third.round(4, BigFloat.up), " ", third.round(4, BigFloat.down))   // 0.34375 0.3125
    let x = BigFloat(1.5) * 3 - BigFloat(1n.over(4n))   // of an f64, an integer and a rational
    println(x, " ", x > third, " ", x.mantissa, " ", x.exponent, " ", x.hex)   // 4.25 true 17n -2 +0x1.1p+2
    println(BigFloat("0.1"), " ", BigFloat(0.1), " ", BigFloat("0.1") + BigFloat("0.2"))   // 0.1 0.100000000000000005551115123125782702118 0.3
    BigFloat.precision = 256                    // the bits of every result from here
    println(BigFloat(2) / 3)                    // 0.66666666666666666666666666666666666666666666666666666666666666666666666666667
    BigFloat.precision = 128
    let inf = BigFloat(1) / 0                   // no division by zero: an infinity
    println(inf, " ", inf - inf, " ", inf / -2, " ", third.f64)   // inf nan -inf 0.33333333333333331
    return 0
}
```

## Description

A `BigFloat` is a float whose mantissa is a `BigInt`: as an `f64`, but
of as many bits as a program asks. It is `#import <BigNum>`'s (#576,
#590, [bignum.md](bignum.md)), and no part of the core.

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
- **math's functions** take a `BigFloat` (#580): `sqrt`,
  `exp`, `log`, `pow`, the trigonometric and hyperbolic ones and their
  inverses, each a method too, and `BigFloat.pi()`: see
  [bignum.md](bignum.md).
  - A result has `BigFloat.precision` significant bits, whatever its
    size, or the precision written: `exp(x, 256)`, `x.sin(64)`.
  - A number far from 1 is taken as any (#583): `cos` of
    `2^-1000000000000` is 1, and `atan` of `2^1000000000000` half of
    pi.
  - They come with it, by the one import (#590); they were an
    overlay's before, read where `<math>` was imported too.
  - And `CBF`, `complexBigFloat` by its alias, is a complex number of
    two BigFloats (#581), as a `c64` is of two `f64`s: `CBF(1, 2) /
    CBF(3, 4)` is `(0.44+0.08.i)`.
    - Each part of `+ - * /` is the exact one's, rounded once to
      `BigFloat.precision` bits.
    - `x.i` is `CBF(0, x)`.
    - math's functions take a `CBF` too (#582), `exp(z)`, `abs(z)`,
      each part to `BigFloat.precision` significant bits.
- **Its text** (#577) is the fewest digits that read back:
  `BigFloat("0.1")` prints `0.1`, and `BigFloat(1) / 3`
  `0.333333333333333333333333333333333333334`, 39 digits.
  - `BigFloat(text)` of it is the number again, at
    `BigFloat.precision` bits: no shorter decimal rounds to it, and of
    the shortest it is the nearest.
    - So `BigFloat(0.1)`, an f64's tenth, prints
      `0.100000000000000005551115123125782702118` at 128 bits, and
      `0.1` where the precision is 53.
    - A number of more bits than the precision, made when it was
      greater, has the digits of its own count of bits:
      `BigFloat(text, bits)` reads it back.
  - It is laid out as an `f64`'s ([floatingpoint.md](floatingpoint.md)):
    plain from 0.0001 up to `2^precision`, where every integer is
    exact, with a point, `1.0`, `100000000000000000000.0`; and with an
    exponent otherwise, `1e+40`, `1.234e-05`.
    - `inf`, `-inf` and `nan` are an `f64`'s.
  - A number far from 1 has its text as soon as any (#584):
    `BigFloat("0x1p-1000000000000")` prints
    `1.044250726930468202952436781310171121576e-301029995664`.
    - Up to the largest exponent there is: `2^9223372036854775807`
      is `6.90466148990027132480002997655809470257e+2776511644261678565`.
    - And it reads back, as any.
  - It is `x.string`, a String (#506), so `` `${x}` `` and `x.cstr`
    give it, and a member, an element and an Optional's value show it:
    `{name: "t", x: 0.1}`, `[1.5, 0.1, inf]`, `some(2.5)`.
  - **`x.dec`** is the same with a sign, `+0.1`, and **`x.hex`** C's
    `%a` with a sign, `+0x1.8p+0`: the bits after the first as hex
    digits, and the power of 2 of the first, its value exactly, of any
    length.
- **`BigFloat(text)`** reads one, all of the text, blanks at its ends
  aside; text that is none is a NaN, `BigFloat("1.5x")`.
  - A decimal, with a point and an exponent, read exactly and then
    rounded: `"0.1"`, `"-.5"`, `"1.5e-3"`.
    - And what else a `BigRat` is read from
      ([rational.md](rational.md)): `BigFloat("1/3")` is a third to
      128 bits.
    - An exponent far from 0 is read as soon as any (#584):
      `BigFloat("1e1000000000")` is the nearest to it still, and
      `BigFloat("1e1000000000/3")` to a third of it.
      - A decimal past the largest exponent is an infinity,
        `BigFloat("1e2777000000000000000")`, and one below the
        least 0.
  - A hex float, C's: `"0x1.8p+1"` is 3, `"0x.8"` a half; so
    `BigFloat(x.hex)` is `x`.
  - `"inf"` and `"nan"`, with a sign or none.
  - `BigFloat(text, precision)` rounds to that many bits; the text is
    a `cstr`, or a `String` by reference, `BigFloat(&s)`.

## Where it lives

A part of the module modules/BigNum.k (#590, [bignum.md](bignum.md)),
a Kelvin source compiled with the program that imports it, as
`Rational` is; see [modules.md](modules.md). It was a module of its
own before, modules/BigFloat.k, `#import <BigFloat>`.

- **`<BigNum>` imports `<Rational>`** and `<math>`, so a program that
  imports it has `BigRat`, the rationals and math's own too
  ([rational.md](rational.md)).
- **Its text** is reckoned in rationals, exact: what rounds to a
  number lies between the halves of the gaps to its neighbours, and
  the fewest digits with a decimal between them are found by halving.
  - A decimal is read by `<Rational>`'s reader.
  - A number far from 1 is no rational (#584), which would be as long
    as its exponent is large: past `2^(8 * bits + 256)`, or as far
    below 1, its text is reckoned in whole numbers.
    - The number and the two ends are divided by a power of 10, of
      `5^k` cut to the bits that tell, with 64 below the point.
    - So far out no decimal that is tried is the number, an end, or
      midway between two: where one is too near to tell, the bits are
      added to until it is told.
  - A decimal whose power of 10 is far from 0 is read so too: between
    the product by `5^k` cut and by what that is below, and with more
    bits where the two round apart.
    - No such decimal is a number of the precision, nor midway
      between two.
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
| | `BigFloat(text)`, `BigFloat(text, precision)` | of its text, `"0.1"`, `"1.5e-3"`, `"1/3"`, `"0x1.8p+1"`, `"inf"`, `"nan"`; a `cstr` or a `String` by reference; text that is none is a NaN (#577) |
| | `BigFloat.precision` | the significant bits of every result, 128; a variable |
| | `.mantissa`, `.exponent` | its mantissa, a `BigInt`, odd or 0, and the power of 2 it is times |
| | `.round(precision)` | itself at `precision` significant bits, to the nearest and the even one |
| | `.round(precision, rule)` | by a rule |
| | `BigFloat.nearestEven`, `.nearestAway`, `.up`, `.down`, `.towardZero`, `.awayFromZero` | the six rules, each a `RoundingRule` |
| | `+`, `-`, `*`, `/`, prefix `-` and `+` | rounded to `BigFloat.precision` bits; of two, or with a `BigInt` or an integer on either side |
| | `==`, `!=`, `<`, `<=`, `>`, `>=` | by value; a NaN equals nothing and has no order |
| | `.isNaN`, `.isInfinite`, `.isFinite` | whether it is a NaN; an infinity; neither |
| | `.f64` | the nearest `f64`; `inf`, `-inf`, 0 or `nan` |
| | `print(x)`, `.cstr`, `${x}`, `.string` | the fewest digits that `BigFloat(text)` reads back, `0.1`; `.string` a String (#577) |
| | `.dec`, `.hex` | the same with a sign, `+0.1`, and C's `%a` with a sign, `+0x1.8p+0`, exact; each a String |
| | `.sqrt()`, `.exp()`, `.log()`, `.sin()`, ..., `.atanh()` (#580) | the function to `BigFloat.precision` significant bits; `.exp(p)` to `p` |
| | `.pow(y)`, `.pow(y, p)`, `.atan2(x)`, `.atan2(x, p)` | the two-argument ones |
| | `BigFloat.pi()`, `BigFloat.pi(p)` | pi to `BigFloat.precision` bits, or to `p` |
| | `.i` (#581) | `CBF(0, x)`, a complex number of two BigFloats: the value rotated a quarter turn ([bignum.md](bignum.md)) |
| `BigRat` | `BigRat(x)` | the value of a `BigFloat`, exactly |
