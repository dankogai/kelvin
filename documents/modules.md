# Modules: `#import` and `modules/`

A Kelvin file is brought into a program with `#import`, and Kelvin's own
files, its prelude header and its library live in one directory,
`modules/`. This document has the import, the search, the layout, and
the one module so far, `complex.k`. C headers are in
[c-interfaces.md](c-interfaces.md).

## Kelvin files: `#import <complex.k>`

`#import` of a `.k` file, without `as C`, brings in its source: its
declarations are compiled with the program as if written where the
import is (#40), which is at the top level. `"x.k"` is found next to
the importing file, and `<x.k>` in `./modules`, of the directory kelvinc
runs in, and then in Kelvin's own `modules/` (#46), which also holds
the runtime, `kelvin_prelude.h` and `libkelvin`: in the source tree, or
in `$PREFIX/lib/kelvin/modules` after `make install`, or under
`$KELVIN_HOME`. A file is brought in once, however often it is
imported, also through other files or other paths. A declaration ends
where a file does, and errors in a file, also an unfinished one at its
end, name its own lines. A C header it imports as `"x.h"` is the one
next to it. Its functions are named by their parameter types in C
(#41), so that they never clash with C's, except the C functions it
declares by hand, which keep their names.

## `modules/`

```
modules/                  in the source tree, or $PREFIX/lib/kelvin/modules
    kelvin_prelude.h      the prelude: print, println, the properties
    libkelvin.a           built by make, linked into every program
    libkelvin.dylib|.so   the same, for use from C and other toolchains
    complex.k             #import <complex.k>
./modules/                a project's own, looked in first
    x.k, x.h, libx.a      #import <x.k>, #import <x.h> as C, KELVIN_CFLAGS=-lx
```

- `#import <x.k>` looks in `./modules` of the directory kelvinc runs in,
  then in Kelvin's `modules/`: the first of `$KELVIN_HOME`, kelvinc's
  own directory (the source tree) and its parent (an installation,
  `bin/../lib/kelvin/modules`) that holds `kelvin_prelude.h` (#46).
- C looks in both for headers and libraries too (`-I`, `-L`), so a
  project's `./modules` may hold a C header or a static library beside
  its Kelvin files, and `KELVIN_CFLAGS=-lx` links `./modules/libx.a`.
  `KELVIN_CFLAGS` go after the program's C, as a library must.
- `make install PREFIX=...` puts `kelvinc` in `$PREFIX/bin` and the whole
  of `modules/` in `$PREFIX/lib/kelvin/modules`.

## Complex numbers: `modules/complex.k`

`#import <complex.k>` brings in `complex64`, whose parts are `f64`,
and `complex32`, whose parts are `f32`, without C's `_Complex` (#43):

```kelvin
#import <complex.k>

let main():i32 {
    let i:complex64 = complex64(0.0, 1.0)
    let z:complex64 = complex64(1.0, 2.0)
    let w:complex64 = exp(z) * z + 1.0          // operators, and exp of a complex64
    println(`${w} ${abs(w)} ${sin(0.5)}`)       // sin of an f64 is C's
    println(abs(exp(i * 3.141592653589793) + 1.0) < 1e-15)   // true
    return 0
}
```

- **Making one**: `complex64(re, im)`, `complex64(re)`, `polar(r, theta)`,
  `(complex64){re, im}`, and `complex64(z)` of a `complex32` (or
  `complex32(z)` of a `complex64`).
- **Arithmetic**: `+ - * /` between two of one kind, or one and a real
  number of its parts' type (either way round), unary `-`, `==` and
  `!=`. `complex32` and `complex64` do not mix: convert one.
- **Functions**: `conj`, `abs`, `arg`, `norm` (`abs` squared), `exp`,
  `log`, `sqrt`, `pow`, `sin`, `cos`, `tan`, `sinh`, `cosh`, `tanh` and
  their inverses, which take their principal values, with C99's branch
  cuts and its signs of zero on them. They keep their accuracy near 0
  and ±1, and no step overflows where the result does not. C's own
  functions of these names still take numbers, also ones only C sees,
  as `tanh(atof(s))`: the file declares them.
- **The text** of one is its derived `.cstr`, as in
  `{real: 1, imag: 2}`, also in a template; `print` takes no struct.
- `complex128` waits for `f128`. C99's special values for infinities and
  NaNs are not attempted, except for `sqrt` and division by an
  infinity *(provisional P54)*.
- kelvinc compiles with `-ffp-contract=off`, so clang computes `a * b +
  c` with two roundings, as gcc does, and the results are the same with
  both *(provisional P55)*.

