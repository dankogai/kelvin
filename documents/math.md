# Math: `#import <math>`

The functions of C's `math.h` for `f64` and `f32`, their constants, and complex numbers `c64` and `c32`; with `<Rational>`, `CBR`, an exact one, and the functions of a `BigRat` and of a `CBR` to any precision; with `<BigFloat>`, the functions of a `BigFloat`, `CBF`, a complex number of two, and the functions of a `CBF`.

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
  `(c64){re, im}`, and `c64(z)` of a `c32` (or `c32(z)` of a `c64`);
  `c64(text)` of its text, below.
- **Arithmetic**: `+ - * /` between two of one kind, or one and a real
  number of its parts' type (either way round), unary `-`, `==` and
  `!=`. `c32` and `c64` do not mix: convert one.
  - `+z` is `z`'s value, as of any type with a unary `-` (#563).
  - Each is written in `extend c64 { }` as
    `static let +(a:Self, b:Self):Self` (#135, #140), and a mixed one
    as `static let +(a:Self, b:f64):Self`.
- **Powers**: `z ** w` is `pow(z, w)` (#380), of two of one kind or one
  and a real number of its parts' type, either way round: `i ** i` is
  `(0.20787957635076193+0.0.i)`, and `z **= 2.0` squares
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
- **The text** of one is `(a+b.i)` (#570): `print` writes
  `c64(1.5, -2.0)` as `(1.5-2.0.i)`, and so do a template, `${z}`, and
  `z.cstr`.
  - Each part is as `print` writes a float
    ([floatingpoint.md](floatingpoint.md)), and the imaginary part's
    sign joins the two: `(1.5+2.0.i)` of the conjugate.
    - A `nan` has no sign, so a `+` is written before it:
      `(nan+nan.i)`; an infinity has its own, `(inf-inf.i)`.
  - Both parts are always written, a zero with its sign:
    `(1.5+0.0.i)`, `(0.0+2.0.i)`, `(1.5-0.0.i)`, `(-0.0+2.0.i)`, and
    `(-0.0-0.0.i)` of two negative zeros.
  - A `c32`'s is of its `f32` parts, `(0.100000001-2.0.i)`.
  - An element and a member are shown so too: `[(1.5-2.0.i), (0.0+1.0.i)]`
    and `{name: "h", z: (1.5-2.0.i)}`.
  - It is the type's `z.string`, a `String`
    ([structs.md](structs.md)), where a struct's derived text was,
    `{real: 1.5, imag: -2.0}`.
  - It pastes back as the number, `1.5-2.0.i`, and `c64(text)` reads
    it, below, the sign of a zero too.
- `z.typename` is `c64`, also through its alias.
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
  - Each writes both parts, a zero and its sign too:
    `c64(1.5, -0.0).dec` is `(+1.5-0.0.i)`.
- **From text** (#569): the type reads its own text back, so
  `c64(z.dec)`, `c64(z.hex)` and `c64(z.cstr)` are `z`, as
  `f64("1.5")` is 1.5.
  - It reads what `print` writes, `(1.5-2.0.i)`, and `(+1.5-2.0.i)`,
    each with its parentheses or with none, and the text of a struct
    of the two parts, `{real: 1.5, imag: -2.0}`, which `print` wrote
    before #570.
  - Each part is read as `f64(text)` reads it, so a hex float, `inf`
    and `nan` are read, and the sign of a zero is kept:
    `c64("(-0.0+2.0.i)")` is `c64(-0.0, 2.0)`.
  - A part alone is read, and the other is 0: `c64("1.5")` is
    `c64(1.5, 0.0)` and `c64("2.0.i")` is `c64(0.0, 2.0)`.
  - Spaces may come first and last, inside the parentheses or the
    braces, and about the sign that joins the parts:
    `c64("1.5 - 2.0.i")` is `c64(1.5, -2.0)`.
  - Text that is no complex number is an error, and gives a NaN in
    both parts: `c64("abc")`, `c64("")`, `c64("1.5+2.0")`, with no
    `.i`, and `c64("1.5x")`. All of the text is read.
  - `c32(text)` is the same, of `f32` parts; the text is a `cstr`, or
    a `String` by reference, `c64(&s)`.
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
    println(z * z.conj(), " ", norm(z))           // ((13n/36n)+(0n/1n).i) (13n/36n)
    println(1 / CBR(3, -4))                       // ((3n/25n)+(4n/25n).i)
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
  - `z / 0` is infinite, each part a BigRat's infinity by the part's
    sign: `CBR(1, -1) / 0` is `((1n/0n)+(-1n/0n).i)`.
    - A part that is 0 stays 0 beside one that is none (#571), since
      a rational's 0 is exactly 0: `CBR(1) / CBR(0)` is
      `((1n/0n)+(0n/1n).i)` and `CBR(0, 1) / 0` is
      `((0n/1n)+(1n/0n).i)`.
    - So by a `CBR`, a `BigRat`, a `BigInt` or an `i64` that is 0,
      and of each by a `CBR` that is 0, `1 / CBR(0)`.
    - `0 / 0` has NaN parts, which equal nothing, and a NaN part of
      `z` makes no 0 of the other.
    - A `c64`'s is C's, of floats: `c64(1.0) / c64(0.0)` is
      `(inf+nan.i)`, a float's `0.0 / 0.0` being a `nan`.
  - By an infinity it is 0, as a `c64`'s.
  - By a real `CBR`, one with an imaginary part of 0, it is part by
    part, as by a `BigRat`, and by an imaginary one too, with a
    quarter turn (#572).
    - What is finite is the same, exact.
    - An infinite `z` keeps a part that is 0: with `inf` a BigRat's
      infinity, `CBR(inf, 0) / CBR(2)` is `((1n/0n)+(0n/1n).i)`, where
      its imaginary part was 0 times an infinity, a NaN, and
      `CBR(inf, 0) / CBR(0, 2)` is `((0n/1n)+(-1n/0n).i)`.
    - The sign is the quotient's: `CBR(inf, 0) / CBR(-2)` is
      `((-1n/0n)+(0n/1n).i)`.
    - So by a negative `BigRat`, `BigInt` or `i64` (#574), as a
      BigRat's infinity divided by one has its sign:
      `CBR(inf, 0) / -2` is `((-1n/0n)+(0n/1n).i)`.
  - Times a real `CBR`, or an imaginary one, it is the other scaled,
    part by part, as times a `BigRat`, either way round (#573).
    - What is finite is the same, exact.
    - Times an infinity a part that is 0 stays 0 beside one that is
      none, as by 0: `CBR(1) * CBR(inf, 0)` is `((1n/0n)+(0n/1n).i)`,
      where its imaginary part was 0 times an infinity, a NaN, and
      `CBR(0, 1) * inf`, of a BigRat's infinity, is
      `((0n/1n)+(1n/0n).i)`.
    - An imaginary one turns it a quarter: `CBR(inf, 0) * CBR(0, 2)`
      is `((0n/1n)+(1n/0n).i)`.
    - 0 times an infinity is NaNs in both parts, whichever is the 0:
      `CBR(0) * CBR(inf, 0)`.
    - Of two numbers of two parts each it is the formula's:
      `CBR(inf, inf) * CBR(1, 1)` has a NaN, an infinity less an
      infinity.
- **What stays rational**: `conj(z)` and `norm(z)`, a `BigRat`, each a
  method too; `z.i` is `z` times `i`, and `r.i` of a BigRat is
  `CBR(0, r)`.
- **What does not** takes a precision (#554), as a BigRat's functions
  do, below: `abs`, `arg`, `sqrt`, `exp`, `log`, `pow`, `sin` and the
  rest, `exp(z, 64)`, `z.sqrt()`.
  - `c64(z)` is the nearest `c64`, where 53 bits will do.
  - No `CBR` is made of a `c64`: Rational makes no fraction of a float.
- **The text** of one is `(a+b.i)` too (#570): `print` writes
  `CBR(1n.over(2n), -1n.over(3n))` as `((1n/2n)+(-1n/3n).i)`, and so
  does a template.
  - Each part is a BigRat's text, in its own parentheses
    ([rational.md](rational.md)), with a `+` always between them, as
    `z.hex` lays it out: the sign is the part's own.
  - Both parts are always written: `((3n/1n)+(0n/1n).i)`, and
    `((0n/0n)+(0n/0n).i)` of NaNs.
  - It is `z.string`, a `String` of any length, which `print` shows
    whole; `z.cstr` is the same text, cut at 256 bytes.
  - `CBR(text)` reads it back (#569), as `BigRat(text)` a part's
    (#565).
- **`z.hex`, `z.oct` and `z.bin`** are `(real.hex+imag.hex.i)` and its
  kin, a `String` (#559): `((+0x1n/0x2n)+(-0x1n/0x3n).i)`.
  - Each part is a BigRat's text, in its own parentheses
    ([rational.md](rational.md)), so a `+` is always between them.
- **From text** (#569): `CBR(text)` reads what `print` writes, and
  `CBR(text, base)` in a base, so `CBR(&z.string)`, `CBR(z.hex, 16)`,
  `CBR(z.oct, 8)` and `CBR(z.bin, 2)` are `z`.
  - It reads `((1n/2n)+(-1n/3n).i)`, with the outer parentheses or
    with none, and the text of a struct of the two parts,
    `{real: (1n/2n), imag: (-1n/3n)}`, which `print` wrote before #570.
  - A part is a BigRat's text, as `BigRat(text, base)` reads it,
    exactly: in parentheses of its own, which a sign may come before,
    or bare, so `CBR("(1.5+2.5.i)")` and `CBR("1/2-1/3.i")` are read.
  - Spaces may be about the sign that joins the parts, as a `c64`'s:
    `CBR("(1/2) - (1/3).i")`.
  - A part alone is read, and the other is 0: `CBR("(1/2)")`,
    `CBR("3")` and `CBR("(1/3).i")`.
  - Text that is no `CBR` is an error, and gives a NaN in both parts,
    each `(0n/0n)`: `CBR("abc")`, `CBR("1+2")`, `CBR("1x")`.
  - From base 19 up `i` is a digit, so there `2.i` is a number and
    `(2).i` the imaginary one.

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
    `((-1n/1n)+(0n/1n).i)`, Euler's, to 64 bits.
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

### Functions of a `BigFloat`, with `<BigFloat>`

With `<BigFloat>` the functions take a `BigFloat` too (#580), and
give one of `BigFloat.precision` significant bits, as every BigFloat's
result ([bigfloat.md](bigfloat.md)).

```swift
#import <math>
#import <BigFloat>

let main():int32 {
    println(sqrt(BigFloat(2)))                   // 1.41421356237309504880168872420969807857
    println(exp(BigFloat(1)), " ", BigFloat.pi()) // 2.71828182845904523536028747135266249776 3.1415926535897932384626433832795028842
    let x = BigFloat("0.7")
    println(x.sin(16), " ", sin(x) * sin(x) + cos(x) * cos(x))   // 0.6442108154296875 1.0
    println(exp(BigFloat(1000)), " ", exp(BigFloat(-1000)))      // 1.970071114017046993888879352243323125315e+434 5.0759588975494567652918094795743369193e-435
    return 0
}
```

- **The functions**: `sqrt`, `exp`, `log`, `pow`, `sin`, `cos`, `tan`,
  `asin`, `acos`, `atan`, `atan2`, `sinh`, `cosh`, `tanh`, `asinh`,
  `acosh`, `atanh`, each a method too, `x.exp()`; and `BigFloat.pi()`.
- **The precision** is a count of significant bits, a float's, where
  a BigRat's function counts bits after the point.
  - With none written it is `BigFloat.precision`, 128; `f(x,
    precision)` and `x.f(precision)` give another, `exp(x, 256)`,
    `BigFloat.pi(64)`.
  - It is good whatever the size of the result: `exp(BigFloat(1000))`
    has 128 good bits, and so has `exp(BigFloat(-1000))`, where a
    BigRat's 128 bits after the point would be 0.
- **A result is the nearest** `BigFloat` to the true value, or, where
  that is all but midway between two, one of the two.
  - `sqrt`'s is always the nearest, as an `f64`'s.
  - What is whole is itself: `sqrt(BigFloat(9))` is 3,
    `pow(BigFloat(2), BigFloat(10))` 1024.
- **`pow(x, y)`** is `e^(y ln x)` of an `x` above 0; of a negative `x`
  and a whole `y` the power, and of one not whole a NaN.
- **An infinity and a NaN** come where a float's function gives one:
  `log(BigFloat(0))` is `-inf`, `sqrt(BigFloat(-1))` a NaN,
  `atan` of an infinity half of pi, `tanh` of one 1.
  - `exp` of a number past `2^62` is an infinity, or 0: its exponent
    is past an `i64`.
- **A number far from 1** is taken as any (#583): no rational is made
  of it, which would be as long as its exponent is large.
  - Near 0 a function is its first term: `cos` and `cosh` of
    `2^-1000000000000` are 1, `sin` and its kin the number itself, and
    `acos` half of pi.
  - Far out it is its limit: `atan` is half of pi, with the number's
    sign, and `asinh` and `acosh` are `ln(2x)`.
  - Out of its domain it is a NaN: `asin`, `acos` and `atanh` past 1,
    `acosh` below it, `log` of a negative number.
  - `atan2(y, x)` is of the quotient: the quotient itself where that
    is far below 1, half of pi where far above, and of two as far as
    any, `atan2(huge, huge)`, a quarter of pi.
  - `pow` beside a 0 or an infinity reads the other's sign and size
    alone: `pow(BigFloat(0), huge)` is 0.
  - A sine, a cosine and a tangent have no limit: of a number of
    `2^67108864` and more they are NaNs, past reckoning, pi not being
    had to as many bits.
- **How**: by a BigRat's function, with as many bits after the point
  as make the bits asked for good, and 8 more.
  - `exp` takes the multiple of `ln 2` out first and `log` the power
    of 2, so no bits are spent on the size; `sinh`, `cosh` and `tanh`
    of 1 and more are of `exp`.
  - `sqrt` is the whole root of the mantissa, shifted.
  - `sin`, `tan`, `asin`, `atan`, `sinh`, `tanh`, `asinh` and `atanh`
    of an `x` so near 0 that its square is below the last bit are `x`.

### Complex numbers of any precision: `CBF`, with `<BigFloat>`

With `<BigFloat>` there is `CBF` too (#581): a complex number whose
parts are `BigFloat`s, as a `c64`'s are `f64`s, of as many bits as a
program asks.

```swift
#import <math>
#import <BigFloat>

let main():int32 {
    let z = CBF(1, 2) / CBF(3, 4)                // or complexBigFloat(1, 2), by the alias
    println(z, " ", z * CBF(3, 4), " ", norm(CBF(3, 4)))   // (0.44+0.08.i) (1.0+2.0.i) 25.0
    println(CBF(1, 1) / 3)                       // (0.333333333333333333333333333333333333334+0.333333333333333333333333333333333333334.i)
    let e = BigFloat("0x1p-100")                 // 2^-100: (1 + e)(1 - e) - 1 is -e², exactly
    println((CBF(BigFloat(1) + e, BigFloat(1)) * CBF(BigFloat(1) - e, BigFloat(1))).hex)   // (-0x1p-200+0x1p+1.i)
    let w = CBF("(0.1-0.2.i)")                   // of its text, each part a BigFloat's
    println(w, " ", w.dec, " ", w.round(8), " ", c64(w), " ", CBF(1) / CBF(0))   // (0.1-0.2.i) (+0.1-0.2.i) (0.10009765625-0.2001953125.i) (0.10000000000000001-0.20000000000000001.i) (inf+0.0.i)
    println(complexBigFloat(1, 2) == CBF(1, 2), " ", CBF(c64(0.5, 0.25)), " ", CBR(CBF(1, 2) / 4))   // true (0.5+0.25.i) ((1n/4n)+(1n/2n).i)
    return 0
}
```

- **The type**: `CBF`, with `real` and `imag` of `BigFloat`, a struct;
  `complexBigFloat` is its alias, as `complexBigRat` is `CBR`'s.
  - It comes with the two imports, `<math>` and `<BigFloat>`, by the
    overlay `modules/math+BigFloat.k` ([modules.md](modules.md)).
- **Making one**: `CBF(re, im)` and `CBF(re)` of BigFloats, of BigInts,
  of `i64`s or of `f64`s, and `(CBF){re, im}` of two BigFloats.
  - Two BigFloats are kept as they are; a part of another kind is a
    `BigFloat` of it, so `CBF(0.1, 0.2)` has an `f64`'s tenth and
    `CBF(BigFloat("0.1"), BigFloat("0.2"))` the nearest to a tenth.
  - Both parts are of one kind: `CBF(1.5, 2.0)`, and `CBF(1.5, 2)` is
    an error that says to convert one.
  - `CBF(z)` of a `c64` and of a `CBR` has the nearest to each part,
    and `CBF(z, precision)` at a precision.
- **`+`, `-`, `*`, `/`**, prefix `-`, `==` and `!=`, of two, or with a
  `BigFloat`, a `BigInt` or an `i64` on either side.
  - Each part of a result is the exact one's, rounded once to
    `BigFloat.precision` bits: the nearest, and of two as near the even
    one, as a BigFloat's result.
    - So `z * w` is `CBF(CBR(z) * CBR(w))`, and `z / w` likewise.
    - Nothing is lost where products all but cancel: with `e` of
      `2^-100`, `CBF(1 + e, 1) * CBF(1 - e, 1)` has a real part of
      `-0x1p-200`, where `(1 + e) * (1 - e) - 1` of BigFloats is 0.
    - Parts as far apart as any are no more work: of `2^1000000000000`
      and 1 a product takes no longer.
  - A `BigInt` or an `i64` is a `BigFloat` of it first, as with a
    BigFloat.
  - An infinity and a NaN in a part are as a `CBR`'s, above.
    - `z / 0` is infinite, a part that is 0 staying 0: `CBF(1) /
      CBF(0)` is `(inf+0.0.i)`, and `CBF(0) / CBF(0)` NaNs, which equal
      nothing.
    - By an infinity it is 0; times a real or an imaginary one it is
      scaled, `CBF(1) * CBF(inf, 0)` is `(inf+0.0.i)`.
- **`conj(z)`** and **`norm(z)`**, each a method too: `norm` is `real²
  + imag²`, a `BigFloat`, the sum exactly, rounded once.
  - `z.i` is `z` times `i`, and `x.i` of a `BigFloat` `CBF(0, x)`.
- **`z.round(precision)`** is `z` with each part at that many bits,
  and `z.round(precision, rule)` by a rule, as `x.round` of a BigFloat.
- **Back**: `CBR(z)` is its value exactly, and `c64(z)` the nearest
  `c64`.
- **Its text** is laid out as a `c64`'s: `(0.1-0.2.i)`, each part a
  BigFloat's text, the fewest digits that read back, the imaginary
  part's sign joining the two.
  - `print`, a template and `.cstr` give it, and `.string` a String;
    a struct's member, an Optional's value and an element show it.
  - `z.dec` has the real part's sign too, `(+0.1-0.2.i)`, and `z.hex`
    is of the parts' `.hex`, `(+0x1.8p+0-0x1p+1.i)`, its value exactly.
- **From text**: `CBF(text)` reads what `print` writes, and `z.dec`'s
  and `z.hex`'s, so `CBF(&z.string)` is `z`; `CBF(text, precision)` has
  each part at a precision.
  - As a `c64`'s text is read: with the parentheses or with none, a
    part alone, `1.5` or `2.0.i`, the other 0, spaces about the sign
    that joins, and `{real: 0.1, imag: -0.2}`.
  - A part is a decimal, `1.5e-05`, a hex float, `inf` or `nan`, with a
    sign or none.
  - Text that is none is an error, and gives a NaN in both parts:
    `CBF("x")`, `CBF("(1+2)")`.
- **math's functions** take a `CBF` too, below.

### Functions of a `CBF`, with `<BigFloat>`

math's functions take a `CBF` (#582), as they take a `c64` and a
`CBR`, and give each part to `BigFloat.precision` significant bits.

```swift
#import <math>
#import <BigFloat>

let main():int32 {
    let z = CBF(1, 2)
    println(exp(z))                              // (-1.13120438375681363843125525551079471063+2.47172667200481892761693089355166453273.i)
    println(sqrt(CBF(-9)), " ", sqrt(CBF(3, 4)), " ", abs(CBF(3, 4)), " ", log(CBF(-1)))   // (0.0+3.0.i) (2.0+1.0.i) 5.0 (0.0+3.1415926535897932384626433832795028842.i)
    println(z.exp(16), " ", z.abs(16), " ", z.arg(16))   // (-1.131195068359375+2.47174072265625.i) 2.236083984375 1.107147216796875
    println(pow(CBF(-4), BigFloat("0.5")), " ", pow(CBF(0, 1), CBF(2)), " ", asin(CBF(2)))   // (0.0+2.0.i) (-1.0+0.0.i) (1.5707963267948966192313216916397514421+1.316957896924816708625046347307968444025.i)
    println(exp(CBF(BigFloat(1), BigFloat("1e-300"))))   // (2.71828182845904523536028747135266249776+2.71828182845904523536028747135266249776e-300.i)
    return 0
}
```

- **The functions**: `abs` and `arg`, each a `BigFloat`; `sqrt`,
  `exp`, `log`, `pow`, `sin`, `cos`, `tan`, `sinh`, `cosh`, `tanh`,
  `asin`, `acos`, `atan`, `asinh`, `acosh` and `atanh`, each a `CBF`;
  each a method too, `z.exp()`.
  - `pow(z, w)` takes a `CBF` and a `CBF`, or a `BigFloat` on either
    side.
- **The precision** is a count of significant bits, of each part.
  - With none written it is `BigFloat.precision`, 128; `f(z,
    precision)` and `z.f(precision)` give another, `exp(z, 256)`.
  - Each part has its bits whatever its size, and however far below
    the other part it is: `exp(CBF(1, 1e-300))` has an imaginary part
    of 128 good bits, and so have the parts of `exp(CBF(-1000000,
    1))`.
- **A part of a result is the nearest** `BigFloat` to the true
  value's, or, where that is all but midway between two, one of the
  two, as a BigFloat's function.
  - `abs` is always the nearest, and so is `sqrt` of a real number.
- **A part that is 0 is exactly 0**: `exp` of a real number is real,
  `sqrt(CBF(-9))` is `(0.0+3.0.i)`, and `pow(CBF(-4), BigFloat("0.5"))`
  `(0.0+2.0.i)`, where a `c64`'s has a real part of `1.2e-16`.
  - Of a real number, where the function of a real number is one, it
    is a BigFloat's: `sin(CBF(x)).real` is `sin(x)`.
  - The value of pi is rounded: `exp(CBF(0, pi))` has an imaginary
    part of `1.9e-39`, pi's own error.
- **The inverses** take their principal values, with C99's branch
  cuts, and a point on a cut is on the side a float's `+0` is, as a
  `CBR`'s: `asin(CBF(2))` has an imaginary part above 0.
- **`pow(z, w)`** is the power itself, exactly, rounded, of a whole
  real `w`, 65536 at the most; a BigFloat's of a real `z` above 0 and
  a real `w`; else `e^(w log z)`.
  - It is of any size: `pow(CBF(10), CBF(1000000000, 1))` is a number
    of `2^3321928094`.
  - 0 to a `w` and a `z` to 0 are a `CBR`'s: `pow(CBF(0), CBF(0))` is
    1.
    - No more is read of the other than the signs of its parts.
  - A part is 0 exactly where the angle is a whole number of quarter
    turns: of a `z` on an axis, and of one on a diagonal with an even
    whole `w`, however large.
    - `pow(CBF(1, 1), CBF(131072))` is `2^65536`, and its imaginary
      part 0.
- **An infinity and a NaN** in a part give what a `CBR`'s function
  gives: `exp(CBF(inf))` is `(inf+0.0.i)`, `log(CBF(0))`
  `(-inf+0.0.i)`, and `sin` of an infinity NaNs.
- **A part past reckoning**, `2^67108864` and more in size or below
  `2^-67108864`, gives NaNs in both parts of the inverses: a rational
  of it is too long to make.
  - `abs` and `sqrt` take any.
  - `log`, `arg` and `pow` take any too (#586).
    - `arg`, and the imaginary part of `log`, is a BigFloat's `atan2`;
      the real part is half the log of the norm, whose exponent may be
      past an `i64`'s.
      - With `tiny` of `2^-1000000000000`, `log(CBF(1, tiny))` is
        `tiny^2 / 2 + tiny i`.
    - `pow` keeps the angle of `z` as quarter turns and what is left
      of them, so beside an axis each part's bits are good:
      `pow(CBF(tiny, 1), CBF(3))` is `-3 tiny - i`.
    - A whole power is the power itself where the parts of `z` are no
      further apart than `2^67108864`: with `huge` of
      `2^1000000000000`, `pow(CBF(huge, huge), CBF(2))` is
      `2 huge^2 i`.
    - A `w` near 0 makes 1 and `w log z`: `pow(CBF(1, 1), CBF(tiny))`
      is `1 + tiny pi / 4 i`.
    - A `w` far out makes an infinity or 0, and NaNs where the angle
      is past reckoning: `pow(CBF(1, 2), CBF(-huge))` is
      `(0.0+0.0.i)`, and `pow(CBF(1, 2), CBF(huge))` `(nan+nan.i)`.
      - But `pow(CBF(1, tiny), CBF(huge))` is `e^i`, the two being 1
        over each other.
      - Past reckoning is what would take 1048576 bits more than are
        asked.
  - `exp`, the sines, the cosines and the tangents take any too
    (#585): they are made of a BigFloat's functions, which do (#583),
    and of no rational.
    - Near 0 a function is its first term: with `tiny` of
      `2^-1000000000000`, `exp(CBF(1, tiny))` is `e + e tiny i`, and
      `sin(CBF(tiny, 1))` `tiny cosh 1 + i sinh 1`.
    - Far out `e^x` is an infinity or 0, and `sinh` and `cosh`
      infinities, each part with its other factor's sign:
      `exp(CBF(huge, 2))` is `(-inf+inf.i)`, and `exp(CBF(-huge, 2))`
      `(0.0+0.0.i)`.
    - An angle of `2^67108864` and more has no sine, and a part it is
      in is a NaN: `exp(CBF(1, huge))` is `(nan+nan.i)`.
      - But where its other factor is 0: `sinh(CBF(0, huge))` is
        `(0.0+nan.i)`, and `tanh(CBF(huge, huge))` `(1.0+0.0.i)`.
- **How**: `exp`, the sines, the cosines and `tanh` are products and
  quotients of a BigFloat's functions, which lose nothing.
  - `sqrt` and `log` are of the norm, exactly; `pow` is `exp` of `w`
    times `log`, with as many more bits as a part of it is small.
    - The whole quarter turns that `w` makes of the angle are taken
      out of it exactly, and the sine and the cosine are of what is
      left.
  - The inverses are a `CBR`'s, with as many bits after the point as
    make each part's bits good.

## Where it lives

The functions of a `BigFloat`, `CBF` and its functions are `modules/math+BigFloat.k`'s, an overlay read where `<math>` and `<BigFloat>` are both imported; it imports `<math+Rational>`, whose functions it is written with (#579). `CBR` and the functions of a `BigRat` and of a `CBR` are `modules/math+Rational.k`'s, an overlay (#551), read where `<math>` and `<Rational>` are both imported. The rest is `modules/math.k`, brought in by `#import <math>`, written in Kelvin: C's own functions of `math.h` declared, overloads for `f32` and the complex types, `extend` blocks of methods and type attributes, and `typealias` (#149) for the two aliases. Nothing of it is in the prelude or the runtime; `kelvinc --lib modules/math.k` builds it into `math.kh` and `libkmath.a` where a project wants that (#146).

## Functions

<!-- fragment -->
```swift
sin(x:float64):float64, sin(x:float32):float32, sin(z:c64):c64, sin(z:c32):c32   // and so for each function above
pow(x:float64, y:float64):float64, pow(z:c64, w:c64):c64, pow(z:c64, x:float64):c64
abs(x:float64):float64, abs(x:float32):float32, abs(n:int64):int64, abs(z:c64):float64, abs(z:c32):float32
conj(z:c64):c64, arg(z:c64):float64, norm(z:c64):float64                   // and of a c32
c64(real:float64, imag:float64):c64, c64(real:float64):c64, c64(z:c32):c64, polar(r:float64, theta:float64):c64
c64(text:cstr):c64, c32(text:cstr):c32                                      // and of a String by reference (#569)
```

With `<Rational>` (#552):

<!-- fragment -->
```swift
CBR(real:BigRat, imag:BigRat):CBR, CBR(real:BigRat):CBR                    // and of BigInts, and of i64s
c64(z:CBR):c64, conj(z:CBR):CBR, norm(z:CBR):BigRat
CBR(text:cstr):CBR, CBR(text:cstr, base:int64):CBR                         // and of a String by reference (#569)
sin(x:BigRat):BigRat, sin(x:BigRat, precision:int64):BigRat                // and so for each function of a BigRat (#553)
sin(z:CBR):CBR, sin(z:CBR, precision:int64):CBR                            // and of a CBR (#554)
abs(z:CBR):BigRat, abs(z:CBR, precision:int64):BigRat, arg(z:CBR):BigRat, arg(z:CBR, precision:int64):BigRat
pow(z:CBR, w:CBR):CBR, pow(z:CBR, x:BigRat):CBR, pow(x:BigRat, w:CBR):CBR   // each with a precision too
pow(x:BigRat, y:BigRat):BigRat, pow(x:BigRat, y:BigRat, precision:int64):BigRat
atan2(y:BigRat, x:BigRat):BigRat, atan2(y:BigRat, x:BigRat, precision:int64):BigRat
```

With `<BigFloat>` (#580 to #582):

<!-- fragment -->
```swift
CBF(real:BigFloat, imag:BigFloat):CBF, CBF(real:BigFloat):CBF              // and of BigInts, of i64s and of f64s
CBF(z:c64):CBF, CBF(z:CBR):CBF, CBF(z:c64, precision:int64):CBF, CBF(z:CBR, precision:int64):CBF
CBR(z:CBF):CBR, c64(z:CBF):c64, conj(z:CBF):CBF, norm(z:CBF):BigFloat
CBF(text:cstr):CBF, CBF(text:cstr, precision:int64):CBF                    // and of a String by reference
sin(z:CBF):CBF, sin(z:CBF, precision:int64):CBF                            // and so for each function of a CBF (#582)
abs(z:CBF):BigFloat, abs(z:CBF, precision:int64):BigFloat, arg(z:CBF):BigFloat, arg(z:CBF, precision:int64):BigFloat
pow(z:CBF, w:CBF):CBF, pow(z:CBF, x:BigFloat):CBF, pow(x:BigFloat, w:CBF):CBF   // each with a precision too
sin(x:BigFloat):BigFloat, sin(x:BigFloat, precision:int64):BigFloat        // and so for each function of a BigFloat
pow(x:BigFloat, y:BigFloat):BigFloat, pow(x:BigFloat, y:BigFloat, precision:int64):BigFloat
atan2(y:BigFloat, x:BigFloat):BigFloat, atan2(y:BigFloat, x:BigFloat, precision:int64):BigFloat
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
| | `.string`, `${z}`, `println(z)` | `(1.5-2.0.i)`: each part as `print` writes a float, the imaginary part's sign joining them, both parts always; a `String` (#570) |
| | `.cstr` | the same text, a `cstr` |
| | `.hex`, `.dec` | `(+0x1.8p+0-0x1p+1.i)` and `(+1.5-2.0.i)`: its parts' texts and `.i`, a `String` (#559) |
| | `c64(text)`, `c32(text)` | of its text: `(1.5-2.0.i)`, `(+1.5-2.0.i)`, `{real: 1.5, imag: -2.0}`, or a part alone, `1.5`, `2.0.i`; a `cstr` or a `String` by reference; text that is none is a NaN in both parts (#569) |
| `CBR`, with `<Rational>` (#552) | `.real`, `.imag` | the parts, fields, each a `BigRat` |
| | `+`, `-`, `*`, `/`, prefix `-` and `+`, `==`, `!=` | exact, of two, or with a `BigRat`, a `BigInt` or an `i64` on either side; `z / 0` is infinite, a part that is 0 staying 0, `((1n/0n)+(0n/1n).i)` (#571); by a real or an imaginary `CBR` it is part by part (#572), and times one (#573); an infinite part by a negative number has the quotient's sign (#574) |
| | `.conj()` | the conjugate, a `CBR` |
| | `.norm()` | `real² + imag²`, a `BigRat` |
| | `.i` | `z` times `i` |
| | `.string`, `${z}`, `println(z)` | `((1n/2n)+(-1n/3n).i)`: each part a `BigRat`'s text, a `+` between them; a `String`, shown whole (#570) |
| | `.cstr` | the same text, a `cstr`, cut at 256 bytes |
| | `.hex`, `.oct`, `.bin` | `((+0x1n/0x2n)+(-0x1n/0x3n).i)` and its kin, a `String` (#559) |
| | `CBR(text)`, `CBR(text, base)` | of its text: `((1n/2n)+(-1n/3n).i)`, `{real: (1n/2n), imag: (-1n/3n)}`, `z.hex` with 16, or a part alone; text that is none is a NaN in both parts (#569) |
| | `.abs()`, `.arg()`, `.abs(p)`, `.arg(p)` | to 128 bits, or within `2^-p`, a `BigRat` (#554) |
| | `.sqrt()`, `.exp()`, `.log()`, `.sin()`, ..., `.atanh()` | the function to 128 bits, a `CBR` (#554) |
| | `.sqrt(p)`, `.exp(p)`, ..., `.pow(w)`, `.pow(w, p)` | the same, each part within `2^-p` |
| `BigRat`, with `<Rational>` (#552) | `.i` | `CBR(0, r)`: the value rotated a quarter turn |
| `BigRat`, with `<Rational>` (#553) | `.sqrt()`, `.exp()`, `.log()`, `.sin()`, ..., `.atanh()` | the function to `BigRat.precision`, 128 bits, a `BigRat` |
| | `.sqrt(p)`, `.exp(p)`, `.sin(p)`, ... | the same within `2^-p` |
| | `.pow(y)`, `.pow(y, p)`, `.atan2(x)`, `.atan2(x, p)` | the two-argument ones |
| `BigRat.` | `.pi()`, `.pi(p)` | pi to 128 bits, or within `2^-p` |
| `BigFloat`, with `<BigFloat>` (#580) | `.sqrt()`, `.exp()`, `.log()`, `.sin()`, ..., `.atanh()` | the function to `BigFloat.precision` significant bits, 128, a `BigFloat` |
| | `.sqrt(p)`, `.exp(p)`, `.sin(p)`, ... | the same to `p` significant bits |
| | `.pow(y)`, `.pow(y, p)`, `.atan2(x)`, `.atan2(x, p)` | the two-argument ones |
| `BigFloat.` | `.pi()`, `.pi(p)` | pi to `BigFloat.precision` bits, or to `p` |
| | `.precision` | 128, the precision where none is written |
| `CBF`, with `<BigFloat>` (#581) | `.real`, `.imag` | the parts, fields, each a `BigFloat` |
| | `+`, `-`, `*`, `/`, prefix `-`, `==`, `!=` | each part the exact one's, rounded once to `BigFloat.precision` bits; of two, or with a `BigFloat`, a `BigInt` or an `i64` on either side; `z / 0` is infinite, a part that is 0 staying 0, `(inf+0.0.i)` |
| | `.conj()` | the conjugate, a `CBF` |
| | `.norm()` | `real² + imag²`, a `BigFloat`, rounded once |
| | `.i` | `z` times `i` |
| | `.round(precision)`, `.round(precision, rule)` | each part at `precision` bits, to the nearest and the even one, or by a rule |
| | `.string`, `${z}`, `println(z)` | `(0.1-0.2.i)`: each part a `BigFloat`'s text, the imaginary part's sign joining them; a `String` |
| | `.cstr` | the same text, a `cstr` |
| | `.dec`, `.hex` | `(+0.1-0.2.i)` and `(+0x1.8p+0-0x1p+1.i)`, exact: its parts' texts and `.i`, a `String` |
| | `CBF(text)`, `CBF(text, precision)` | of its text: `(0.1-0.2.i)`, `z.dec`, `z.hex`, `{real: 0.1, imag: -0.2}`, or a part alone, `1.5`, `2.0.i`; a `cstr` or a `String` by reference; text that is none is a NaN in both parts |
| | `CBF(z)`, `CBF(z, precision)` | of a `c64` or a `CBR`: each part the nearest |
| | `.abs()`, `.arg()`, `.abs(p)`, `.arg(p)` | to `BigFloat.precision` significant bits, or to `p`, a `BigFloat` (#582) |
| | `.sqrt()`, `.exp()`, `.log()`, `.sin()`, ..., `.atanh()` | the function, each part to `BigFloat.precision` significant bits, a `CBF` (#582) |
| | `.sqrt(p)`, `.exp(p)`, ..., `.pow(w)`, `.pow(w, p)` | the same, each part to `p` significant bits |
| `CBR`, `c64` | `CBR(z)`, `c64(z)` | of a `CBF`: its value exactly, and the nearest `c64` |
| `BigFloat`, with `<BigFloat>` (#581) | `.i` | `CBF(0, x)`: the value rotated a quarter turn |
