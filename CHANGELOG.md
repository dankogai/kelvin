# Changelog

## 0.1.1 (#496)

`fetch()` and `localStorage`, JS's, as modules, with fixes found on the
way: #468 to #495.

### The library

- **`#import <fetch>`**, JS's `fetch()`, an HTTP/1.1 client of its own,
  HTTPS by OpenSSL ([fetch.md](documents/fetch.md)):
  - `fetch(url)` and `fetch(url, init)` give a
    `Result<Response, Error>` (#482, #483);
  - `RequestInit`: method, headers, body, redirect, `timeout` in `f64`
    seconds, `signal` from an `AbortController`, `stream`, `cookies`
    (#483, #486 to #489);
  - `res.text()`, `res.json()` (#484), `res.stream`, an `IO`, for a
    body that streams (#488);
  - a `CookieJar` kept across fetches and redirects, saved and loaded
    as curl's cookies.txt (#489, #490);
  - `make HAS_SSL=0` builds it without HTTPS; CI builds it with HTTPS
    on macOS, Ubuntu and FreeBSD.
- **`#import <localStorage>`**, JS's: the global `localStorage`,
  `getItem`, `setItem`, `removeItem`, `clear`, `length`, `key(i)`, kept
  in a JSON file of the program's (#491)
  ([localstorage.md](documents/localstorage.md)).
- **JSON** is built as a library, `JSON.kh` and `libkJSON`, which a
  module may import (#484).

### The language

- **A global** C cannot initialize, one that owns or of a value that is
  not a constant, is given its value at its first use, once, on any
  thread: `var names = $["a"]`, `let start = OS.time` (#493).
- **Printing** pastes back: a `uchr` inside a value is `uchr("é")`
  (#479), a fixed array `[a, b]` (#481).
- **`uchr`**: a walk of uchrs stops at `uchr(0)`, and `for n:u32 in s`
  gives each codepoint's number (#480); `uchr(s)` is the first codepoint
  of a String or a Bytes (#494).
- **An enum's value** is C's int to an integer's methods, `.bit(n)`,
  `.abs` and the rest (#469).
- **`i64(&s)`** of a String or a Bytes by reference reads its text, as
  `i64(s)` does (#495).

### Fixes

- Kelvin errors in words where C's came before: `x as uchr` (#468), an
  enumerator changed (#469), `uchr(2.5)` and `uchr(true)` (#494), an
  overload declared after a call that needs it (#492).
- An owner moves into a setter or a subscript's index, where it was
  freed twice (#474); a global owner assigned anew frees what it held
  (#493); `i64(&s)` gave the pointer's address (#495).
- tests/run.sh reads an error test's text byte by byte, under any
  locale (#485).

### kc

- kc, the compiler in Kelvin, reads more of kelvinc's Kelvin: trailing
  functions, a struct's operators, every integer type, attributes,
  subscripts, types with no tag, an enum's tag, `uchr` (#470 to #478),
  and the fixes above.

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
