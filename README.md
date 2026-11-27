# kelvin

[![CI](https://github.com/dankogai/kelvin/actions/workflows/ci.yml/badge.svg)](https://github.com/dankogai/kelvin/actions/workflows/ci.yml)

Yet another attempt to improve C: a quiet alternative that starts from bare
C and changes it bit by bit, while staying 100% ABI compatible.

C is also the symbol for Celsius, and Kelvin is its natural successor. The
step size is identical, so everything you know about C carries over one to
one.

## Synopsis

```swift
#import <stdio.h> as C              // for printf()

let fizzbuzz(n:i64):String {
    var r = $""                     // String()
    if n % 3 == 0 { r += "fizz" }   // or $"fizz"
    if n % 5 == 0 { r += "buzz" }   // or $"buzz"
    if r.isEmpty  { r = String(n) } // .count == 0, as of any collection
    return r                        // moved out to the caller
}

let main(argc:i32, argv:[cstr]): i32 {
    let n = {                       // an anonymous function, called in place
        (k:i64):i64 in k <= 0 ? 30 : k
    }( argc < 2 ? 0 : i64(argv[1]) ) // i64(text) reads the number in it
    for i in 0...n {                // a closed range, 0 to n
        // println(`fizzbuzz(${i}) = ${fizzbuzz(i)}`) prints the same
        printf("fizzbuzz(%lld) = %s\n", i, fizzbuzz(i).cstr)
    }                               // each String freed after its printf
    return 0;                       // a C-style `;` is fine too
}
```

## Documents

- [documents/README.md](documents/README.md) lists the documents, one
  topic each: [cstr.md](documents/cstr.md),
  [strings.md](documents/strings.md),
  [bytes.md](documents/bytes.md), [arrays.md](documents/arrays.md),
  [functions.md](documents/functions.md), ...
- [documents/versusC.md](documents/versusC.md) has all the differences
  from C at a glance.
- [documents/gotcha.md](documents/gotcha.md) says what Kelvin is not,
  for one who comes from Swift, JavaScript or Python: no closures, no
  generics or protocols of a program's own, no exceptions, no garbage
  collector, and what to write instead.
  - Each document says whether what it covers is the core, the
    prelude, or loaded with an `#import`; versusC.md sums that up.
- [CHANGELOG.md](CHANGELOG.md) has the release notes, 0.1.0 the first
  (#467), 0.1.1 with `fetch()` (#496), 0.2.0 with `RegExp` and
  `BigInt` in the prelude (#514), 0.3.0 with math in the prelude,
  `Kelvin.name`, a String of graphemes and the numbers of any size
  (#608), 0.4.0 with C's last features, `<Combinatorics>` and Kelvin's
  own errors where C's came (#650), 0.4.1 the latest, with `<Prime>`,
  `_` among a literal's digits, more of those errors and kc building
  every program kelvinc builds (#750).
- [TODO.md](TODO.md) is what is left, checked against the code (#658).
- [Design.md](Design.md) has the design decisions, and
  [Dialogue.md](Dialogue.md) how they were made.
- [Style.md](Style.md) is how Kelvin code is written.
- The changes from C are listed [at the end](#changes-from-c);
  everything else is C.

## Examples

Each one ends with the output it prints, as `// out:` lines, which
`make test` checks; a quine, marked `// quine:`, prints its own file, and
`make test` checks that (#465).

| File | Shows |
|------|-------|
| [examples/hello.k](examples/hello.k) | the smallest program |
| [examples/fizzbuzz.k](examples/fizzbuzz.k) | a `String` built with `+=`, `.isEmpty`, `String(n)`, moved out by `return`; a closed range, a template literal, a Range mapped to an Array |
| [examples/primes.k](examples/primes.k) | a `bool` array, nested ranges, `continue` |
| [examples/strings.k](examples/strings.k) | a `String`'s graphemes, codepoints and bytes, `s[i]`, a slice, `.upper()`, `.find`, `.split` and `.replace` with a `RegExp`, `.normalize(nfc)`; `cstr`, `for c in s`, a `u8^` cursor with `p++`; `.hex` and friends |
| [examples/shapes.k](examples/shapes.k) | structs, `extend` blocks of methods and attributes, derived `.cstr` text, the prelude's `hypot` and `f64.pi` |
| [examples/linkedlist.k](examples/linkedlist.k) | references (`^`, `:=`), `malloc`/`free`, an `extend list` block whose var methods change the list they are called on, `l.push(v)`, and whose methods read it, `for n in head` |
| [examples/sort.k](examples/sort.k) | `$[T]`'s `sort` and `sorted`, by `<`, by an anonymous function with `$0` and `$1` or by a named one; `map`, `filter`, `reduce`, `prefix` and `reversed` chained; an Array of structs; Strings sorted and joined |
| [examples/sequences.k](examples/sequences.k) | iterators, structs with a `var` method `next()`: `for`, `map` and `reduce` of one that ends, `prefix` of one that never does; `(2...).lazy.filter(prime)`, a Range with no end, filtered lazily |
| [examples/wordfreq.k](examples/wordfreq.k) | word frequencies: the prelude's `RegExp` and `.split`, a `Set<String>` of words to leave out, a `Dictionary<String, i64>` counting the rest, an Array of structs that own their words, sorted by count |
| [examples/calc.k](examples/calc.k) | a calculator: an enum with values for tokens, `switch` binding a case's value, the shunting-yard algorithm with Arrays as stacks, each step a `Result` and `try` passing an `err` up, `if let` |
| [examples/results.k](examples/results.k) | `Result<T, U>` wrapping C's `timespec_get`; an `IO`'s `f.error` as an `err`, `f.lines`, `OS.mkstemp` and `OS.env`'s `cstr?`; a `String` error from text, an `err` passed up by `try`, `if let`, `??`, `switch` |
| [examples/tasks.k](examples/tasks.k) | `async f(x)` and `await`: four `Task<i64>`s in an Array count primes at once, and a `Task<String>` moves its owner out to the caller |
| [examples/bfi.k](examples/bfi.k) | a brainfuck interpreter: a struct that owns a `Bytes` and an `Array`, `Result` and `if let err(why)`, a `switch` on bytes, `argv`, `IO`'s `f.bytes`, `IO.stdin.byte` and `IO.stdout.write`; `!` ends the program and starts its input |
| [examples/bfc.k](examples/bfc.k) | a brainfuck compiler to Kelvin source, which kelvinc then compiles: slices, `for c in bytes`, a `String` built of escapes, `IO` for the file and for what it writes, `argv` |
| [examples/complex.k](examples/complex.k) | the prelude's `c64` and `f64.pi`, overloaded functions beside C's, operators: roots of a quadratic and of unity, a Fourier transform; a number to four decimals by a template |
| [examples/ski.k](examples/ski.k) | SKI combinator logic, and Iota and Jot compiled to it: terms as nodes of an `Array` of structs by index, a global owner, recursive descent through an `i64^` cursor, reduction to a normal form, `String` built with `+=` (#201) |
| [examples/lambda.k](examples/lambda.k) | the untyped lambda calculus, written with `λ`: Church numerals and Wikipedia's definitions, `FACT 3` by `Y`, de Bruijn indices that never capture, names primed with `′` where they would; a `String` read by codepoint, functions over a `reader^` that call each other through a prototype (#202) |
| [examples/quine.k](examples/quine.k) | a quine: a String holding the program with a mark where the String goes, printed with itself written as a literal at the mark, its quotes, backslashes and newlines escaped; `for c in s`, `.utf32` (#465) |
| [examples/quine_cheat.k](examples/quine_cheat.k) | a cheating quine, Perl's `open 0; print while <0>`: `for line in IO(__FILE__).lines`, C's `__FILE__` being the source's path through kelvinc's `#line`, the IO held for the loop (#465, #466) |

## Build and use

Requires:

- a C11 compiler, as `cc`, clang or gcc;
- GNU make, which reads `GNUmakefile`;
- Python 3, which makes the Unicode tables of the runtime from
  `tools/ucd/` (#156), and writes `modules/Rational.k` (#541);
- optional: `node` for `tests/grammar.js`, and `zip` and `unzip` for
  `make vsix` (#190, #191).

On FreeBSD (#193):

- Install GNU make and Python 3 with pkg, or from the ports:
  - `pkg install gmake python3`;
  - or the ports `devel/gmake` and `lang/python3`.
  - Optional: `pkg install node zip`, or `www/node` and `archivers/zip`.
- Then `make`, BSD make, reads `Makefile`, which hands each target to
  `gmake`: `make`, `make test` and the rest work as below.
- Variables go to `gmake` itself: `gmake install PREFIX=~/.local`.

```sh
make                        # builds ./kelvinc, modules/libkelvin.{a,so|dylib} with RegExp, libkIO and libkOS
make test                   # runs tests/run.sh, and tests/docs.sh: the documents' examples compile; tests/grammar.js
make asan                   # runs tests/asan.sh: every test program under ASan, nothing live at exit
make install PREFIX=~/.local # bin/kelvinc and lib/kelvin/modules/
./kelvinc hello.k           # builds ./hello
./kelvinc --run hello.k     # builds and runs
./kelvinc --emit-c hello.k  # prints the generated C
./kelvinc --lib geo.k       # builds the module geo: modules/geo.kh, libkgeo.a and libkgeo.dylib|.so
./kelvinc --runtime runtime/string.k  # an object of the runtime, for libkelvin (#289)
./kelvinc --prelude modules/RegExp.k -o build/prelude  # a module of the prelude: RegExp.kh and RegExp.o, for libkelvin (#504)
./kelvinc -c util.k         # builds the object util.o (#281)
./kelvinc -o app main.o util.o  # links objects, or main.k util.o, into ./app
```

## Self-hosting

- [selfhost/](selfhost/README.md) is experimental (#204, #230): `kc`, a
  compiler of a subset of Kelvin, written in that subset alone, which
  `selfhost/bootstrap.sh` builds in stages to a fixpoint, in CI
  (#228).
  - Its README lists what stands in the way of a Kelvin kelvinc.
  - `selfhost/errors.sh` runs kc over the programs kelvinc refuses,
    `tests/error`, against a list of those it does not yet refuse in
    kelvinc's words, in CI too (#609), at kelvinc's line and column
    (#690).
- **The runtime in Kelvin** (#289): `runtime/*.k`, which
  `kelvinc --runtime` builds into `libkelvin` beside its C.
  - Its `kv_` functions keep the names `kelvin_prelude.h` declares,
    which the C kelvinc writes calls; only `--runtime` may name one so,
    and the modules of the prelude, RegExp and UnicodeData, their
    helpers `kv_rx_` and `kv_ucd_` (#504).
  - `runtime/string.k`: a String's `find`, `has`, `starts`, `ends`
    and `trim` (#289), and `escape` and `unescape` (#290).
  - `runtime/bytes.k`: a Bytes's `toBase64` and `Bytes.fromBase64`
    (#290).
  - `runtime/task.k`: a Task's thread, started, awaited and freed
    (#312).
  - `runtime/random.k`: `T.random()` of the number types and of bool
    (#547), over the system's bits, which `runtime/random.c` asks for.
  - `runtime/os.k`, built into `libkOS` beside `runtime/os.c`, whose C
    it takes over a group at a time (#301): the working directory, the
    environment, files by path and the process ids; stat and the
    existence checks (#303); directories, walk and glob (#304); users,
    groups and a file's owner (#305); paths (#306); processes and time
    (#309); temporary files (#310); the system (#311) so far.

## Editors

- **VS Code**: [editors/vscode](editors/vscode) colors Kelvin with a
  TextMate grammar of its own (#190); `make vscode` installs it (#191).
- **GitHub** colors `.k` files and the documents' examples as Swift,
  which Kelvin reads most like (#189).

## License

MIT

## Changes from C

So far the changes from C are these, by topic.

### Syntax and statements

- variables are declared with `let`, which never changes (C's `const`), or
  `var`: `let k = 42`, `var n:i32 = 0`; the type follows the name, and
  functions are lets too, `let add(a:i64, b:i64):i64`, whose parameters
  are lets unless written `var`, and `_` leaves one unnamed,
  `let on_signal(_:i32)` (#388)
  - a global C cannot initialize, one that owns or of a value that is not
    a constant, is given its value at its first use, once, on any thread,
    as Swift's globals are: `var names = $["a"]`, `let start = OS.time`
    (#493)
- pointers are a postfix `^` (`i32^`, `p^`, `p^.m`), and are assigned
  with `:=` (`buffer := malloc(n):i64^`), while `=` assigns values
  - a member a type does not have is an error in words, `p.m` of a
    pointer naming `p^.m`, where it was C's; the runtime's own C fields,
    as `s.b`, are no members (#497)
- XOR is `~`
- there are no C casts: convert with `i32(x)`, `malloc(n) as u8^` or
  `0xdead:u16`
- a `;` may be left out at the end of a line, and a function whose body is
  one expression returns it: `let square(x:i64):i64 { x * x }`
- `switch` is Swift's: a case ends at the next, `case 1, 2:` shares a
  body, `fallthrough` goes on into the next, and every value is handled,
  by every case or by `default:`
- conditions are `bool`, with no parentheses and block bodies:
  `if n > 0 { ... }`, `while p != nowhere { ... }`; comparisons give a
  `bool`, so `println(a == b)` prints `true`, and `let ok = a < b`
  declares one
- assignment is a statement, and `++` and `--` step only a pointer, as
  statements: `p++`; a number takes `i += 1`
- counting loops use ranges: `for i in 0..<n { ... }` and
  `for i in 1...n { ... }`, where `i` is a `let`
- `for c in s { ... }` walks a string up to its NUL, and
  `for n in head { ... }` a list along `next`
  - `for n:u32 in s` gives each codepoint's number (#480)

### Types

- structs, unions and enums are types by their bare name: `var p:point`
  for `struct point`; a struct or a union with no tag is written by its
  members where a type goes, `var v:{x:f64, y:f64} = {3.0, 4.0}`,
  `var u:union{i:i32, f:f32}`; one defined inside a struct is named
  bare there and by its path outside, `shape.size` (#389), and one
  defined in a function is its block's (#391)
  - an array of structs with no fields, of size 0, counts by its
    declared length, `[none](4).count` 4, where `sizeof(a) /
    sizeof(a[0])` was 0 / 0; that length is a constant, not a local's
    (#499)
- an `enum` whose cases carry values is a union that knows its case,
  with a byte for the tag: `enum json { null; n: f64; s: String; a:
  Array<json> }`, made as `json.n(1.5)`, read as `j.n` (checked), tested
  with `j.is(n)` and `switch j { case n: ... }`, and printed as it is
  made, `json.n(1.5)`, so that the text pastes back (#529)
- there is no `void`: `any^` is C's `void *` and `nowhere` its null, and a
  reference declared without a value is `nowhere`
  - a number, a struct, an enum and a fixed array declared without a
    value in a function are zero (#761), as an owner is empty, where C
    left them unset
- numeric types always say their size (`u8`…`u64`, `i8`…`i64`,
  `i128`/`u128`, `f32`, `f64`, or by their full names `uint8`, `int64`,
  `float64`), so `char`, `int`, `long`, `float` and `double` are gone,
  and `let i = 42` is an `i64`
- `bool`, `true` and `false` are built in; `!!n` is the `bool` of an
  integer 0 or 1 (#387), and a number's bits, `.bits`, each a `bool` by
  its place, take the place of C's bit-fields
  - an integer's bit is `x.bits[n]`, set with `x.bits[n] = b`, and
    `x.bits[n].flip()` flips it; `x.bits` is its bools, an
    `Array<bool>`, and `u8(bools)` the way back (#530); `b.flip()` is
    `b = !b` (#454)
  - `Bits`, a type of its own (#387, #455), is no more (#532): the word
    is an error that names `x.bits` and a `BigInt`'s `b.bits`
  - an integer type has its limits, `i64.max` and `u8.min`, of every
    width, with no import (#545), C's `INT64_MAX`
  - `T.random()` is a value of a number's type or of `bool` by the
    system's random bits, with no seed and no import (#547), as Swift's:
    `i64.random(1...6)` a die's roll, `f64.random()` from 0.0 up to 1.0,
    `bool.random()` a coin's toss; C's `rand() % 6` is neither even nor
    hard to guess
  - a floating-point type has its constants, Swift's `FloatingPoint`'s,
    with no import (#546): `f64.pi`, `f64.infinity`, `f64.nan`,
    `f64.greatestFiniteMagnitude`, `f64.leastNonzeroMagnitude`,
    `f64.ulpOfOne`, C's `DBL_MAX`, `DBL_TRUE_MIN` and `DBL_EPSILON`
- `Result<T, U>` is a value with an outcome, `ok(v)` or `err(e)`
  - `r.ok` checked, `r ?? 0`, `r.is(err)`, `if let v = r { } else { r.err }`
  - `switch r { case ok: ... case err: ... }`, `if let err(e) = r { }`,
    `r.map(f)`
  - `let v = try f()` passes the `err` up
  - `T?` is its special case, a value that may be absent, `none` or
    `some(v)`: `var x:i64? = none`, `x = 3`, `x.some`, `x ?? 0`
- properties
  - `x.size` is `sizeof(x)`
  - integers have `.dec`, `.hex`, `.oct` and `.bin` text, and `f32`/`f64`
    have `.dec` and `.hex` (`(42:i32).hex` is `+0x2a`)
  - pointers and functions have `.addr`, the address as a `uintptr_t`,
    `.hex`, as in `0x000000016ee86888`, and `.isNull`
  - `x.type` is `x`'s type where a type goes, as in `var y:x.type`, and
    `x.typename` its name, as in `"i64"`

### Functions and methods

- every type can have methods, such as `let point.area():f64 { ... }`
- function types are `(T, U):R`, as in `before:(i64, i64):bool`
- anonymous functions enclose nothing, are inline (C's `static inline`),
  and may follow a call as its last argument: `sort(xs, n) { $0 < $1 }`,
  where `$0` and `$1` are the parameters
- functions overload by their parameter types; C's function of a name
  is called only where no Kelvin function has it (#223): beside
  `let sin(z:c64):c64`, C's is declared, `let sin(x:f64):f64`, as
  math declares it, so that `sin(0.5)` is C's
  - a function, a method, an operator or a function of a type may be
    called before it is written, as in Swift: kelvinc writes its
    prototype where it is needed, every overload seen (#505)
- a function with no result is `let f() { }`, or `let f():() { }` with
  the result written out; the two mean the same
- `extend T { }`, as Swift's `extension`, holds a type's methods
- a type's own text, of any length, is `let T.string:String { ... }`,
  which print shows whole (#506)
  `let f()`, functions `static let f()`, computed attributes
  `let area:f64 { .w * .h }` read as `r.area`, attributes with a setter
  `var celsius:f64 { get { ... } set(v) { ... } }`, type attributes
  `static var count:i64 = 0` read as `T.count`, computed ones
  `static let origin:Self { ... }` read as `T.origin`, operators
  `static let +(a:Self, b:Self):Self`, and subscripts `let [](i:i64):R`;
  in every member `.w` is `self.w` and `Self` is `T`; each also written
  alone, `let T.area:f64 { ... }`
- structs and unions may define operators:
  `let +(a:money, b:money):money { ... }`, then `a + b`
  - the bitwise `& | ~ << >>` and unary `~` too, `~` of two values its
    xor (#502)

### Text and printing

- `print()` and `println()` come from a small prelude in `libkelvin`, so
  `println("n = ", n)` works for any type with no import
- `Bytes` and `String` are owned text on the heap, with
  `b.toBase64(url, nopad)` and `Bytes.fromBase64(text)` built in
- every number, bool, pointer and Kelvin struct has its text as `x.cstr`
  - a struct's is derived, as `{x: 3, y: 4}`, or defined as one template,
    `let point.cstr():cstr { `(${.x}, ${.y})` }`, where `.x` is `self.x`
  - `cstr` is immutable text, C's `const uint8_t *`, with `s.count` for
    its length
  - a String of it is `String(x.cstr)`; `toString()` and `fmt()` are no
    methods (#22)
- `print` and `println` show any value whole: `println(xs, " ", ages)`
  prints `[1, 2] {"ann": 31}`, with Strings inside quoted, and
  `println(cfg.pretty)` the same indented, a line for each item
  - `i64(&s)` of a String or a Bytes by reference reads its text, as
    `i64(s)` does, where it converted the pointer (#495)
  - a fixed array is `[a, b]`, as inside a struct, where it was its
    address (#481)
- quoting text
  - template literals: `` `Hello, ${name}!` `` may span lines, and
    `${x}` is `x`'s text as `print` shows it, kept on the stack (a string
    value is cut at 256 bytes)
  - `"""` on its own lines quotes text as written, with no escapes
  - `$"..."` and `` $`...` `` make a `String`
- converters read numbers from text, as C's `strtol` and `strtod` do:
  `i64("42")`, `i32("755", 8)`, or as a property, `"42".i64`

### Owners on the heap

- owners on the heap, each freed when its block ends, moved by `return`
  and by passing, copied only by `.copy()`, borrowed as a pointer
  - a check that fails at run time, `b[i]` past the count, text that is
    not UTF-8, a pattern that is not one, prints its reason and exits
    with status 1; `KELVIN_ABORT=1` in the environment makes it abort
    instead, for a debugger or a core (#174)
  - an owner that moves out in an expression is named nowhere else in
    it, as C may read it after the move: `f(s, s)` and `s.count + f(s)`
    are errors, but `s = f(s)` (#500)
  - an operator is lent an owner operand, which its caller keeps:
    `a * a + b` leaves `a` and `b` (#501); so is a parameter written
    `b:lent T`, `let total(a:lent bag, b:lent bag)` (#510)
  - a local owner named in a struct's literal moves into it, as into a
    call: `return (Big){r, false}` takes `r` (#503)
  - `Bytes` is a growable array of bytes: `b += "more"`, `b[i]` checked
  - `String` is a `Bytes` of well-formed UTF-8, counted and walked by
    grapheme, each a String, its codepoints each a `u32` (#522, #528);
    `` $`a${x}b` `` builds one from a template, with no bound;
    `s.find(text)`, `s.has(text)`, `s.starts(text)`, `s.ends(text)`
    and `s.trim()` (#177)
  - `Array<T>` is a growable array of any value type, owners included;
    `xs.join(", ")`, or `.joined(", ")`, is a String of its elements
    as a template shows them (#461)
  - `$"text"` and `$[1, 2, 3]` are a `String` and an `Array` for short,
    and `$[i64]` the type `Array<i64>`
  - `Dictionary<K, V>` is a hash map, `${"ann": 31}`, keyed by integers
    or Strings: `d[k]` an Optional, `d[k]!` checked, `d[k] ?? v`,
    `d[k]?.m` (#218), `d.has(k)`, `d.find(k)`, `for k, v in d`, `d.keys`
    and `d.values`
  - `Set<T>` is a hash set, `${3, 1, 4}`: `s += x`, `s.has(x)`, `s | t`,
    `s & t` and `s ~ t`
  - every collection has `x.isEmpty`, its `.count == 0`; an iterator's,
    which has no count, is `false` (#434)

### Modules and the library

- C headers are imported with `#import <stdio.h> as C`, and C of your
  own goes in `#inline C { ... }` (#197)
- a module is a Kelvin source, `#import <JSON>`, or a header and a
  library, `M.kh` and `libkM` in `modules/`, which `#import <M>` brings
  in and links by itself, as `IO` and `OS` are; `kelvinc --lib M.k`
  builds a Kelvin file into one
- `IO` is a file as an owner, closed when its block ends, a module:
  `#import <IO>`
  - `let f = IO(path, "r")`, with `f.error` when it did not open
  - `for line in f.lines { }`, `for chunk in f.read(4096) { }`,
    `let s = f.string`, a line and the whole a `Result<String, i64>`
    (#406)
  - `f.write("x")`, `IO.stderr.println("n = ", n)`
- `#import <JSON>` is JSON as an enum with values: `var j = JSON.parse(text)`,
  `j.object["k"].array[0].number`, `JSON.stringify(&j, "  ")` (#113)
- `#import <SION>` is SION, JSON with more, data, dates, exts and any
  value as a key: `SION.parse(text)`, `s["key"]`, `SION.stringify(&s, 2)`;
  `#import <MsgPack>` packs one into MessagePack, `MsgPack.pack(&s)`,
  and back, `MsgPack.unpack(&b)`
- `UnicodeData`, the prelude's, in every program (#520), is the Unicode
  Character Database:
  `s.normalize(nfc)`, `s.graphemes`, the clusters a reader sees as
  characters, `s.upper()`, `s.fold()`, and a codepoint's `.name` and `.category`,
  of a `u32` (#156, #527): `$"é".codepoints[0].name`
  - `String.fromCodepoints(0x48, 0x69)` and `grapheme(0x65, 0x301)`,
    the first grapheme alone, make a String of codepoints, in a
    `Result<String, CodepointError>` (#526)
- `RegExp` is regular expressions, JS's over Strings, with the
  `$/pattern/flags` literal: `re.test(&s)`, `s.match(&re)`,
  `s.replace(&re, "$1")`, `s.split(&re)`, `\p{Script=Greek}` and `\X`
  for a grapheme cluster (#157)
  - the prelude's, as JS's and Swift's are, with no import: a program
    that names it has it, and one that does not links none of it;
    `#import <RegExp>` still builds (#504)
- `BigInt` is integers of any size, the prelude's, as Python's `int` and
  JS's `BigInt`: `BigInt(1) << 100`, `BigInt("123456789012345678901") *
  n`, `+ - * / %` truncated, comparisons, `& | ~ << >>`, an `i64` on
  either side, `b.text(16)` (#507); `123n`, `0xffn` and `0b101n` are
  BigInt literals, as JS's (#508), and `0o17n` (#561); `b ** e`, Python's `pow(b, e, m)`,
  `a.gcd(b)`, `a.lcm(b)`, `a.isqrt()` (#511); `i64(b)` and `f64(b)`
  are `b.i64` and `b.f64`, as a converter of a struct is its attribute
  (#512)
  - its bits are an integer's, of any width: `b.bits`, an
    `Array<bool>` whose last bool is its sign, `b.bits[n]`, read and
    set where it is, past its top too, `b.bits[n].flip()`, and
    `BigInt(bools)` the way back (#531)
- `T(v)` is a converter, never C's cast: the nearest value `T` holds,
  `u8(300)` is 255, `i64(1e30)` i64's largest, NaN 0; `v as T` is C's,
  which wraps (#513)
- `#import <fetch>` is JS's `fetch(url)`, a GET over HTTP and HTTPS:
  `var r = fetch("https://example.com/")`, a `Result<Response, Error>`,
  `res.status`, `res.headers["content-type"]`, `res.text()`; HTTPS is
  OpenSSL's, where `make` builds with `HAS_SSL=1`, the default (#482)
  - `fetch(url, (RequestInit){.method = $"POST", .headers = ..., .body = Bytes("x")})`
    sends a method, headers and a body, and `.redirect` follows, gives or
    refuses a redirect (#483)
  - `res.json()` is the body as a `JSON`, a `Result<JSON, Error>`;
    `JSON` is built into `libkJSON` for it (#484)
  - `.timeout = 2.5`, seconds as an `f64`, bounds the whole request,
    redirects and all (#486)
  - `var c = AbortController()`, `.signal = c.signal` in a fetch on a
    task's thread, and `c.abort()` ends it at once (#487)
  - `.stream = true` gives the body as it comes, `res.stream` an `IO`,
    `for chunk in res.stream.read(65536)`, and `res.streamError` what
    ended it (#488)
  - `var jar = CookieJar()` and `.cookies = jar` keep and send cookies
    across fetches and redirects, as RFC 6265 has them; `res.setCookies`
    is each Set-Cookie apart (#489)
  - `jar.save(path)` and `jar.load(path)` write and read it as curl's
    cookies.txt (#490)
- `#import <localStorage>` is JS's `localStorage`:
  `localStorage.setItem("k", "v")`, `localStorage.getItem("k")` a
  `String?`, kept in a JSON file of the program's between runs (#491)
- `OS` and `SYS` are the system and the program, as Python has them, one
  module, `#import <OS>`: `OS.cwd`, `OS.env("HOME")`, `OS.listdir(dir)`,
  `OS.isdir(p)`, `OS.system(cmd)`, `SYS.argv`, `SYS.platform`, `SYS.exit(1)`
- `async f(x)` makes a call on a thread of its own and gives a
  `Task<R>`, and `await t` its value, once; the arguments are passed
  as any call's, a value copied and an owner moved in (#312)
- math is `math.h` and its complex counterpart, the prelude's, with
  no import (#591): its functions for `f64` and `f32`, each a method
  too, `x.sin()`, its constants as attributes of the type, `f64.pi`,
  and `c64` and `c32` with their arithmetic and elementary functions,
  `x.i` a quarter turn
- `#import <M>` of a Kelvin file is its source, from `./modules` or
  Kelvin's own `modules/`: `#import <SION>`
- an overlay comes with two modules: where `<A>` and `<B>` are both
  imported, `modules/A+B.k` is imported too, as Swift's cross-import
  overlay; Kelvin has no `#if` to ask with (#551)
- `#import <Rational>` is rational numbers: `1.over(3)` is `(1/3)`, a
  `rat64` of two `i64`s in lowest terms, with exact `+ - * /` and
  comparisons; a denominator of 0 is an infinity and `(0/0)` a NaN, as
  a float has them, and a result that does not fit is a NaN (#538)
  - `rat32`, `rat16` and `rat8` are the same of `i32`s, `i16`s and
    `i8`s; only signed integers have `.over`, and two widths do not
    mix: `rat64(r)` converts (#539)
  - `BigRat` is of two `BigInt`s, a fraction of any precision:
    `1n.over(3n)` is `(1n/3n)`, and every result fits (#540)
  - with `#import <BigNum>` there is `CBR`, a complex number of two
    BigRats, exact in `+ - * /`: `1 / CBR(3, -4)` is
    `((3n/25n)+(4n/25n).i)` (#552)
  - and math's functions take a BigRat, each to a precision in bits,
    128 where none is written: `sqrt(BigRat(2), 64)`, `x.exp()`,
    `BigRat.pi(256)`; reckoned in BigInts, the same on every system
    (#553)
  - and a `CBR` too: `exp(z, 64)`, `z.sqrt()`, `abs(z)`, each part
    within `2^-precision`, the inverses with C99's branch cuts (#554)
- a complex number has the texts of its parts: `c64(1.5, -2.0).hex` is
  `(+0x1.8p0-0x1p+1.i)` and its `.dec` `(+1.5-2.0.i)`, which paste
  back as the number; a `CBR` has `.hex`, `.oct` and `.bin`, as a
  BigRat (#559)
- `+x`, the prefix, of a struct is its value where the type has a unary
  `-`: `+1n` is `1n`, so a `BigInt`'s `.hex`, `+0xffn`, pastes back, and
  `+n` of a variable is a new `BigInt`, as `-n` is (#563)
- a rational is read from its text by its type: `rat64("8/-12")` is
  `(-2/3)`, `BigRat("8/-12")` is `(-2n/3n)`, and `rat64(r.hex, 16)` is
  `r`; its `.hex`, `.oct` and `.bin` have the sign on the numerator
  alone, `(-0x2/0x3)` (#565); text with no number is a NaN,
  `rat64("abc")` is `(0/0)` (#567)
- a rational reads a number as an `f64`'s text is written, and exactly:
  `rat64("1.5")` is `(3/2)`, `rat64("2.5/1.5")` is `(5/3)`,
  `rat64("0.1")` is `(1/10)` and `rat64("1.5e-3")` is `(3/2000)`; all
  of the text is read, so `rat64("5x")` is a NaN (#568)
- a complex number is read from its text by its type: `c64(z.dec)`,
  `c64(z.hex)` and `c64("{real: 1.5, imag: -2.0}")` are `z`, the sign
  of a zero too, and `c64("1.5")` and `c64("2.0.i")` a part alone;
  `c32(text)` likewise, and with `<BigNum>` `CBR(text)` and
  `CBR(z.hex, 16)` (#569)
- `print` of a complex number writes `(a+b.i)`: `c64(1.5, -2.0)` is
  `(1.5-2.0.i)`, each part as `print` writes a float, both always, a
  zero with its sign, `(-0.0+0.0.i)`; a `CBR` is
  `((1n/2n)+(-1n/3n).i)`; it is the type's `.string`, in a template
  and `.cstr` too, and `c64(text)` and `CBR(text)` read it back (#570)
- a `CBR` by 0 keeps a part that is 0: `CBR(1) / CBR(0)` is
  `((1n/0n)+(0n/1n).i)`, where its imaginary part was `0 / 0`, a NaN;
  each part that is not 0 is an infinity by its sign, and `0 / 0` is
  NaNs still; a `c64`'s is C's, `(inf+nan.i)` (#571)
- a `CBR` by a real `CBR`, or by an imaginary one, is part by part, as
  by a `BigRat`: `CBR(inf, 0) / CBR(2)`, of a BigRat's infinity, is
  `((1n/0n)+(0n/1n).i)`, where its imaginary part was 0 times an
  infinity, a NaN; what is finite is as it was (#572)
- and times a real `CBR`, or an imaginary one, it is the other scaled,
  part by part: `CBR(1) * CBR(inf, 0)` is `((1n/0n)+(0n/1n).i)`, a
  part that is 0 staying 0 times an infinity; 0 times an infinity is
  NaNs (#573)
- an infinity of a rational divided by a negative number is the other
  infinity, with `<Rational>`: `BigRat(1, 0) / BigRat(-2)` is
  `(-1n/0n)`, where it was `(1n/0n)`, and `rat64(1, 0) / -2` is
  `(-1/0)`; so a `CBR`'s part, `CBR(inf, 0) / -2` (#574)
- a function may be named by its types as a member of a type is:
  `meters(x:f64)` beside the attribute `meters.f64`, which kelvinc
  refused, both being `meters__f64` in C; the function is
  `_kv_fn_meters__f64` there (#575)
- `BigFloat`, with `#import <BigNum>`, is a floating-point number of
  any precision, a `BigInt` times a power of 2: every result, of
  `+ - * /` and of
  `BigFloat(x)`, is rounded to `BigFloat.precision` significant bits,
  128, which a program may set, so `BigFloat(1) / 3` is a third to
  128 bits; `x.round(precision)` and `x.round(precision, rule)` round
  it to fewer, by `BigFloat.nearestEven`, `.nearestAway`, `.up`,
  `.down`, `.towardZero` or `.awayFromZero`; it has a float's
  infinities and NaN; `x.f64` is the nearest `f64` and `BigRat(x)`
  its value exactly (#576)
- print of a `BigFloat` writes the fewest digits that read back:
  `BigFloat("0.1")` is `0.1` and `BigFloat(1) / 3`
  `0.333333333333333333333333333333333333334`, laid out as an
  `f64`'s; `x.dec` has a sign and `x.hex` is C's `%a`,
  `+0x1.8p0`, exact; `BigFloat(text)` reads a decimal, a fraction,
  a hex float, `inf` and `nan`, and text that is none is a NaN (#577)
- the else arm of `c ? a : b` may begin with a type's attribute:
  `c ? -f64.infinity : f64.infinity` and `c ? x : i64.max`, which
  kelvinc and kc refused, the `:` and the type's word read as an
  annotation of the first arm (#578)
- an overlay may use another's: two that stand at one place, right
  after the module both are of, are in the order found, where the
  second was put before the first and saw none of what it imports
  (#579)
- with `<BigNum>` math's functions take a `BigFloat`:
  `sqrt(BigFloat(2))` is `1.41421356237309504880168872420969807857`;
  `sqrt`, `exp`, `log`, `pow`, the trigonometric and hyperbolic
  functions and their inverses, each a method too, and
  `BigFloat.pi()`; a result has `BigFloat.precision` significant
  bits whatever its size, `exp(BigFloat(-1000))` is
  `5.0759588975494567652918094795743369193e-435`, or the precision
  written, `exp(x, 256)` (#580)
- with `<BigNum>` there is `CBF`, `complexBigFloat` by
  its alias, a complex number of two BigFloats: `CBF(1, 2) / CBF(3, 4)`
  is `(0.44+0.08.i)`; each part of `+ - * /` is the exact one's,
  rounded once to `BigFloat.precision` bits, so nothing is lost where
  products all but cancel; `conj`, `norm`, `z.i`, `z.round(precision)`;
  its text is a `c64`'s, `(0.1-0.2.i)`, which `CBF(text)` reads back,
  with `.dec` and `.hex`; `CBF(z)` of a `c64` and of a `CBR`, and
  `CBR(z)` and `c64(z)` back (#581)
- math's functions take a `CBF`: `abs` and `arg`, `sqrt`, `exp`, `log`,
  `pow`, the trigonometric and hyperbolic functions and their
  inverses, each a method too; each part of a result has
  `BigFloat.precision` significant bits whatever its size and however
  far below the other it is, or the precision written, `exp(z, 256)`;
  a part that is 0 is exactly 0, `pow(CBF(-4), BigFloat("0.5"))` is
  `(0.0+2.0.i)`; a part past `2^67108864` in size or below
  `2^-67108864` gives NaNs (#582)
- math's functions of a `BigFloat` take a number far from 1:
  `cos(BigFloat("0x1p-1000000000000"))` is 1, where it was killed for
  want of memory, a rational as long as the exponent is large being
  made of it; near 0 a function is its first term, far out its limit,
  `atan` half of pi and `asinh` `ln(2x)`, and `atan2` is of the
  quotient; a sine, a cosine and a tangent of a number of `2^67108864`
  and more are NaNs (#583)
- The text of a `BigFloat` far from 1 is had as soon as any other's:
  `BigFloat("0x1p-1000000000000")` prints
  `1.044250726930468202952436781310171121576e-301029995664`, and
  `BigFloat("1e1000000000")` reads one, where each made a rational as
  long as the exponent is large, minutes of a million places and no
  end of more; the fewest digits still, which read back, and the
  nearest number, up to the largest exponent there is; a decimal past
  that is an infinity or 0 (#584)
- `exp`, the sines, the cosines and the tangents of a `CBF` take a
  part of any size: `exp(CBF(1, tiny))`, `tiny` being
  `2^-1000000000000`, is `e + e tiny i`, where it was NaNs, a part
  below `2^-67108864` or of `2^67108864` and more being past
  reckoning (#582); they are made of a BigFloat's functions, which
  take any number (#583); far out `e^x` is an infinity or 0, and an
  angle of `2^67108864` and more gives NaNs, but where its other
  factor is 0; `log`, `pow`, `arg` and the inverses are as they were
  (#585)
- `log`, `arg` and `pow` of a `CBF` take a part of any size too:
  `log(CBF(1, tiny))` is `tiny^2 / 2 + tiny i`, and
  `pow(CBF(tiny, 1), CBF(3))` `-3 tiny - i`; the norm's exponent may
  be past an `i64`'s; `pow` keeps the angle of `z` as quarter turns
  and what is left of them, so that each part's bits are good beside
  an axis, and a part is 0 exactly on a diagonal too,
  `pow(CBF(1, 1), CBF(131072))` is `2^65536`, where it did not end; a
  `w` far out makes an infinity or 0, or NaNs where the angle is past
  reckoning, and an infinite power has its signs of an angle of
  `2^64` and more, which were wrong; the inverses are as they were
  (#586)
- `abs` and `sqrt` of a `CBF` take a part of any exponent:
  `abs(CBF(top, top))`, `top` being `2^9000000000000000000`, is the
  root of 2 times `top`, where it was an infinity, and
  `sqrt(CBF(top, 1))` was wrong by the root of 2; the norm's exponent
  is twice a part's, past an `i64`'s there, and is held no more (#587)
- `exp` of a BigFloat is had up to the greatest exponent there is:
  `exp(BigFloat("0x1p+62"))` is a number of `2^6653256548922161245`,
  where it was an infinity, an `x` of `2^62` and more having been
  taken for past any exponent; it is the result that is tried now, an
  infinity past `6393154322601327917` at 128 bits and 0 below
  `-6393154322601327741`; `pow`, `sinh` and `cosh` have their numbers
  with it (#588)
- A part of a `CBF`'s `exp` is tried against the exponents as the
  product it is: with `tiny` of `2^-4000000000000000000`,
  `exp(CBF(7000000000000000000, tiny))` has an imaginary part of
  `2^6098865286222743851`, where it was an infinity, `e^x` having been
  made a BigFloat before it was multiplied; beside the least number a
  part is 0 where `e^x` is, and was 16 places sooner; `sinh`, `cosh`,
  `sin`, `cos`, `tanh`, `tan` and `pow` are so too (#589)
- `#import <BigNum>` is the one library of the numbers of any size:
  `BigFloat`, `CBR` and `CBF`, and math's functions of a `BigRat`, a
  `CBR`, a `BigFloat` and a `CBF`; it was `#import <BigFloat>` and two
  overlays, read where `<math>` was imported beside `<Rational>` or
  `<BigFloat>`; `<Rational>` is as it was, `rat64` and down and
  `BigRat` with its arithmetic, and `#import <BigFloat>` is an error
  that says what to write (#590)
- math is the prelude's: `sin(0.5)`, `2.0.sqrt()`, `f64.tau` and
  `c64(1.0, 2.0)` need no import, as in JavaScript and Perl; a program
  that names one of math's names has it, as it has `RegExp` and
  `BigInt`, and one that names none compiles as before; libkelvin
  holds it, so two objects that both use it link; `#import <math>` is
  accepted and does nothing; `abs(-3)` is Kelvin's, an `i64`, where it
  was C's, an `int` (#591)
- A call of an overloaded function has the result of the overload it
  calls where kelvinc asks whether a call has a value: one with no
  result is no value of a body and no argument, as a program's own
  `log(x:i64)` beside math's `log`, and one with a result is a value a
  body drops; both were left to C (#593)
- A type attribute may be computed, `static let T.x:R { ... }`, read
  as `T.x` with no parentheses and made at each read, where
  `static let T.x = v` is one stored value: so an owner may be one,
  each read a new one; in `extend T { }` it is `static let x:R { ... }`,
  and a module's header writes it `static let x:R { get }` (#595)
- Every number of the family has `F.zero`, `F.infinity` and `F.nan`:
  `f64` and `f32`, where `.zero` is new; `rat64` down to `rat8`,
  `(0/1)`, `(1/0)` and `(0/0)`; and `BigRat` and `BigFloat`, each a new
  one at each read (#596)
- `x.sign` of a floating-point number is -1 or 1, an `i64`, by its
  sign bit, a zero's and a NaN's too, where it was a `bool?`; it is
  set with -1 or 1, `x.sign *= -1`; a rational and a `BigFloat` have
  it, -1 where negative and 1 of all else (#597)
- A floating-point number is `sign * significand * 2 ** exponent`,
  three integers, the significand odd, as a `BigFloat` is its mantissa
  times a power of 2: `1.0.exponent` is 0 and `1.5` is 3 times `2^-1`,
  where `.exponent` and `.significand` were IEEE 754's raw fields,
  `1.0`'s exponent 1023; `f64(sign, exponent, significand)` makes the
  number of the three, the nearest, and `f32`, `BigFloat`, `BigRat`
  and `rat64` are made so too, a `BigFloat`'s and a `BigRat`'s
  significand a `BigInt` or an integer (#598)
- `<Rational>` and `<BigNum>` are libraries, `M.kh` and `libkM`, built
  once by `make` as `<JSON>` is, where each was a source compiled with
  every program that imported it: a program with `<BigNum>` builds in
  a quarter of a second, where it took four; a module's library is
  linked before those its header imports, whatever the order of a
  program's imports (#599)
- `Kelvin.name` is the prelude's `name`, whatever the program calls
  its own, as `Swift.print` is Swift's: `Kelvin.log(x)` beside a `log`
  of the program's, `Kelvin.sqrt(x)` under a variable named `sqrt`,
  and `Kelvin.BigInt` beside a `struct BigInt`. A function of the
  program's with the name and the types of one of the prelude's is
  another function, where it took its place or did not link, and a
  type with the name of one of its types no longer keeps the prelude's
  out; `Kelvin` is no name of a program's own (#600)
- A module of the prelude that an import writes, `#import <math>`, is
  read where the prelude's is, before all else, and not where the
  import stands: a module's header that names `c64`, imported before
  `<BigNum>`, whose header writes that import, came before math, and
  C did not know its type (#601)
- `x.hex` of a floating-point number writes an exponent of 0 with no
  sign, `+0x1p0`, where it was C's `p+0`; any other has its sign, as
  before, `+0x1.8p+1` and `-0x1.8p-2`. So of an `f64`, an `f32`, a
  `BigFloat` and the parts of a complex number, and of the number
  SION writes (#603)
- A name of the program's own top level that is no function hides the
  prelude's of that name, and `Kelvin.name` is the prelude's: a
  variable named as one of its functions, `let exp = 2.5`, which C
  refused, and anything named as a word of its enum, `let nfc = 5`,
  which every program has had since #520; a member of such a name is
  a member still (#604)
- An owner that is moved out is dead on the path that moved it, where
  it was dead for all that followed in the block: `if c { return s }`
  leaves `s` for what follows, and the two branches of an `if` and the
  cases of a `switch` may each move it, as only one of them runs;
  after them it is dead where any that goes on moved it (#605)
- An operator of the prelude's own types is the prelude's alone:
  `let +(a:c64, b:c64):c64` in a program is kelvinc's error, where it
  was the linker's, a duplicate symbol, as an operator has no
  `Kelvin.` to say which is meant; an operator of other types stands
  beside the prelude's (#606)
- `x.hex` of an `f64` and an `f32` is Kelvin's own text, the same on
  every system, where it was the C library's `%a`: a subnormal is
  written by its first 1, `5e-324.hex` is `+0x1p-1074`, as a
  `BigFloat`'s is, where glibc's `%a` writes
  `0x0.0000000000001p-1022` (#607)
- `#import <Combinatorics>` is permutations, combinations, power sets,
  base-n numbers and Cartesian products, as js-combinatorics and
  swift-combinatorics have them: each a Sequence of `$[i64]`s, indices
  a program picks its elements by, counted by a `BigInt`, indexed by an
  `i64` or a `BigInt`, `Permutation(36)[Permutation(36).count - 1]`,
  with `sample()`; and `factorial`, `permutation`, `combination`,
  `factoradic` and `combinadic` (#614)
- A subscript's index may be lent, `let [](i:lent BigInt):R`, as a
  function's parameter is (#510): its caller keeps it, where
  `lent` was read and the owner moved in all the same (#614)
- `<Combinatorics>` has swift-combinatorics' `UniquePermutation`, the
  arrangements of a multiset of `i64`s each distinct one once,
  `UniquePermutation(&$[1, 1, 2])` three, and `Permutations` and
  `Combinations` of several sizes, `Combinations(4, 2...3)`; and
  `pick(&seed, ix)`, the elements of a program's own seed at the
  indices a kind gives, of an Array of one of eight types or of a
  String's graphemes, `pick(&$"kelvin", Permutation(6)[719])` is
  `"nivlek"` (#615)
- The `$` of `$[...]` and `${...}` reaches every literal inside it:
  text becomes a String, as `$"..."` makes one, so `$["a", "b"]` is an
  `Array<String>` where it was an `Array<cstr>`, `$[["a"], ["b"]]` an
  `Array<Array<String>>`, and `${"k": "v"}` a
  `Dictionary<String, String>`; a `{k: v}` inside is a Dictionary. A
  written type wins, `var cs:$[cstr] = $["x"]`, and what is no literal
  keeps its type. And `$""` is the type String, wherever a type goes:
  `$[$""]` is `Array<String>` (#616)
- `xs.gather(ix)` is a new Array of the elements of any Array at the
  indices of a `$[i64]`, in their order, each copied, and `s.gather(ix)`
  a String's graphemes at them: `$["a", "b", "c"].gather($[2, 0])` is
  `["c", "a"]`. It replaces `<Combinatorics>`' `pick(&seed, ix)`, so
  `$"kelvin".gather(Permutation(6)[719])` is `"nivlek"` (#617)
- The indices of `.gather` may be an `[i64](N)` too, a variable's,
  a member's or written in place, `xs.gather([2, 0])`; an empty one
  gives none, and a negative index is named as itself in the message,
  `index -1 is out of range` (#618)
- Calling a variable of no function type is kelvinc's error, where it
  was C's: `let sqrt = 2.0; sqrt(sqrt)` says `'sqrt'` is a variable
  here, which hides the function of its name (#620)
- `self` in a function with no receiver, or in a global's value, is
  kelvinc's error, where it was C's (#621)
- An enum's word is of its enum to `.typename`: `red.typename` is
  `color`, where it was `i32`, and `nfc.typename` `NormalForm`; `.size`
  and the integer's methods stay C's int's (#622)
- A BigFloat's range is of its leading bit: one of `2^(2^63)` and more
  is an infinity at any precision, and the bits below the least number
  are rounded off; exp's limits are `2^63` ln 2 either way,
  `6393154322601327829` (#623)
- Every path of a function with a result returns a value: one whose
  body can reach its end is kelvinc's error, where it was C's warning;
  a call of `exit`, or of a function of the program that never returns,
  ends a path (#625)
- A struct, a union, an enum, a typealias and a global may be used
  before they are written, as a function may, and two structs may
  point at each other in either order (#626)
- A wrong count of arguments, a value returned of another type, `^` of
  what is no pointer and a comma in an Array's subscript are kelvinc's
  errors, where they were C's (#627)
- A name declared twice in one block is kelvinc's error, where it was
  C's; a block inside, and each case of a switch, may declare it again
  (#628)
- A number prefers an overload whose parameter is of its own kind:
  `twice(n)` of an `i32` calls `twice(n:i64)` over `twice(x:f64)`,
  where it was an error; the open questions Q5, Q10 and Q12 are closed
  (#632)
- `register` is an error that says it is left out on purpose, and
  `_Noreturn` needs no word, as kelvinc marks a function that never
  returns itself (#640)
- `thread_local var x` is each thread's own, C's `_Thread_local`, at the
  top level and, static, in a block (#641)
- `atomic` is C's `_Atomic`, a qualifier as `const` is, of a number, a
  bool or a pointer: `var hits:atomic i64 = 0` (#642)
- `#if os(macOS)`, `#elseif`, `#else` and `#endif` choose code by the
  platform, as Swift's do (#643)
- Design.md's principle and c-interfaces.md say `#if os(...)` is one
  of Kelvin's directives (#644)
- The error of a C directive names `#if os(...)` among Kelvin's own
  (#645)
- Two definitions of one name at the top level, of any kinds, are
  kelvinc's error, where they were C's (#646)
- A value past a struct's last member or an array's count is kelvinc's
  error, where C only warned (#647)
- A fixed array set whole, `a = b`, is kelvinc's error, where it was
  C's (#648)
- `break` and `continue` outside a loop are kelvinc's errors, where
  they were C's (#649)
- A struct that holds itself by value is kelvinc's error, where kelvinc
  ended with a segmentation fault (#659)
- A constant index outside a fixed array is kelvinc's error, where C
  only warned (#661)
- An integer divided by a constant 0 is kelvinc's error, where C only
  warned (#662)
- A literal that does not fit its integer type, or a float's fraction
  where an integer goes, is kelvinc's error (#663)
- A shift by a constant count past its type's width is kelvinc's error,
  where C only warned (#665)
- `#import <Prime>` is primality of every integer type and of
  `BigInt`, as swift-bignum has it: `97.isPrime`, `100.nextPrime`,
  `100.prevPrime`, a `T?`, `n.isSurelyPrime` and `u8.primes`, an
  Iterator of a type's primes; and a computed attribute of a type may
  be of an integer type, `static let i64.answer:i64 { 42 }` (#668)
- A member a value's type does not have is kelvinc's error of
  arithmetic too, named by C's type of it: `(n + 1).foo` of a `u8` is
  `i32 has no member 'foo'`, where it was C's error (#669)
- A `_` among a numeric literal's digits is left out, as Swift and Perl
  have it: `0x7fff_ffff`, `1_000_000`, `1_000.000_1`, `1_000n`; after a
  digit or another `_`, and text read at run time is as before (#671)
- `<Prime>` has `BigInt.generatePrime(bits)`, a random prime of exactly
  that many bits, as OpenSSL's libcrypto makes one: top two bits set,
  sieved, Baillie-PSW and 64 or 128 rounds of random bases (#672)
- An integer literal past u64's greatest is kelvinc's error, which says
  how its BigInt is written, `99999999999999999999n`, where it was C's;
  and `let x = 18446744073709551615`, an `i64`, does not fit, where it
  was -1 (#678)
- kc writes a top-level let of a pointer as kelvinc does, a const
  pointer, `int64_t *const q`, where it wrote `const int64_t * q`, which
  C refused `q^ = 5` of, and `const const uint8_t *` of a cstr (#680)
- `(size_t)(n + 1)`, `(int32_t)*p` and `(size_t)-1` are kelvinc's error,
  C casts are not Kelvin, where C said expected expression (#689)
- kc prints a struct's pointer, function, IO and plain enum members as
  kelvinc does, by their text, where it said not yet, and a block's
  enum's case by its path, `pair.kind.sides(4)` (#692)
- kc shows a fixed array in a template, `${a}`, and by `.pretty` as
  kelvinc does, and a let parameter's to its declared count, where it
  said not yet; `for` over an array of empty structs walks its count,
  and an empty struct prints `{}` (#693)
- kc reads a top-level enum with no name and values, its cases words
  of the program, and the methods of a type with no tag, as kelvinc
  does (#120, #121); a var method of an enum with values, and `.m` at a
  line's start going on with the expression before it where there is
  no self (#694)
- kc reads overloads of a variadic function, `f__T__va`, and chooses
  overloads as kelvinc does where it did not: a call C chooses for is of
  its overloads' one result, text and `any^` fit pointers, an array an
  array parameter, an overloaded name a function parameter (#695)
- kc reads `x.type` and `typeof` of what kelvinc does not see, C's
  `__typeof__`, an inferred global's, an expression's and a C name's,
  and compound literals of them, as kelvinc does (#696)
- kc reads a function defined inside a function, `_kv_outer_name` in
  C, its block's, as kelvinc does (#180, #697)
- kc walks a pointer up to a 0, and what only C sees so, as kelvinc
  does, and takes nowhere among a `[cstr]`'s elements (#698)
- kc reads `[T?](n)`, a fixed array of Optionals, and prints a fixed
  array of a count C computes, as kelvinc does (#699)
- kc gives a global C cannot initialize its value at its first use, as
  kelvinc does (#493), and so makes a value's text in a global's
  initializer (#700)
- kc reads `T^ atomic`, an atomic pointer, as kelvinc does (#701)
- An enum, a struct or a union with no name in a block or inside a type
  is kc's error in kelvinc's words, where it said not yet (#702)
- kc reads a parameter's array of arrays whose inner count C computes,
  as kelvinc does (#703)
- kc takes none and a value among a fixed array of Optionals' elements,
  as kelvinc does (#704)
- A Dictionary's key and a Set's element are an integer or a String,
  and a fixed array is no Array's element, in kelvinc's words where the
  type is written, where kc built `Set<f64>` (#705)
- kc prints a choice of bools as a bool, where it printed 1 (#706)
- kc writes a record's `.cstr` and its text in a template as kelvinc
  does, an Array member `[...]`, to its own longest (#707)
- kc keeps a let's const in `typeof(k)`, as kelvinc does (#708)
- kc reads `x as T ? a : b` as a choice, where it read `T?`, and holds a
  String an expression gives that a search borrows (#710)
- kc reads `Optional<T>()` and `Optional<T>(v)`, and moves an owner into
  a `T?` parameter as some of it, as kelvinc does (#711)
- kc makes an Optional's and a Result's `.map`, `.flatMap` and
  `.mapErr` as kelvinc does (#712)
- kc makes a Bytes's Base64, `b.toBase64()` and `Bytes.fromBase64(s)`,
  its slice and `b + c`, as kelvinc does (#713)
- kc takes an empty last case, a let pointer parameter's element set,
  `IO.strerror`, and `(T){...}` of an enum with values, as kelvinc does
  (#714)
- kc reads an operator at a line's end, labels and goto, element
  designators, a comma in a condition, a method's prototype and several
  globals in one declaration, as kelvinc does (#715)
- kc appends an Array's elements, what a borrow points to and text as
  a String to an Array, and reads its capacity, as kelvinc does (#716)
- kc reads text in a `[u8]`, `[[T]]` of rows and `:=` of an array, and
  infers C's `size_t` of sizes and counts, as kelvinc does (#717)
- kc reads `v.pretty(n)`, `cstr restrict`, `$(...)` in a function of a
  type and an anonymous function's `:()`, as kelvinc does (#718)
- kc reads anonymous functions in a list, in a top-level struct's count
  and calling themselves, and a `?:` across lines, as kelvinc does
  (#719)
- kc reads `((i64):i64)^`, arrays of functions, a file imported again
  by another path and a header next to an imported file, as kelvinc
  does (#720)
- kc reads `.pretty` of an enum with values, `async` of a function
  value and a number's text in a brace-less for body, as kelvinc does
  (#721)
- kc takes and gives owners through function values, as kelvinc does
  (#722)
- kc writes a let's local array with C's `const` and says a list where
  no array is declared in kelvinc's words (#724)
- An Optional's braces with nothing in them, `var x:i64? = {}` and
  `(i64?){}`, are `none`, as a `T?` declared with no value is, where
  they were `some(0)`; kc reads `(T?){...}` (#725)
- kc reads `q[i]` of a pointer as kelvinc does: of a `[T](N)^` the
  array `i` rows on, and of a `T^` a `T`, where it was a `u8` (#726)
- kc passes `#inline C { ... }` through to the C it writes, at the top
  level and among statements, as kelvinc does (#727)
- kc reads a `{`, `as`, `[` and a product's `*` at the start of a
  line, `return`'s value on the next line and `q++` in a `for`'s
  clause, as kelvinc does (#728)
- kc reads `volatile`, a variadic function's type `(T, ...):R`,
  compound literals of a C header's types and `nowhere`'s properties,
  as kelvinc does; an array's compound literal goes where a pointer
  goes again, which #724 had refused (#729)
- kc builds every program of tests/run and examples, each printing
  what kelvinc's prints: `IO.popen`, a module's `extern lazy` global
  and the rest of the last eight (#730)
- A compound literal where a macro's argument goes,
  `println(([i32](3))[1, 2, 3][1])`, is written in parentheses, where it
  was C's error (#732)
- An element of a `[const T](N)`, behind a pointer too, and `p[i] = v`
  through a `const T^` are errors in Kelvin's words, where they were
  C's (#733)
- A global used before it is written takes the types it names with
  it where it is moved up, a struct written after `main` among them
  (#734)
- kc says five more errors in kelvinc's words: an array where a value
  goes, braces assigned to a member, `ok({1, 2})`, a fixed array's
  method and a row where a number goes (#736)
- kc reads zeros where a pointer goes, `var p:i64^ := [i64](3)`, and
  `[T](n)^`, a pointer to an array of a count C computes, as kelvinc
  does (#737)
- A variable inferred from a value read through const, `var d = s[0]`
  of a `cstr`, is the plain type, which changes, where it was const
  and C refused the change; kc names such reads as kelvinc (#738)
- A call through a function value of the wrong count, `f(1)` of an
  `f:(i64, i64):i64`, is an error in Kelvin's words, where it was C's
  (#740)
- A struct's member takes a value of its kind: `{1, "two"}` is `'y' of
  point is an i64, and this is text`, and a number where an array
  member goes is an error, where they were C's (#741)
- `T^ const` and `cstr const`, a pointer that is itself const, does not
  change: `p := &y` is `'p' is an i64^ const, a pointer that does not
  change: declare it without const to point it elsewhere`, where it
  was C's error (#742)
- `ok({})` and `err({})` are `a list is not a value here`, as
  `ok({1, 2})` is, where the case was said to hold a T, and this is ()
  (#743)
- kc says `while (i == 0) (i) += 1` in kelvinc's words and builds a
  function type's parameter of rows counted by another parameter,
  `f:([[i64](n)](2)):i64` (#744)
- A literal's element read through const is of the plain type:
  `$[p^]` of a `const i64^` is an `Array<i64>`, where C warned or
  refused, and a volatile's too (#746)
- `.typename` names a count C computes as written: `[i32](n)` of a
  `var a:[i32](n)`, and a function's that takes such an array, where
  it was `?` (#747)
- A value where a function type goes is a function of that type:
  `num({ (x:f64):i64 in 1 })` is `this is (f64):i64, where (i64):i64
  goes`, and text there is an error, where C took it (#748)
- kc says a cstr variable where a String goes in kelvinc's words,
  `'t' is a String, and this is cstr`, and declares a Set by `:=`
  (#749)
- An element of a fixed array and a value of a Dictionary's literal
  are of the kind written: `[1, "a"]` of a `[i64](2)` is `an element
  of [i64](2) is an i64, and this is text`, where it was C's (#752)
- A variable is of the type of a function whose rows count by a
  parameter, `let h := apply`, where C found no `n` in its type
  (#753)
- kc reads a function whose parameter is a fixed array as kelvinc:
  its type is `([i64](3)):i64`, and `take3(three)` is built, where
  kc refused it (#754)
- An Array, a Dictionary and a Set are values: `:=` of one is `'d'
  is a value (Array<i64>): assign it with '=', not ':='`, where
  `a := b` built and freed one twice (#755)
- kc reads a `w:v.type` of an array of a count C computes as the
  array, an array of a constant count with no value,
  `[i64](sizeof(i64))`, and a struct's braces that begin with an
  Array, `{$[1], 2}` (#756)
- kc says a Set's key, an Array's appended element, an Optional's
  element and a designated element's value in kelvinc's sentences,
  and an error of a member read at its `.` (#757)
- An Array, a Dictionary and a Set of structs are named by the
  structs' bare names, `Array<point>`, where `.typename` said
  `Array<struct point>` (#758)
- A number is no pointer: `var p:i64^ := 5` is `'p' is an i64^, and
  this is a number`, where it was C's error; `0` is C's null still
  (#760)
- A variable declared with no value is zero: `var x:i64`, `var
  p:point` and `var a:[i64](3)`, where kelvinc left them unset, as C
  (#761)
- `var v:[i64]`, an array of no count and no value, is `[i64] takes
  its count from its elements`, where it was C's error (#762)
- An Array, a Dictionary and a Set have `+=` alone: `s -= x` is `a Set
  has no '-=': remove an element with s.remove(x)`, where it was C's
  error (#763)
- A function's name where functions are an Array's elements is the
  overload of their type, `xs += twice`, and an anonymous function
  takes it, `xs += { $0 + 1 }`; `nowhere` where a number goes is `'n'
  is an i64, and this is any^`, where it was C's error (#764)
- A String and a Bytes have `+=` alone: `t -= "a"` is `a String has
  no '-='`, where it was C's error (#766)
- An array is not declared with another: `var a:[i64](2) = b` is `an
  array is not assigned: assign its elements, a[i]`, where it was C's
  error (#767)
- `Set<i64>([1, 2])` says what a Set takes, `the elements in {a, b,
  c}`, where it said to write a compound literal (#768)
- `Array<i64>("a")` is `Array<i64>(n) takes a count, and this is
  text`, where it was C's error; `Array<i64>(c)` of a cstr and
  `Array<i64>(&x)` of a number are errors, where they were built
  (#771)
- A struct where an array is declared is `'a' is a [i64](2), and this
  is pt`, the array as written, where it said `an i64^` (#772)
- Zeros and a compound literal where an array goes are of its shape:
  `var a:[i64](2) = [i64](3)` is `'a' is a [i64](2), and this is
  [i64](3)`, where it was taken; a member and a row take them, where
  they were C's errors (#773)
- `println(g)` of a `[[i64](n)](2)`, rows of a count C computes, is
  an error that names the rows, `print its rows, println(g[i])`,
  where it was C's error (#776)
- `var v:[i64](n) = [1, 2, 3]` of a count that is no constant, a
  let's name too, is `an array of a count computed at run time takes
  no elements in C`, where it was C's error or leaned on a C
  compiler's extension (#779)
- `var v:[i64](3.0)` is `an array's count is an integer, and this is
  f64`, where it was C's error (#783)
