# Math: `#import <math>`

The functions of C's `math.h` for `f64` and `f32`, their constants, and complex numbers `c64` and `c32`; with `<Rational>`, `CBR`, an exact one, and the functions of a `BigRat` and of a `CBR` to any precision.

## Synopsis

```swift
#import <math>

let main():int32 {
    let i = c64(0.0, 1.0)                        // or complex64(0.0, 1.0), by the alias
    let z = c64(1.0, 2.0)
    let w = exp(z) * z + 1.0                     // operators, and exp of a c64
    println(`${w} ${abs(w)} ${sin(0.5)}`)        // sin of an f64 is C's
    println(abs(exp(i * float64.pi) + 1.0) < 1e-15)  // true: f64.pi, a constant of the type
    println(2.0.sqrt(), " ", (0.5:float32).sin(), " ", z.exp(), " ", 1.0.i)   // the methods; 1.0.i is c64(0, 1)
    return 0
}
```

## Description

`modules/math.k` (#43, #148) is `math.h` and its complex counterpart,
as C's math and cmath are: the functions of `math.h` for `f64` and
`f32`, each a method too, `x.sin()`; the constants of each type as
attributes of it, `f64.pi`; `c64` and `c32`, complex numbers with `f64`
and `f32` parts, named by the size of each part, `complex64` and
`complex32` by their aliases (#150); and `x.i`, `x` rotated a quarter
turn on the Gaussian plane.

### The functions of `math.h`

- **Each function** for an `f64` and an `f32`: `sin`, `cos`, `tan`,
  `asin`, `acos`, `atan`, `sinh`, `cosh`, `tanh`, `asinh`, `acosh`,
  `atanh`, `exp`, `exp2`, `expm1`, `log`, `log2`, `log10`, `log1p`,
  `sqrt`, `cbrt`, `floor`, `ceil`, `round`, `trunc`, `fabs`, `erf`,
  `erfc`, `tgamma`, `lgamma`, `pow`, `hypot`, `atan2`, `fmod`, `fmin`,
  `fmax`, `copysign` and `fma`.
  - Of an `f64` each is C's own, declared, so a number reaches it also
    where only C sees its type, as `tanh(atof(s))`.
  - Of an `f32` each is its `f` kind, `sinf`, so `sin(x)` of an `f32`
    gives an `f32`.
  - `abs` is of a float, `abs(-2.5)`, and of an `i64`; of an `i32` it
    is C's.
- **Each is a method too**, `x.sin()`, `x.pow(y)`, `x.atan2(y)`,
  `x.fma(y, z)`, which says which where it matters; Kelvin's
  overloading picks the one for the type anyway (#41).
  - A literal takes them, `2.0.sqrt()`, `(0.5:f32).sin()`.
- **The constants**, as attributes of the type (#133): `f64.tau`,
  `f64.e`, `f64.ln2`, `f64.ln10`, `f64.log2e`, `f64.log10e`,
  `f64.sqrt2`, `f64.epsilon`, `f64.max` and `f64.min`, and the same of
  `f32`, `f32.tau`, `f32.epsilon`.
  - `f64.pi`, `f64.infinity` and `f64.nan` were here too; they are the
    language's since #546, with no import, the same values:
    [floatingpoint.md](floatingpoint.md).
  - `f32.epsilon` is larger than `f64.epsilon`, as C's `FLT_EPSILON`
    is.
- **Tests**: `x.isnan`, `x.isinf` and `x.isfinite`; the core's
  `x.isNaN` (#382), `x.isInfinite` and `x.isFinite` (#384) need no
  import.
- **`x.i`** is `x` rotated a quarter turn: `1.0.i` is `c64(0.0, 1.0)`,
  `(0.5:f32).i` a `c32`, and `z.i` of a complex number is `z` times
  `i`, so `1.0.i.i` is `-1`.

### Complex numbers: `c64` and `c32`

- **The types**: `c64`, with `real` and `imag` of `f64`, and `c32`,
  with `f32` parts, structs: C99's `_Complex` is left out on purpose
  (#404), an error that names these; `complex64` and
  `complex32` are their aliases (#150), the same types by the size of
  the whole.
  - `c128` waits for `f128`.
- **Making one**: `c64(re, im)`, `c64(re)`, `polar(r, theta)`,
  `(c64){re, im}`, and `c64(z)` of a `c32` (or `c32(z)` of a `c64`).
- **Arithmetic**: `+ - * /` between two of one kind, or one and a real
  number of its parts' type (either way round), unary `-`, `==` and
  `!=`. `c32` and `c64` do not mix: convert one.
  - `+z` is `z`'s value, as of any type with a unary `-` (#563).
  - Each is written in `extend c64 { }` as
    `static let +(a:Self, b:Self):Self` (#135, #140), and a mixed one
    as `static let +(a:Self, b:f64):Self`.
- **Powers**: `z ** w` is `pow(z, w)` (#380), of two of one kind or one
  and a real number of its parts' type, either way round: `i ** i` is
  `{real: 0.20787957635076193, imag: 0.0}`, and `z **= 2.0` squares
  `z`.
  - It binds as Kelvin's `**` does ([operators.md](operators.md)):
    tighter than a prefix on its left, right to left.
- **The functions**: `conj`, `abs`, `arg`, `norm` (`abs` squared),
  `exp`, `log`, `sqrt`, `pow`, `sin`, `cos`, `tan`, `sinh`, `cosh`,
  `tanh` and their inverses, which take their principal values, with
  C99's branch cuts and its signs of zero on them.
  - Each is a method too, `z.exp()`, `z.abs()`, `z.pow(w)`; `z.pow`
    takes a `c64`, since a method has one form per name, and `pow(z, x)`
    a real.
  - They keep their accuracy near 0 and ±1, and no step overflows where
    the result does not.
- **The text** of one is its derived `.cstr`, as in
  `{real: 1.0, imag: 2.0}`, also in a template and in `print` (#122), and
  `z.typename` is `c64`, also through its alias.
- **`z.hex` and `z.dec`** are its parts' `.hex` and `.dec`
  ([floatingpoint.md](floatingpoint.md)) and `.i`, in parentheses, a
  `String` (#559).
  - `c64(1.5, -2.0).hex` is `(+0x1.8p+0-0x1p+1.i)`, and its `.dec`
    `(+1.5-2.0.i)`.
  - Each part's text has a sign, and the imaginary part's joins the
    two: `(+1.5+2.0.i)` of the conjugate.
    - A `nan` has none, so a `+` is written before it: `(nan+nan.i)`.
  - It pastes back as the number, a `c64`: `+1.5-2.0.i` is 1.5 less
    `2.0.i`.
    - One sign of a zero is lost so: `(-0.0+2.0.i)` reads as
      `c64(0.0, 2.0)`, since `-0.0 + 0.0` is `0.0`.
    - `inf` and `nan` are no names of Kelvin's.
  - A `c32`'s is of its `f32` parts, `(+0.100000001-2.0.i)`.
  - There is no `z.oct` or `z.bin`, as a float has none.
- C99's special values for infinities and NaNs are not attempted,
  except for `sqrt` and division by an infinity *(provisional P54)*.
- kelvinc compiles with `-ffp-contract=off`, so clang computes `a * b +
  c` with two roundings, as gcc does, and the results are the same with
  both *(provisional P55)*.

### Exact complex numbers: `CBR`, with `<Rational>`

Where a program imports `<Rational>` too, `<math>` has a complex number
of two `BigRat`s (#552), fractions of any size
([rational.md](rational.md)): every result is exact.

```swift
#import <math>
#import <Rational>

let main():int32 {
    let z = CBR(1n.over(2n), 1n.over(3n))        // or complexBigRat(...), by the alias
    println(z * z.conj(), " ", norm(z))           // {real: (13n/36n), imag: (0n/1n)} (13n/36n)
    println(1 / CBR(3, -4))                       // {real: (3n/25n), imag: (4n/25n)}
    println(abs(c64(CBR(3, -4))))                 // 5.0, by way of a c64
    return 0
}
```

- **The type**: `CBR`, with `real` and `imag` of `BigRat`, a struct;
  `complexBigRat` is its alias, as `complex64` is `c64`'s.
  - It is there with both imports alone: a program with `<math>` or
    `<Rational>` alone neither sees it nor compiles it.
  - It lives in an overlay, `modules/math+Rational.k` (#551,
    [modules.md](modules.md)).
- **Making one**: `CBR(re, im)` and `CBR(re)` of BigRats, of BigInts or
  of `i64`s, and `(CBR){re, im}` of two BigRats.
- **Arithmetic**: `+ - * /`, unary `-`, `==` and `!=`, between two, or
  one and a `BigRat`, a `BigInt` or an `i64`, either way round.
  - Nothing rounds and nothing overflows: `CBR(1, 1)` multiplied up to
    its 128th power is `2^64`, exactly.
  - `z / 0` is infinite, each part a BigRat's infinity, by an infinity
    it is 0, and `0 / 0` has NaN parts, which equal nothing, as a
    `c64`'s.
- **What stays rational**: `conj(z)` and `norm(z)`, a `BigRat`, each a
  method too; `z.i` is `z` times `i`, and `r.i` of a BigRat is
  `CBR(0, r)`.
- **What does not** takes a precision (#554), as a BigRat's functions
  do, below: `abs`, `arg`, `sqrt`, `exp`, `log`, `pow`, `sin` and the
  rest, `exp(z, 64)`, `z.sqrt()`.
  - `c64(z)` is the nearest `c64`, where 53 bits will do.
  - No `CBR` is made of a `c64`: Rational makes no fraction of a float.
- **The text** of one is its parts', as a struct's:
  `{real: (1n/2n), imag: (1n/3n)}`; each part's is a BigRat's, which
  `BigRat(text)` reads back (#565), and nothing reads the whole yet.
- **`z.hex`, `z.oct` and `z.bin`** are `(real.hex+imag.hex.i)` and its
  kin, a `String` (#559): `((+0x1n/0x2n)+(-0x1n/0x3n).i)`.
  - Each part is a BigRat's text, in its own parentheses
    ([rational.md](rational.md)), so a `+` is always between them.

### Functions of a `BigRat` and of a `CBR`, to a precision, with `<Rational>`

With `<Rational>` the functions take a `BigRat` too (#553). Few of
their values are rational, so each takes a precision, in bits, and
gives a `BigRat` that near.

```swift
#import <math>
#import <Rational>

let main():int32 {
    println(sqrt(BigRat(2), 64))                 // (26087635650665564425n/18446744073709551616n)
    println(BigRat.pi(8), " ", exp(BigRat(1), 8)) // (201n/64n) (87n/32n)
    let x = BigRat(1, 3)
    println(x.sin(16), " ", sin(x) == sin(x, 128)) // (21443n/65536n) true
    return 0
}
```

- **The precision** is a count of bits after the binary point:
  `f(x, precision)` is a fraction of `2^precision` parts, within one
  part, `2^-precision`, of the true value.
  - It is absolute: `exp(BigRat(100), 0)` is `e^100` to the nearest
    whole number, 44 digits, and a value below `2^-precision` is 0.
  - With none written it is `BigRat.precision`, 128 bits, some 38
    decimal digits; one below 0 is 0.
  - A result prints in lowest terms, so its denominator is `2^precision`
    or a lesser power of 2.
- **The functions**: `sqrt`, `exp`, `log`, `pow`, `sin`, `cos`, `tan`,
  `asin`, `acos`, `atan`, `atan2`, `sinh`, `cosh`, `tanh`, `asinh`,
  `acosh`, `atanh`, each a method too, `x.exp()`, `x.exp(64)`; and
  `BigRat.pi(precision)`, `BigRat.pi()`.
  - `pow(x, y)` of a whole `y` is the power itself, rounded, of a
    negative `x` too; else `x` is above 0.
- **An infinity and a NaN** come where a float's function gives one:
  `log(BigRat(0))` is `(-1n/0n)`, `sqrt(BigRat(-1))` is `(0n/0n)`,
  `atan` of an infinity is half of pi.
  - `exp` of `2^32` and more is an infinity: its value is past
    reckoning.
- **Of a `CBR`** (#554) they are the same, each part within
  `2^-precision` of the true value's: `sqrt`, `exp`, `log`, `pow`,
  `sin`, `cos`, `tan`, `sinh`, `cosh`, `tanh` and their inverses give a
  `CBR`, `abs` and `arg` a `BigRat`; each a method too.
  - `exp(CBR(BigRat(0), BigRat.pi(200)), 64)` is
    `{real: (-1n/1n), imag: (0n/1n)}`, Euler's, to 64 bits.
  - `pow(z, w)` of a whole real `w` is the power itself, rounded:
    `pow(CBR(1, 1), CBR(128), 0)` is `2^64`; a `BigRat` may be on
    either side.
  - The inverses take their principal values, with C99's branch cuts,
    as `c64`'s. A rational has no negative zero, so a point on a cut is
    on the side a float's `+0` is: `sqrt(CBR(-4))` is `2i`, and
    `asin(CBR(2))` has a positive imaginary part.
  - A part that is an infinity or a NaN gives NaNs, but where `exp`,
    `log`, `sqrt` and `tanh` have a limit.
- **How**: in `BigInt`s alone, a number as the integer `x * 2^w` of
  some bits more than asked, which the rounding takes off; series,
  after the argument is brought near 0.
  - No float is in it: every system gives the same bits.
  - It is not the fastest way: 16000 bits of each take a fraction of a
    second, a million would take long.

## Where it lives

`CBR` and the functions of a `BigRat` and of a `CBR` are `modules/math+Rational.k`'s, an overlay (#551), read where `<math>` and `<Rational>` are both imported. The rest is `modules/math.k`, brought in by `#import <math>`, written in Kelvin: C's own functions of `math.h` declared, overloads for `f32` and the complex types, `extend` blocks of methods and type attributes, and `typealias` (#149) for the two aliases. Nothing of it is in the prelude or the runtime; `kelvinc --lib modules/math.k` builds it into `math.kh` and `libkmath.a` where a project wants that (#146).

## Functions

<!-- fragment -->
```swift
sin(x:float64):float64, sin(x:float32):float32, sin(z:c64):c64, sin(z:c32):c32   // and so for each function above
pow(x:float64, y:float64):float64, pow(z:c64, w:c64):c64, pow(z:c64, x:float64):c64
abs(x:float64):float64, abs(x:float32):float32, abs(n:int64):int64, abs(z:c64):float64, abs(z:c32):float32
conj(z:c64):c64, arg(z:c64):float64, norm(z:c64):float64                   // and of a c32
c64(real:float64, imag:float64):c64, c64(real:float64):c64, c64(z:c32):c64, polar(r:float64, theta:float64):c64
```

With `<Rational>` (#552):

<!-- fragment -->
```swift
CBR(real:BigRat, imag:BigRat):CBR, CBR(real:BigRat):CBR                    // and of BigInts, and of i64s
c64(z:CBR):c64, conj(z:CBR):CBR, norm(z:CBR):BigRat
sin(x:BigRat):BigRat, sin(x:BigRat, precision:int64):BigRat                // and so for each function of a BigRat (#553)
sin(z:CBR):CBR, sin(z:CBR, precision:int64):CBR                            // and of a CBR (#554)
abs(z:CBR):BigRat, abs(z:CBR, precision:int64):BigRat, arg(z:CBR):BigRat, arg(z:CBR, precision:int64):BigRat
pow(z:CBR, w:CBR):CBR, pow(z:CBR, x:BigRat):CBR, pow(x:BigRat, w:CBR):CBR   // each with a precision too
pow(x:BigRat, y:BigRat):BigRat, pow(x:BigRat, y:BigRat, precision:int64):BigRat
atan2(y:BigRat, x:BigRat):BigRat, atan2(y:BigRat, x:BigRat, precision:int64):BigRat
```

## Properties and methods

| On | Property or method | Gives |
|---|---|---|
| `f64`, `f32` | `.sin()`, `.exp()`, `.sqrt()`, `.floor()`, ... | the function of `math.h`, as `x.sin()` |
| | `.pow(y)`, `.atan2(y)`, `.hypot(y)`, `.fmod(y)`, `.fmin(y)`, `.fmax(y)`, `.copysign(y)`, `.fma(y, z)` | the two- and three-argument ones |
| | `.abs()` | `fabs` |
| | `.isnan`, `.isinf`, `.isfinite` | tests, a `bool` |
| | `.i` | a `c64` or `c32`: the value rotated a quarter turn |
| `f64.`, `f32.` | `.tau`, `.e`, `.ln2`, `.ln10`, `.log2e`, `.log10e`, `.sqrt2`, `.epsilon`, `.max`, `.min` | the constants, attributes of the type; `.pi`, `.infinity` and `.nan` need no import (#546) |
| `c64`, `c32` | `.real`, `.imag` | the parts, fields |
| | `.exp()`, `.log()`, `.sqrt()`, `.sin()`, ..., `.conj()` | the function, as `z.exp()` |
| | `.abs()`, `.arg()`, `.norm()` | an `f64` or `f32` |
| | `.pow(w)` | `z` to the power `w`, a `c64` or `c32` |
| | `z ** w` | `pow(z, w)`, with a `c64`, a `c32` or a real number of its parts' type on either side (#380) |
| | `.i` | `z` times `i` |
| | `.cstr`, `${z}`, `println(z)` | `{real: 1.0, imag: 2.0}` |
| | `.hex`, `.dec` | `(+0x1.8p+0-0x1p+1.i)` and `(+1.5-2.0.i)`: its parts' texts and `.i`, a `String` (#559) |
| `CBR`, with `<Rational>` (#552) | `.real`, `.imag` | the parts, fields, each a `BigRat` |
| | `+`, `-`, `*`, `/`, prefix `-` and `+`, `==`, `!=` | exact, of two, or with a `BigRat`, a `BigInt` or an `i64` on either side |
| | `.conj()` | the conjugate, a `CBR` |
| | `.norm()` | `real² + imag²`, a `BigRat` |
| | `.i` | `z` times `i` |
| | `.cstr`, `${z}`, `println(z)` | `{real: (1n/2n), imag: (1n/3n)}` |
| | `.hex`, `.oct`, `.bin` | `((+0x1n/0x2n)+(-0x1n/0x3n).i)` and its kin, a `String` (#559) |
| | `.abs()`, `.arg()`, `.abs(p)`, `.arg(p)` | to 128 bits, or within `2^-p`, a `BigRat` (#554) |
| | `.sqrt()`, `.exp()`, `.log()`, `.sin()`, ..., `.atanh()` | the function to 128 bits, a `CBR` (#554) |
| | `.sqrt(p)`, `.exp(p)`, ..., `.pow(w)`, `.pow(w, p)` | the same, each part within `2^-p` |
| `BigRat`, with `<Rational>` (#552) | `.i` | `CBR(0, r)`: the value rotated a quarter turn |
| `BigRat`, with `<Rational>` (#553) | `.sqrt()`, `.exp()`, `.log()`, `.sin()`, ..., `.atanh()` | the function to `BigRat.precision`, 128 bits, a `BigRat` |
| | `.sqrt(p)`, `.exp(p)`, `.sin(p)`, ... | the same within `2^-p` |
| | `.pow(y)`, `.pow(y, p)`, `.atan2(x)`, `.atan2(x, p)` | the two-argument ones |
| `BigRat.` | `.pi()`, `.pi(p)` | pi to 128 bits, or within `2^-p` |
| | `.precision` | 128, the precision where none is written |
