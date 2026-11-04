# Changelog

## 0.1.0 (#467)

The first release of Kelvin: C, changed bit by bit, still 100% ABI
compatible. `kelvinc` translates Kelvin into C and hands it to the C
compiler. The changes from C, 469 of them so far, are in
[README.md](README.md#changes-from-c) by topic, and the reasons for each
in [Design.md](Design.md) and [Dialogue.md](Dialogue.md).

### The language

- **Declarations** read left to right: `let k = 42`, `var n:i32 = 0`,
  `let add(a:i64, b:i64):i64`; `let` never changes; types say their
  size, `i8` to `u128`, `f32`, `f64`, `bool` built in.
- **Pointers** are `T^`, `p^` and `p^.m`; `nowhere` is null; `cstr` is
  immutable text; `p.next`, `p.addr`, `p.isNull`.
- **Types**: structs, unions and enums by their bare name, methods on
  any type, `extend T { }` with attributes, operators and subscripts;
  enums with values, `T?` and `Result<T, E>`, with `??`, `!`, `?.`,
  `if let` and `try`.
- **Functions**: function types `(T):R`, anonymous functions with
  `$0`, trailing ones, overloads beside C's.
- **Owners on the heap**, freed when their block ends, moved by
  `return`: `String`, `Bytes`, `Array<T>` (`$[...]`),
  `Dictionary<K, V>` and `Set<T>` (`${...}`), `Bits`, with `map`,
  `filter`, `reduce`, `sorted`, `join` and the rest. See
  [ownership.md](documents/ownership.md).
- **Text**: `print` and `println` of any value, template literals
  `` `n = ${n}` ``, `x.cstr` of any value, numbers read from text,
  `"""` blocks.
- **Ranges and iterators**: `0..<n`, `1...n`, `for x in seq`, lazy
  sequences, `Iterator<T>`.
- **Threads**: `async f(x)` and `await`, a `Task<T>`.
- **C stays C**: `#import <stdio.h> as C`, `#inline C { }`, C's
  precedence, conversions and undefined behavior, as written.

### The library

- **Modules**, each `#import <M>`: `IO` (files, pipes and processes),
  `OS` and `SYS`, `JSON`, `SION`, `MsgPack`, `RegExp` (`$/.../`),
  `UnicodeData`, `math`.
- **Your own modules**: `kelvinc --lib M.k` builds `M.kh` and `libkM`,
  which C can call too.

### Tools

- `kelvinc`: `--run`, `-c`, `--emit-c`, `--lib`, `-O`, `-g`; see
  `kelvinc --help`. `#line` directives point the C compiler's
  diagnostics at the `.k` source.
- `make install PREFIX=...` installs `bin/kelvinc` and
  `lib/kelvin/modules`; kelvinc finds its modules from there.
- VS Code: `make vscode` installs a grammar of Kelvin's own
  (`editors/vscode`).

### Platforms

- Tested in CI on macOS (clang), Ubuntu (clang and gcc) and FreeBSD
  (clang); kelvinc and kc themselves under ASan and UBSan, and the test
  programs under ASan.
- Needs a C11 compiler, GNU make and Python 3 to build; node, zip and
  unzip are optional.
- Windows is not supported.

### Stability

- 0.x is initial development: a later 0.x may change what 0.1.0 has.
- The provisional decisions, the P rows of Design.md and the documents'
  *(provisional Pn)* marks, and Design.md's open questions are deferred
  past 0.1.0, and may change before 1.0.
- kc, Kelvin's compiler written in Kelvin (`selfhost/`), is a preview:
  it builds itself to a fixpoint, in CI, and builds 148 of the 353
  test programs and examples; see [selfhost/README.md](selfhost/README.md).
