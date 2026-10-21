# Math: `#import <math>`

`modules/math.k` (#43, #148) is `math.h` and its complex counterpart,
as C's math and cmath are: the functions of `math.h` for `f64` and
`f32`, each a method too, `x.sin()`; the constants of each type as
attributes of it, `f64.pi`; `c64` and `c32`, complex numbers with `f64`
and `f32` parts, named by the size of each part, `complex64` and
`complex32` by their aliases (#150); and `x.i`, `x` rotated a quarter
turn on the Gaussian plane.

**Where it lives:** `modules/math.k`, brought in by `#import <math>`, written in Kelvin: C's own functions of `math.h` declared, overloads for `f32` and the complex types, `extend` blocks of methods and type attributes, and `typealias` (#149) for the two aliases. Nothing of it is in the prelude or the runtime; `kelvinc --lib modules/math.k` builds it into `math.kh` and `libkmath.a` where a project wants that (#146).

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

## The functions of `math.h`

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
- **The constants**, as attributes of the type (#133): `f64.pi`,
  `f64.tau`, `f64.e`, `f64.ln2`, `f64.ln10`, `f64.log2e`, `f64.log10e`,
  `f64.sqrt2`, `f64.infinity`, `f64.nan`, `f64.epsilon`, `f64.max` and
  `f64.min`, and the same of `f32`, `f32.pi`, `f32.epsilon`.
  - `f32.epsilon` is larger than `f64.epsilon`, as C's `FLT_EPSILON`
    is.
- **Tests**: `x.isnan`, `x.isinf` and `x.isfinite`.
- **`x.i`** is `x` rotated a quarter turn: `1.0.i` is `c64(0.0, 1.0)`,
  `(0.5:f32).i` a `c32`, and `z.i` of a complex number is `z` times
  `i`, so `1.0.i.i` is `-1`.

## Complex numbers: `c64` and `c32`

- **The types**: `c64`, with `real` and `imag` of `f64`, and `c32`,
  with `f32` parts, structs without C's `_Complex`; `complex64` and
  `complex32` are their aliases (#150), the same types by the size of
  the whole.
  - `c128` waits for `f128`.
- **Making one**: `c64(re, im)`, `c64(re)`, `polar(r, theta)`,
  `(c64){re, im}`, and `c64(z)` of a `c32` (or `c32(z)` of a `c64`).
- **Arithmetic**: `+ - * /` between two of one kind, or one and a real
  number of its parts' type (either way round), unary `-`, `==` and
  `!=`. `c32` and `c64` do not mix: convert one.
  - Each is written in `extend c64 { }` as
    `static let +(a:Self, b:Self):Self` (#135, #140), and a mixed one
    as `static let +(a:Self, b:f64):Self`.
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
- C99's special values for infinities and NaNs are not attempted,
  except for `sqrt` and division by an infinity *(provisional P54)*.
- kelvinc compiles with `-ffp-contract=off`, so clang computes `a * b +
  c` with two roundings, as gcc does, and the results are the same with
  both *(provisional P55)*.

## Functions

<!-- fragment -->
```swift
sin(x:float64):float64, sin(x:float32):float32, sin(z:c64):c64, sin(z:c32):c32   // and so for each function above
pow(x:float64, y:float64):float64, pow(z:c64, w:c64):c64, pow(z:c64, x:float64):c64
abs(x:float64):float64, abs(x:float32):float32, abs(n:int64):int64, abs(z:c64):float64, abs(z:c32):float32
conj(z:c64):c64, arg(z:c64):float64, norm(z:c64):float64                   // and of a c32
c64(real:float64, imag:float64):c64, c64(real:float64):c64, c64(z:c32):c64, polar(r:float64, theta:float64):c64
```

## Properties and methods

| On | Property or method | Gives |
|---|---|---|
| `f64`, `f32` | `.sin()`, `.exp()`, `.sqrt()`, `.floor()`, ... | the function of `math.h`, as `x.sin()` |
| | `.pow(y)`, `.atan2(y)`, `.hypot(y)`, `.fmod(y)`, `.fmin(y)`, `.fmax(y)`, `.copysign(y)`, `.fma(y, z)` | the two- and three-argument ones |
| | `.abs()` | `fabs` |
| | `.isnan`, `.isinf`, `.isfinite` | tests, a `bool` |
| | `.i` | a `c64` or `c32`: the value rotated a quarter turn |
| `f64.`, `f32.` | `.pi`, `.tau`, `.e`, `.ln2`, `.ln10`, `.log2e`, `.log10e`, `.sqrt2`, `.infinity`, `.nan`, `.epsilon`, `.max`, `.min` | the constants, attributes of the type |
| `c64`, `c32` | `.real`, `.imag` | the parts, fields |
| | `.exp()`, `.log()`, `.sqrt()`, `.sin()`, ..., `.conj()` | the function, as `z.exp()` |
| | `.abs()`, `.arg()`, `.norm()` | an `f64` or `f32` |
| | `.pow(w)` | `z` to the power `w`, a `c64` or `c32` |
| | `.i` | `z` times `i` |
| | `.cstr`, `${z}`, `println(z)` | `{real: 1.0, imag: 2.0}` |
