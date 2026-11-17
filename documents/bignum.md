# BigNum: `#import <BigNum>`

The numbers of any size, in one library: `BigFloat`, a float of any precision, `CBR` and `CBF`, complex numbers of two `BigRat`s and of two `BigFloat`s, and math's functions of a `BigRat`, a `CBR`, a `BigFloat` and a `CBF`.

## Synopsis

```swift
#import <BigNum>

let main():int32 {
    let x = BigFloat(1) / 3                      // a third, to 128 bits
    println(x, " ", sqrt(BigFloat(2)))           // 0.333333333333333333333333333333333333334 1.41421356237309504880168872420969807857
    println(CBF(1, 2) / CBF(3, 4), " ", abs(CBF(3, 4)))   // (0.44+0.08.i) 5.0
    let z = CBR(1n.over(2n), 1n.over(3n))        // of two BigRats, exact
    println(z * z, " ", sqrt(1n.over(4n)), " ", BigRat.pi(16))   // ((5n/36n)+(1n/3n).i) (1n/2n) (205887n/65536n)
    println(sqrt(2.0), " ", rat64(1, 3) + rat64(1, 6))   // 1.4142135623730951 (1/2): math's and Rational's come with it
    return 0
}
```

## Description

`<BigNum>` (#590) is the one import of the numbers that have no fixed
size. It is built on `BigInt`, the prelude's
([bigint.md](bigint.md)), on [math](math.md), and on `BigRat`, which
is `<Rational>`'s ([rational.md](rational.md)).

- **What it has**, each described where it was before:
  - `BigFloat` (#576), a floating-point number whose mantissa is a
    `BigInt`, rounded to `BigFloat.precision` significant bits:
    [bigfloat.md](bigfloat.md).
  - `CBR` (#552), `complexBigRat` by its alias, a complex number of
    two `BigRat`s, exact in `+ - * /`: [math.md](math.md).
  - `CBF` (#581), `complexBigFloat` by its alias, a complex number of
    two `BigFloat`s: [math.md](math.md).
  - math's functions, `sqrt`, `exp`, `log`, `pow`, the trigonometric
    and hyperbolic ones and their inverses, of a `BigRat` (#553), a
    `CBR` (#554), a `BigFloat` (#580) and a `CBF` (#582), each to a
    precision, and each a method too: [math.md](math.md).
- **What it imports** is the program's too: `<math>`, with the
  functions of an `f64` and `c64`, and `<Rational>`, with `rat64` and
  down and `BigRat`.
  - A program that writes `#import <math>` or `#import <Rational>`
    beside it has them once.
- **`<Rational>` alone** is as it was: `rat64`, `rat32`, `rat16` and
  `rat8`, and `BigRat` with its exact arithmetic.
  - It has no `CBR` and no function of math: those are `<BigNum>`'s.
  - With `<math>` beside it there are none either, where there were
    before #590, by an overlay.
- **The names of the types stay**: `BigFloat`, `CBF`, `CBR`,
  `complexBigFloat` and `complexBigRat` are what they were. It is the
  import that is renamed.
- **`#import <BigFloat>` is no more**: it is an error that says to
  write `#import <BigNum>`.

## Where it lives

A module, modules/BigNum.k, a Kelvin source compiled with the program
that imports it, as [math](math.md) and `Rational` are; see
[modules.md](modules.md).

- **Three files before #590**, which are its three parts, in the
  order one uses another:
  - `math+Rational.k`, an overlay (#551), read where `<math>` and
    `<Rational>` were both imported: `CBR`, and math's functions of a
    `BigRat` and of a `CBR`.
  - `BigFloat.k`, `#import <BigFloat>`: the type.
  - `math+BigFloat.k`, an overlay (#580), read where `<math>` and
    `<BigFloat>` were both imported: math's functions of a
    `BigFloat`, `CBF`, and its functions.
- **Overlays** are read as before ([modules.md](modules.md)); Kelvin's
  own modules have none now.
- **kc** builds a program that imports the module too, and it prints
  what kelvinc's build prints.

## Properties and methods

| On | Property or method | Gives |
|---|---|---|
| `BigFloat` | all of [bigfloat.md](bigfloat.md)'s | a float of any precision |
| `CBR`, `CBF` | all of [math.md](math.md)'s | complex numbers of two `BigRat`s and of two `BigFloat`s |
| `BigRat`, `CBR`, `BigFloat`, `CBF` | `sqrt(x)`, `x.exp()`, `sin(x, precision)`, ... | math's functions, in [math.md](math.md) |
| `BigRat` | all of [rational.md](rational.md)'s | by `<Rational>`, which it imports |
