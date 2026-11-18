# Math: `math.h` and complex numbers, of the prelude

The functions of C's `math.h` for `f64` and `f32`, their constants, and complex numbers `c64` and `c32`, with no import. Of a number of any size they are `<BigNum>`'s: [bignum.md](bignum.md).

## Synopsis

```swift
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

It is the prelude's (#591), as `RegExp` and `BigInt` are: a program
that names one of its names has it, with no import. Many languages
have these built in, JavaScript and Perl among them.

- **What names it**: a name the module declares, `sin`, `c64`,
  `polar`, wherever the program writes it; and what it gives `f64` and
  `f32`, after a dot: `f64.tau`, `x.isnan`, `2.0.sqrt()`, `1.0.i`.
  - The names are read from the module itself: none is kept in the
    compilers.
  - A program that names none compiles as before, without it.
  - A name the program declares, `let log(what:cstr)`, names nothing
    there; its calls do, and the function stands beside math's, told
    apart by its types.
- **`#import <math>`** is accepted, and does nothing more.
  - Math is read where the prelude's is, before all else, wherever
    the import stands (#601): a file imported before it that names
    `c64` and writes no import of math, as a module's header does
    not, has it all the same.
- **A type of the program's own** named `c64`, `c32`, `complex64` or
  `complex32` hides math's under the bare name, and `Kelvin.c64` is
  math's (#600), as with a `RegExp` of its own.
  - It kept all of math out before; the rest of math is there now,
    `sqrt(2.0)` too.
- **A function of the program's own with the name and the types of
  one of math's**, `let log(x:f64):f64 { ... }`, is another function
  (#600): `log(x)` calls it and `Kelvin.log(x)` math's. See
  [namespace.md](namespace.md).
- **`abs` of an integer** is Kelvin's now, of an `i64`: `abs(-3)` is
  an `i64`. With no import it was C's, of an `int`, which cut a larger
  number short.

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

### Numbers of any size: `<BigNum>`

math's functions take a `BigRat`, a `CBR`, a `BigFloat` and a `CBF`
too, each to a precision, where a program imports `<BigNum>` (#590):
`sqrt(BigRat(2), 64)`, `exp(BigFloat(1))`, `sin(CBF(1, 2))`.

- `CBR` and `CBF` are complex numbers of two `BigRat`s and of two
  `BigFloat`s, as a `c64` is of two `f64`s.
- They are described with the library, in [bignum.md](bignum.md),
  since #592; they were here before.

## Where it lives

`modules/math.k`, written in Kelvin: C's own functions of `math.h` declared, overloads for `f32` and the complex types, `extend` blocks of methods and type attributes, and `typealias` (#149) for the two aliases. It is a module of the prelude (#591): `make` builds it with `kelvinc --prelude` into `modules/math.kh`, its declarations, and an object that libkelvin holds, as `BigInt`'s is, so two objects of one program that both use it link, which two copies of its source did not. Its functions of a `BigRat`, a `CBR`, a `BigFloat` and a `CBF`, and the two complex types, are `modules/BigNum.k`'s ([bignum.md](bignum.md)).

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
