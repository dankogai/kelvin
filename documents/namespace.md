# Kelvin: the prelude's name

`Kelvin.name` is the prelude's `name`, whatever the program calls its own: `Kelvin.log(x)` is the prelude's `log` beside a `log` of the program's, as `Swift.print` is Swift's.

## Synopsis

```swift
let log(s:cstr) { println("log: ", s) }            // a log of the program's own
let abs(n:i64):i64 { 42 }                          // with the very types of the prelude's
struct BigInt { digits: cstr }                     // and a type with the name of one of its types

let main():int32 {
    log("I'm okay")                                // the program's
    println(Kelvin.log(Kelvin.sqrt(2.0)))          // the prelude's: 0.3465735902799727
    println(abs(-3), " ", Kelvin.abs(-3))          // 42 3
    let sqrt = 9.0                                 // a variable of the name hides the bare name alone
    println(Kelvin.sqrt(sqrt))                     // 3.0
    let mine:BigInt = {"123"}                      // the program's BigInt
    let big:Kelvin.BigInt = 2n ** 70               // the prelude's, and 123n is always its literal
    println(mine, " ", big)                        // {digits: "123"} 1180591620717411303424n
    return 0
}
```

## Description

`Kelvin` (#600) names the prelude: what a program has with no import.
A program may call its own functions and types by the names the
prelude uses; `Kelvin.name` then still reaches the prelude's.

- **What it names** is what the prelude declares at its top level:
  - a function: `Kelvin.sqrt`, `Kelvin.abs`, `Kelvin.grapheme`, and a
    type's maker, `Kelvin.BigInt("12")`, `Kelvin.c64(1.0, 2.0)`;
  - a type: `Kelvin.BigInt`, `Kelvin.RegExp`, `Kelvin.Match`,
    `Kelvin.c64`, `Kelvin.NormalForm`;
  - a word of an enum of words: `Kelvin.nfc`, `Kelvin.nfd`;
  - `Kelvin.print` and `Kelvin.println`, and the types that are words
    of the language, `Kelvin.String`, `Kelvin.f64`, `Kelvin.SYS`,
    which no program defines: each is the same with `Kelvin.` and
    without.
- **The prelude alone.** It is math, `BigInt`, `RegExp` and
  `UnicodeData`, with `print` and `println`.
  - What a module adds under one of its names is not the prelude's:
    with `#import <BigNum>`, `sqrt(x)` of a `BigFloat` is BigNum's,
    and `Kelvin.sqrt` does not choose it.
  - A name of the program's own is not the prelude's either:
    `Kelvin.point` of a program's `struct point` is an error.
- **`Kelvin` is no name of a program's own**: `let Kelvin = 3`,
  `struct Kelvin` and a member `x.Kelvin` are errors. `kelvin` is
  free.

### Functions

- **`Kelvin.f(...)` chooses among the prelude's overloads alone.** A
  program's `sqrt(x:i64)` is not asked, so `Kelvin.sqrt(2.0)` is
  math's whatever the program adds.
- **A function of the program's with the name and the types of one of
  the prelude's is another function.** The bare name calls the
  program's, and `Kelvin.name` the prelude's.
  - `let log(x:f64):f64 { ... }` took the place of the prelude's
    before, and the prelude's could not be called.
  - `let abs(n:i64):i64 { ... }` did not link: libkelvin defines one
    of that name.
  - Their results may differ: they are two functions.
- **A variable or a parameter of the name** hides the bare name, as
  it does of any function, and not `Kelvin.name`:
  `let f(exp:f64):f64 { Kelvin.exp(exp) }`.
  - Calling it, `let sqrt = 2.0; sqrt(sqrt)`, is kelvinc's error (#620):
    `'sqrt' is a variable here, of f64, which hides the function of
    its name: rename one of them`.
  - A variable of a function type is called as it is:
    `let sqrt:(f64):f64 := half; sqrt(3.0)`.
- **A function's name is a value** with `Kelvin.` too:
  `let f:(f64):f64 := Kelvin.sqrt`.
- **An operator has no `Kelvin.`**, so one of the prelude's own
  types is the prelude's alone (#606): a program's
  `let +(a:c64, b:c64):c64` is an error.
  - An operator of other types stands beside the prelude's: of one
    of its types and one of the program's, and of a type of the
    program's own that has the name of one of the prelude's.

### Types

- **A type of the program's own with the name of one of the prelude's
  hides it under the bare name**, and `Kelvin.T` is the prelude's.
  They are two types, and a message names each as the program writes
  it: `'b' of 'f' is a BigInt, and this is Kelvin.BigInt`.
  - It kept the prelude's out before: a program with its own `BigInt`
    or `RegExp` had none of the prelude's, and one with its own `c64`
    had no math at all.
  - It hides it in the file that defines it and in the files that
    import that file. A module's header that names `c64` means
    math's, whatever the program that imports it defines.
- **A literal is the prelude's**: `123n` is a `Kelvin.BigInt` and
  `$/.../` a `Kelvin.RegExp`, where each was an error beside a type
  of the program's own of the name.
- **`x.typename`** is the type's own name, `BigInt` of either.
- **A member of the name is a member still** (#604), a struct's
  `BigInt: i64` and an extend's `let BigInt`, read after a dot: no
  name of the top level hides it.

### Names of the top level

- **A name of the program's own top level that is no function hides
  the prelude's of that name** (#604), and `Kelvin.name` is the
  prelude's.
  - A variable named as one of the prelude's functions:
    `let exp = 2.5` and `var floor:i64 = 3`, beside `Kelvin.exp(x)`
    and `Kelvin.floor(x)`.
    - C refused it before, "redefinition of 'exp' as different kind of
      symbol": C's `math.h` declares `exp` in every program.
    - `exp(x)` there calls the variable, which is no function, as it
      does of any variable.
  - A word of an enum of the program's own, `enum Tag { nfc, log }`.
  - Anything named as a word of the prelude's enum, `nfc`, `nfd`,
    `nfkc` or `nfkd`: a variable, a function, a type. Every program
    has those four words since #520, so `let nfc = 5` did not build.
- **A function of the program's named as one of the prelude's
  functions** is an overload of it, or another function of its types,
  as above, and hides nothing.
- It hides in the file that defines it and in the files that import
  that file, as a type does.

### A library

- A library, `kelvinc --lib`, may have its own of either kind, and
  its header says so as its source does: `let far(m:Match):Kelvin.BigInt`.
- A program that imports it sees the library's own under the bare
  name, as the library's files do.

## Where it lives

The compilers. `Kelvin.name` is settled in the tokens, once every file is read, by kelvinc's `with_kelvin` (src/main.c) and kc's `kelvin_names` (selfhost/kc.k); what a file of the prelude declares is told by the file's name, UnicodeData, RegExp, BigInt or math.

- A type of the program's own that has the name of one of the
  prelude's is `_kv_own_T` in C, so that the two are two types there.
- A function of the program's own with the name and the types of one
  that libkelvin defines is `_kv_own_f__types` in C.
- `Kelvin.f` where a variable has the name `f` is called through
  `_kv_ns_f`, a constant pointer to the function at the top level,
  which C's variable of the name does not hide.

## Properties and methods

| Written | Names |
|---|---|
| `Kelvin.f(...)` | the prelude's function `f`, chosen among the prelude's overloads alone |
| `Kelvin.f` | that function, a value where a function type says which |
| `Kelvin.T` | the prelude's type `T`: `BigInt`, `RegExp`, `Match`, `BytesMatch`, `c64`, `c32`, `complex64`, `complex32`, `NormalForm`, `CodepointError` |
| `Kelvin.T(...)` | the prelude's maker of a `T` |
| `Kelvin.nfc`, `.nfd`, `.nfkc`, `.nfkd` | the words of the prelude's `NormalForm` |
| `Kelvin.print`, `Kelvin.println` | `print` and `println` |
| `Kelvin.String`, `Kelvin.i64`, ... | a type that is a word of the language, the same as without |
