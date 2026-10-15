# Modules: `#import` and `modules/`

A Kelvin file is brought into a program with `#import`, and Kelvin's own
files, its prelude header and its libraries live in one directory,
`modules/`. A module is a Kelvin source, `M.k`, or a header and a
library, `M.kh` and `libkM` (#143). This document has the import, the
search, the layout, and the modules so far: `complex.k` and `JSON.k`,
and `IO` and `OS`, each a header and a library. C headers are in
[c-interfaces.md](c-interfaces.md).

**Where it lives:** `#import` is the core. What it brings in is loaded explicitly: `modules/complex.k`, with `complex64` and `complex32`, comes only with `#import <complex.k>`, `IO` and `OS` only with `#import <IO>` and `#import <OS>` (#144, #145), and a C header's names only with `#import <x.h> as C`.

## Kelvin files: `#import <complex.k>`

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
- **`#import <M>`** looks for `M.kh` before `M.k`, in `./modules` and
  then in Kelvin's `modules/`; `#import <M.kh>` and `#import <M.k>`
  name one or the other.
- **Kelvin's own** are `IO` ([io.md](io.md)) and `OS`
  ([os.md](os.md)), built by `make` from runtime/io.c and runtime/os.c
  into `libkIO` and `libkOS`, with the C headers `kIO.h` and `kOS.h`;
  a program without them links the core alone, which is why they are
  modules: one day a program may run where there is no IO.
  - `complex.k` and `JSON.k` stay Kelvin sources: a mode of kelvinc
    that builds a Kelvin file into a `libkM` waits.

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
    complex.k             #import <complex.k>
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
  - Each is written in `extend complex64 { }` as
    `static let +(a:Self, b:Self):Self` (#135, #140), and a mixed one
    as `static let +(a:Self, b:f64):Self`.
- **Functions**: `conj`, `abs`, `arg`, `norm` (`abs` squared), `exp`,
  `log`, `sqrt`, `pow`, `sin`, `cos`, `tan`, `sinh`, `cosh`, `tanh` and
  their inverses, which take their principal values, with C99's branch
  cuts and its signs of zero on them.
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
