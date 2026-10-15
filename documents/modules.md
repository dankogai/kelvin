# Modules: `#import` and `modules/`

A Kelvin file is brought into a program with `#import`, and Kelvin's own
files, its prelude header and its libraries live in one directory,
`modules/`. A module is a Kelvin source, `M.k`, or a header and a
library, `M.kh` and `libkM` (#143). This document has the import, the
search, the layout, and the modules so far: `math.k` and `JSON.k`,
and `IO` and `OS`, each a header and a library. C headers are in
[c-interfaces.md](c-interfaces.md).

**Where it lives:** `#import` is the core. What it brings in is loaded explicitly: `modules/math.k`, with the functions of math.h and `complex64` and `complex32`, comes only with `#import <math>`, `IO` and `OS` only with `#import <IO>` and `#import <OS>` (#144, #145), and a C header's names only with `#import <x.h> as C`.

## Kelvin files: `#import <math>`

`#import` of a `.k` file, without `as C`, brings in its source: its
declarations are compiled with the program as if written where the
import is (#40), which is at the top level.

- A name with no extension is a module: `#import <JSON>` is
  `#import <JSON.kh>`, a header with a library (#143), where there is
  one, else `#import <JSON.k>` (#112).
- `"x.k"` is found next to the importing file, and `<x.k>` in
  `./modules`, of the directory kelvinc runs in, and then in Kelvin's
  own `modules/` (#46), which also holds the runtime,
  `kelvin_prelude.h` and `libkelvin`.
  - That is in the source tree, or in `$PREFIX/lib/kelvin/modules`
    after `make install`, or under `$KELVIN_HOME`.
- A file is brought in once, however often it is imported, also
  through other files or other paths.
- A declaration ends where a file does, and errors in a file, also an
  unfinished one at its end, name its own lines.
- A C header it imports as `"x.h"` is the one next to it.
- Its functions are named by their parameter types in C (#41), so that
  they never clash with C's, except the C functions it declares by
  hand, which keep their names.

## A header and a library: `M.kh` and `libkM`

A large module is a header and a library, as a C library is (#143):
`M.kh`, a Kelvin file of declarations, and `libkM.a`, or a shared
`libkM.dylib` or `libkM.so`, beside it, both in `modules/`. `#import
<M>` brings in the header and links the library, with no flag to
write.

```kelvin
#import <IO>                    // modules/IO.kh, and libkIO.a beside it
#import <shout>                 // ./modules/shout.kh, and ./modules/libkshout.a

let main():i32 {
    IO.stdout.println("io")
    shout("modules")
    return 0
}
```

- **`M.kh`** is a Kelvin file, read as `M.k` is (#40): declarations,
  and `#import <kM.h> as C` of the C header its library needs.
  - It may import other modules: `IO.kh` imports `<OS>`, which IO's
    files are built on, so `#import <IO>` brings OS in too.
- **`libkM`** is linked where `M.kh` is found: `libkM.a` by its path,
  else `-lkM` where only a shared one is, before `libkelvin`, in the
  order imported, so that a library a later one calls comes after it.
  - A `.kh` with no library beside it is a header alone, as a C
    header-only library is.
- **`#import <M>`** takes, in `./modules` and then in Kelvin's
  `modules/`, the first of:
  1. `M.kh`, with `libkM.a`, `.so` or `.dylib` beside it: the header is
     read, and the library linked;
  2. `M.k`: the source, included in the importing program as if written
     there (#40).
  - `#import <M.kh>` and `#import <M.k>` name one or the other.
- **Kelvin's own** are `IO` ([io.md](io.md)) and `OS`
  ([os.md](os.md)), built by `make` from runtime/io.c and runtime/os.c
  into `libkIO` and `libkOS`, with the C headers `kIO.h` and `kOS.h`;
  a program without them links the core alone, which is why they are
  modules: one day a program may run where there is no IO.
  - `math.k` and `JSON.k` stay Kelvin sources, included where they
    are imported: `JSON.k` is the example of how a module is written in
    Kelvin. `kelvinc --lib` builds either into a `.kh` and a `libkM.a`
    where a project wants that.

## Building a module: `kelvinc --lib M.k`

`kelvinc --lib M.k` (#146) builds a Kelvin file into a module: `M.kh`,
its declarations with the bodies dropped, and `libkM.a`, its code,
with `libkM.dylib` or `libkM.so` beside it (#147), all in `./modules`,
or in the directory `-o` names.

```
kelvinc --lib geo.k                  # ./modules/geo.kh, libkgeo.a and libkgeo.dylib|.so
kelvinc --lib modules/JSON.k -o lib  # lib/JSON.kh, lib/libkJSON.a and lib/libkJSON.dylib|.so
```

- **The header** holds what a program needs, as the source wrote it:
  its imports, its structs, unions and enums whole, and a prototype of
  each function, method, function of the type, operator, attribute
  and subscript, in their `extend` blocks.
  - A global is `extern let x:T` or `extern var x:T`, with the type
    kelvinc inferred.
  - A C function's prototype, `let exp(x:f64):f64` with no body, is
    `extern let exp(x:f64):f64` there: in a `.kh`, a prototype without
    `extern` is the library's own function.
  - `T.cstr()` is copied with its body: a text method is inline, sized
    by its template, in each file that uses the type.
  - A `static let f()` of the file, C's static, is left out; a
    `static let` of a type is a function of the type, and kept.
  - A type attribute, `static var T.x = v`, waits: a program cannot
    declare one yet, so a library may not hold one.
- **The library** is the file's C, compiled with `-fPIC` into one
  object and archived; its functions are named by their types, as a
  program's prototypes of them are, so that the names meet.
  - A library has no `main`, which is an error.
- **The shared library** (#147), `libkM.dylib` on macOS and `libkM.so`
  elsewhere, is the same object linked against the shared `libkelvin`
  and the shared libraries of the modules the file imports, or their
  static ones where there is no shared one, for C and other toolchains:
  a C program links it, and the shared `libkelvin` with it, and calls
  the module's functions by the names `--emit-c` shows, with
  `-Wl,-rpath` for the directories the libraries are in, since on Linux
  a program's run path does not reach a library's own dependencies.
  `#import <M>` links `libkM.a`.
- **Attributes and subscripts** may be prototypes in a `.kh` only:
  `let norm1:f64`, `var first:f64`, `let [](i:i64):f64`, each declaring
  the getter, and the setter where it is a `var`.

## `modules/`

```
modules/                  in the source tree, or $PREFIX/lib/kelvin/modules
    kelvin_prelude.h      the prelude: print, println, the properties
    libkelvin.a           built by make, linked into every program
    libkelvin.dylib|.so   the same, for use from C and other toolchains
    IO.kh, kIO.h          #import <IO> (#144, io.md): the header, and its C header
    libkIO.a|.dylib|.so   its library, linked by the import
    OS.kh, kOS.h          #import <OS> (#145, os.md), with SYS
    libkOS.a|.dylib|.so   its library
    math.k                #import <math> (#148): math.h for f64 and f32, complex64 and complex32
    JSON.k                #import <JSON> (#113, json.md)
./modules/                a project's own, looked in first
    x.kh, libkx.a         #import <x>: the header, and its library linked by the import (#143)
    x.k, x.h, libx.a      #import <x.k>, #import <x.h> as C, KELVIN_CFLAGS=-lx
```

- `#import <x.k>`, or `#import <x>` (#112), looks in `./modules` of the
  directory kelvinc runs in, then in Kelvin's `modules/`.
  - Kelvin's `modules/` is the first of `$KELVIN_HOME`, kelvinc's own
    directory (the source tree) and its parent (an installation,
    `bin/../lib/kelvin/modules`) that holds `kelvin_prelude.h` (#46).
- C looks in both for headers and libraries too (`-I`, `-L`), so a
  project's `./modules` may hold a C header or a static library beside
  its Kelvin files, and `KELVIN_CFLAGS=-lx` links `./modules/libx.a`.
  - `KELVIN_CFLAGS` go after the program's C, as a library must.
- `make install PREFIX=...` puts `kelvinc` in `$PREFIX/bin` and the whole
  of `modules/` in `$PREFIX/lib/kelvin/modules`, the `.kh` files, the C
  headers and the `libkM` libraries too.

## Math: `modules/math.k`

`#import <math>` (#148) is `math.h` and its complex counterpart, as C's
math and cmath are: the functions of `math.h` for `f64` and `f32`, the
constants of each as attributes of the type, `f64.pi`, every function
as a method too, `x.sin()`, and `complex64`, whose parts are `f64`, and
`complex32`, whose parts are `f32`, without C's `_Complex` (#43):

```kelvin
#import <math>

let main():i32 {
    let i:complex64 = complex64(0.0, 1.0)
    let z:complex64 = complex64(1.0, 2.0)
    let w:complex64 = exp(z) * z + 1.0          // operators, and exp of a complex64
    println(`${w} ${abs(w)} ${sin(0.5)}`)       // sin of an f64 is C's
    println(abs(exp(i * f64.pi) + 1.0) < 1e-15)  // true: f64.pi, a constant of the type
    println(2.0.sqrt(), " ", (0.5:f32).sin(), " ", z.exp(), " ", 1.0.i)   // the methods; 1.0.i is complex64(0, 1)
    return 0
}
```

- **The functions of `math.h`**, each for an `f64` and an `f32`: `sin`,
  `cos`, `tan`, `asin`, `acos`, `atan`, `sinh`, `cosh`, `tanh`, `asinh`,
  `acosh`, `atanh`, `exp`, `exp2`, `expm1`, `log`, `log2`, `log10`,
  `log1p`, `sqrt`, `cbrt`, `floor`, `ceil`, `round`, `trunc`, `fabs`,
  `erf`, `erfc`, `tgamma`, `lgamma`, `pow`, `hypot`, `atan2`, `fmod`,
  `fmin`, `fmax`, `copysign`, `fma`, and `abs` of a float.
  - Of an `f64` each is C's own, declared; of an `f32` its `f` kind,
    `sinf`, so `sin(x)` of an `f32` gives an `f32`.
  - Each is a method too, `x.sin()`, `x.pow(y)`, `x.atan2(y)`, which
    says which where it matters; Kelvin's overloading picks the one for
    the type anyway.
- **The constants**, as attributes of the type: `f64.pi`, `tau`, `e`,
  `ln2`, `ln10`, `log2e`, `log10e`, `sqrt2`, `infinity`, `nan`,
  `epsilon`, `max` and `min`, and the same of `f32`.
  - `x.isnan`, `x.isinf` and `x.isfinite` test a value.
- **`x.i`** is `x` rotated a quarter turn on the Gaussian plane:
  `1.0.i` is `complex64(0.0, 1.0)`, `(0.5:f32).i` a `complex32`, and
  `z.i` of a complex number is `z` times `i`, so `1.0.i.i` is `-1`.
- **Making a complex number**: `complex64(re, im)`, `complex64(re)`, `polar(r, theta)`,
  `(complex64){re, im}`, and `complex64(z)` of a `complex32` (or
  `complex32(z)` of a `complex64`).
- **Arithmetic**: `+ - * /` between two of one kind, or one and a real
  number of its parts' type (either way round), unary `-`, `==` and
  `!=`. `complex32` and `complex64` do not mix: convert one.
  - Each is written in `extend complex64 { }` as
    `static let +(a:Self, b:Self):Self` (#135, #140), and a mixed one
    as `static let +(a:Self, b:f64):Self`.
- **Complex functions**: `conj`, `abs`, `arg`, `norm` (`abs` squared),
  `exp`, `log`, `sqrt`, `pow`, `sin`, `cos`, `tan`, `sinh`, `cosh`,
  `tanh` and their inverses, which take their principal values, with
  C99's branch cuts and its signs of zero on them; each a method too,
  `z.exp()`, `z.abs()`, `z.pow(w)`.
  - They keep their accuracy near 0 and ±1, and no step overflows where
    the result does not.
  - C's own functions of these names still take numbers, also ones only
    C sees, as `tanh(atof(s))`: the file declares them.
- **The text** of one is its derived `.cstr`, as in
  `{real: 1, imag: 2}`, also in a template and in `print` (#122).
- `complex128` waits for `f128`. C99's special values for infinities and
  NaNs are not attempted, except for `sqrt` and division by an
  infinity *(provisional P54)*.
- kelvinc compiles with `-ffp-contract=off`, so clang computes `a * b +
  c` with two roundings, as gcc does, and the results are the same with
  both *(provisional P55)*.

## JSON: `modules/JSON.k`

`#import <JSON>` brings in `JSON`, a JSON value as an enum with values,
with `JSON.parse(text)` and `JSON.stringify(&j, replacer, space)` as JS
has them (#113): see [json.md](json.md).
