# Modules: `#import` and `modules/`

How a program brings in Kelvin files, headers and libraries with `#import`, and what `modules/` holds.

## Synopsis

```swift
#import <math>                  // modules/math.k, its source compiled with the program
#import <IO>                    // modules/IO.kh, and libkIO.a beside it
#import <ctype.h> as C          // a C header's names

let main():int32 {
    IO.stdout.println("io")
    println(sin(0.5), " ", toupper(97))
    return 0
}
```

## Description

A Kelvin file is brought into a program with `#import`, and Kelvin's own
files, its prelude header and its libraries live in one directory,
`modules/`. A module is a Kelvin source, `M.k`, or a header and a
library, `M.kh` and `libkM` (#143). This document has the import, the
search, the layout, and the modules so far: `math.k`, `Rational.k`,
`JSON.k`, `SION.k` and `MsgPack.k`, and `IO`, `OS`, `UnicodeData` and `RegExp`, each a
header and a library. C headers are in
[c-interfaces.md](c-interfaces.md).

### Kelvin files: `#import <math>`

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

### A header and a library: `M.kh` and `libkM`

A large module is a header and a library, as a C library is (#143):
`M.kh`, a Kelvin file of declarations, and `libkM.a`, or a shared
`libkM.dylib` or `libkM.so`, beside it, both in `modules/`. `#import
<M>` brings in the header and links the library, with no flag to
write.

<!-- fragment -->
```swift
#import <IO>                    // modules/IO.kh, and libkIO.a beside it
#import <shout>                 // ./modules/shout.kh, and ./modules/libkshout.a

let main():int32 {
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
  - **`libkM.link`** beside the library holds what it needs of the
    system, flags split on whitespace, such as
    `-L/opt/local/lib -lssl -lcrypto`, linked right after it (#482):
    `make` writes `fetch`'s, OpenSSL's flags.
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
  - `UnicodeData` ([unicodedata.md](unicodedata.md), #156) is written in
    Kelvin, modules/UnicodeData.k over its C tables; `make` builds it
    with `kelvinc --prelude` (#504) into `UnicodeData.kh` and an object
    that libkelvin holds; it is the prelude's (#520), in every program
    with no import, as String is.
  - `RegExp` ([regexp.md](regexp.md), #157) is the same over its engine,
    runtime/regexp.c, on `UnicodeData`; it is the prelude's (#504): a
    program that names `RegExp`, or writes a `$/.../` literal, has it
    with no import.
  - `BigInt` ([bigint.md](bigint.md), #507), integers of any size, is a
    module of the prelude too, written in Kelvin alone: a program that
    names `BigInt` has it.
  - A module of the prelude is linked from the static libkelvin.a, as
    the rest of it: a program that uses none of it links none of it.
  - `JSON` ([json.md](json.md)) is built the same from `JSON.k` alone
    (#484), so that `fetch` ([fetch.md](fetch.md)) may import it: a
    module built by `kelvinc --lib` that imports a Kelvin source holds
    its code, and a program that imports the source too would define
    it twice, which the linker refuses.
  - `math.k` stays a Kelvin source, included where it is imported.
    `JSON.k` is the example of how a module is written in Kelvin.

### Building a module: `kelvinc --lib M.k`

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
    - One that owns is declared there alone, with no `= {0}`, which would
      define it in the program a second time; the library frees it as
      the program exits, registered as it is loaded, as a program's main
      registers its own (#491).
  - A C function's prototype, `let exp(x:f64):f64` with no body, is
    `extern let exp(x:f64):f64` there: in a `.kh`, a prototype without
    `extern` is the library's own function.
  - An `inline` function, method or operator (#392) is copied with its
    body, so that a program inlines it, as C's `static inline` in a
    header: it uses what the header declares, not a `static` helper of
    the module.
  - `T.cstr()` is copied with its body: a text method is inline, sized
    by its template, in each file that uses the type.
  - A `static let f()` of the file, C's static, is left out; a
    `static let` of a type is a function of the type, and kept.
  - A type attribute, `static var T.x = v`, waits: a program cannot
    declare one yet, so a library may not hold one.
  - An `#inline C { ... }` at the top level is an `#inline C` of its
    declarations (#199), so that a program sees its names; see
    [c-interfaces.md](c-interfaces.md#inline-c).
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

### Separate compilation: `kelvinc -c`

`kelvinc -c F.k` (#281) compiles a file into an object, `F.o` in the
current directory or the path `-o` names, as `cc -c` does, and links
nothing.

```
kelvinc -c util.k                    # ./util.o
kelvinc -c main.k -o build/main.o    # build/main.o
kelvinc -o app build/main.o util.o   # links the objects into ./app
kelvinc main.k util.o                # compiles main.k, linking util.o, into ./main
```

- **Linking:** `.o` and `.a` files are linked with the source, or
  alone, with `libkelvin`.
  - With objects alone, the program is named after the first, `main`
    of `main.o`, unless `-o` names it; `--run` runs it.
  - Objects no longer show what they import, so kelvinc links the
    library of every module in `./modules` and Kelvin's `modules/`, each
    before the ones it imports. A static library brings in only what is
    called.
- **Calling another file:** a file declares the functions of another
  by their prototypes, `let twice(x:i64):i64`, with no body.
- **Not yet:** two objects that `#import "x.k"` both hold x's functions,
  which the linker refuses as duplicate symbols; a module built with
  `--lib` is how files share code for now.
- **kc** (selfhost/) has `-c` too, and kelvinc links its objects.

### `modules/`

```
modules/                  in the source tree, or $PREFIX/lib/kelvin/modules
    kelvin_prelude.h      the prelude: print, println, the properties
    libkelvin.a           built by make, linked into every program
    libkelvin.dylib|.so   the same, for use from C and other toolchains
    IO.kh, kIO.h          #import <IO> (#144, io.md): the header, and its C header
    libkIO.a|.dylib|.so   its library, linked by the import
    OS.kh, kOS.h          #import <OS> (#145, os.md); SYS is the prelude's (sys.md)
    libkOS.a|.dylib|.so   its library
    UnicodeData.kh        the prelude's, in every program (#156, #520, unicodedata.md), built by make from UnicodeData.k
    kUnicodeData.h        its C header; the Unicode tables are libkelvin's (#504)
    RegExp.kh             the prelude's RegExp (#157, #504, regexp.md), built by make from RegExp.k; $/.../ literals
    BigInt.kh             the prelude's BigInt (#507, bigint.md), built by make from BigInt.k
    kRegExp.h             its C header; the engine is libkelvin's (#504)
    math.k                #import <math> (#148): math.h for f64 and f32, c64 and c32
    Rational.k            #import <Rational> (#538, rational.md): rat64, n.over(d)
    JSON.k                #import <JSON> (#113, json.md)
    SION.k                #import <SION> (#152, sion.md): SION values, text in and out
    MsgPack.k             #import <MsgPack> (#153, msgpack.md): MessagePack of a SION
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

### Math: `modules/math.k`

`#import <math>` brings in `math.h` and its complex counterpart (#148):
the functions of `math.h` for `f64` and `f32`, each a method too,
`x.sin()`, the constants as attributes of the type, `f64.pi`, and `c64`
and `c32`, complex numbers, `complex64` and `complex32` by their
aliases (#150), with `x.i` a quarter turn: see [math.md](math.md).

### UnicodeData: `modules/UnicodeData.k`

The prelude's `UnicodeData` (#156, #520), in every program with no
import, is the Unicode Character Database:
`s.normalize(nfc)`, `nfd`, `nfkc` and `nfkd`, `s.graphemes`, the
grapheme clusters as an `Array<String>`, bound before it is walked, the
case mappings `s.upper()`, `s.lower()` and `s.fold()`, and a
codepoint's, a `u32`'s, `.name`, `.category`, `.combining`,
`.decomposition` and the rest: see [unicodedata.md](unicodedata.md).

### RegExp: `modules/RegExp.k`

`RegExp` (#157) is regular expressions, JS's over Strings, and the
`$/pattern/flags` literal, the prelude's since #504, with no import: `re.test(&s)`,
`re.exec(&s)`, `s.match(&re)`, `s.replace(&re, "$1")`, `s.split(&re)`,
with `\p{...}` by category, script and property, and `\X` for a
grapheme cluster: see [regexp.md](regexp.md).

### BigInt: `modules/BigInt.k`

`BigInt` (#507) is integers of any size, the prelude's, with no import:
`BigInt(1) << 100`, `BigInt("12345678901234567890") * 3`, `b / 7` and
`b % 7` truncated, `b.text(16)`, `b & 0xff`: see [bigint.md](bigint.md).

### Rational: `modules/Rational.k`

`#import <Rational>` brings in rational numbers (#538): `rat64`, two
`i64`s in lowest terms, made by `n.over(d)`, with exact arithmetic and
a float's infinities and NaN: see [rational.md](rational.md).

### SION and MessagePack: `modules/SION.k` and `modules/MsgPack.k`

`#import <SION>` (#152) brings in `SION`, a SION value, JSON with more,
as an enum with values keyed by any value, with `SION.parse(text)` and
`SION.stringify(&s, space)`: see [sion.md](sion.md). `#import <MsgPack>`
(#153) packs one into MessagePack and back, `MsgPack.pack(&s)` and
`MsgPack.unpack(&b)`: see [msgpack.md](msgpack.md).

### JSON: `modules/JSON.k`

`#import <JSON>` brings in `JSON`, a JSON value as an enum with values,
with `JSON.parse(text)` and `JSON.stringify(&j, replacer, space)` as JS
has them (#113): see [json.md](json.md).

## Where it lives

`#import` is the core. What it brings in is loaded explicitly: `modules/math.k`, with the functions of math.h and `c64` and `c32`, comes only with `#import <math>`, `IO` and `OS` only with `#import <IO>` and `#import <OS>` (#144, #145), and a C header's names only with `#import <x.h> as C`.
