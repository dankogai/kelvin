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
  topic each: [strings.md](documents/strings.md),
  [bytes.md](documents/bytes.md), [arrays.md](documents/arrays.md),
  [functions.md](documents/functions.md), ...
- [documents/versusC.md](documents/versusC.md) has all the differences
  from C at a glance.
  - Each document says whether what it covers is the core, the
    prelude, or loaded with an `#import`; versusC.md sums that up.
- [CHANGELOG.md](CHANGELOG.md) has the release notes, 0.1.0 the first
  (#467), 0.1.1 with `fetch()` (#496), 0.2.0 the latest, with `RegExp`
  and `BigInt` in the prelude (#514).
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
| [examples/strings.k](examples/strings.k) | `cstr`, `for c in s`, a `u8^` cursor with `p++`, C's string functions, `.hex` and friends |
| [examples/shapes.k](examples/shapes.k) | structs, `extend` blocks of methods and attributes, derived `.cstr` text, `<math.h>` |
| [examples/linkedlist.k](examples/linkedlist.k) | references (`^`, `:=`), `malloc`/`free`, an `extend list` block whose var methods change the list they are called on, `l.push(v)`, and whose methods read it, `for n in head` |
| [examples/sort.k](examples/sort.k) | `$[T]`'s `sort` and `sorted`, by `<`, by an anonymous function with `$0` and `$1` or by a named one; `map`, `filter`, `reduce`, `prefix` and `reversed` chained; an Array of structs; C's `qsort` with a written comparator |
| [examples/sequences.k](examples/sequences.k) | iterators, structs with a `var` method `next()`: `for`, `map` and `reduce` of one that ends, `prefix` of one that never does; `(2...).lazy.filter(prime)`, a Range with no end, filtered lazily |
| [examples/wordfreq.k](examples/wordfreq.k) | word frequencies: the prelude's `RegExp` and `.split`, a `Set<String>` of words to leave out, a `Dictionary<String, i64>` counting the rest, an Array of structs that own their words, sorted by count |
| [examples/calc.k](examples/calc.k) | a calculator: an enum with values for tokens, `switch` binding a case's value, the shunting-yard algorithm with Arrays as stacks, each step a `Result` and `try` passing an `err` up, `if let` |
| [examples/results.k](examples/results.k) | `Result<T, U>` and `T?` wrapping C's `timespec_get`, `fopen` and `getenv`, a `String` error from text, an `err` passed up by hand, `if let`, `??`, `switch` |
| [examples/tasks.k](examples/tasks.k) | `async f(x)` and `await`: four `Task<i64>`s in an Array count primes at once, and a `Task<String>` moves its owner out to the caller |
| [examples/bfi.k](examples/bfi.k) | a brainfuck interpreter: a struct that owns a `Bytes` and an `Array`, `Result` and `if let err(why)`, a `switch` on bytes, `argv`, `fopen` and `getchar`; `!` ends the program and starts its input |
| [examples/bfc.k](examples/bfc.k) | a brainfuck compiler to Kelvin source, which kelvinc then compiles: slices, `for c in bytes`, `printf` for escapes, `argv` |
| [examples/complex.k](examples/complex.k) | `#import <math>`, overloaded functions beside C's, operators: roots of a quadratic and of unity, a Fourier transform |
| [examples/ski.k](examples/ski.k) | SKI combinator logic, and Iota and Jot compiled to it: terms as nodes of an `Array` of structs by index, a global owner, recursive descent through an `i64^` cursor, reduction to a normal form, `String` built with `+=` (#201) |
| [examples/lambda.k](examples/lambda.k) | the untyped lambda calculus, written with `λ`: Church numerals and Wikipedia's definitions, `FACT 3` by `Y`, de Bruijn indices that never capture, names primed with `′` where they would; a `String` read by codepoint, functions over a `reader^` that call each other through a prototype (#202) |
| [examples/quine.k](examples/quine.k) | a quine: a String holding the program with a mark where the String goes, printed with itself written as a literal at the mark, its quotes, backslashes and newlines escaped; `for c in s`, `.utf32` (#465) |
| [examples/quine_cheat.k](examples/quine_cheat.k) | a cheating quine, Perl's `open 0; print while <0>`: `for line in IO(__FILE__).lines`, C's `__FILE__` being the source's path through kelvinc's `#line`, the IO held for the loop (#465, #466) |

## Build and use

Requires:

- a C11 compiler, as `cc`, clang or gcc;
- GNU make, which reads `GNUmakefile`;
- Python 3, which makes the Unicode tables of the runtime from
  `tools/ucd/` (#156);
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
  - a `[uchr](N)` stops at `uchr(0)`, and `for n:u32 in s` gives each
    codepoint's number (#480)

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
  with `j.is(n)` and `switch j { case n: ... }`
- there is no `void`: `any^` is C's `void *` and `nowhere` its null, and a
  reference declared without a value is `nowhere`
- numeric types always say their size (`u8`…`u64`, `i8`…`i64`,
  `i128`/`u128`, `f32`, `f64`, or by their full names `uint8`, `int64`,
  `float64`), so `char`, `int`, `long`, `float` and `double` are gone,
  and `let i = 42` is an `i64`
- `bool`, `true` and `false` are built in; `!!n` is the `bool` of an
  integer 0 or 1, and `Bits`, bits each a `bool` by its place, as many
  as it holds (#455), takes the place of C's bit-fields (#387)
  - an integer's bit is `x.bit(n)`, set with `x.bit(n) = b`, and
    `x.flip(n)` flips it; `b.flip()` is `b = !b` (#454)
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
  `#import <math>` declares it, so that `sin(0.5)` is C's
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
  `static var count:i64 = 0` read as `T.count`, operators
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
  - `toString()` waits for a true string type
- `print` and `println` show any value whole: `println(xs, " ", ages)`
  prints `[1, 2] {"ann": 31}`, with Strings inside quoted, and
  `println(cfg.pretty)` the same indented, a line for each item
  - a `uchr` inside a value is `uchr("é")`, so that it pastes back
    (#479)
  - `uchr(s)` is the first codepoint of a String or a Bytes, as of
    text; of a float, a bool or a pointer to no text it is an error,
    where C failed or read the bytes (#494)
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
    codepoint, each a `uchr`, which prints as its character;
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
  characters, `s.upper()`, `s.fold()`, `uchr("é").name` and
  `.category` (#156)
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
  BigInt literals, as JS's (#508); `b ** e`, Python's `pow(b, e, m)`,
  `a.gcd(b)`, `a.lcm(b)`, `a.isqrt()` (#511); `i64(b)` and `f64(b)`
  are `b.i64` and `b.f64`, as a converter of a struct is its attribute
  (#512)
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
- `#import <math>` is `math.h` and its complex counterpart: its
  functions for `f64` and `f32`, each a method too, `x.sin()`, its
  constants as attributes of the type, `f64.pi`, and `c64` and
  `c32` with their arithmetic and elementary functions, `x.i` a
  quarter turn; a Kelvin file's source, from `./modules` or Kelvin's
  own `modules/`
