# kelvin

[![CI](https://github.com/dankogai/kelvin/actions/workflows/ci.yml/badge.svg)](https://github.com/dankogai/kelvin/actions/workflows/ci.yml)

Yet another attempt to improve C: a quiet alternative that starts from bare
C and changes it bit by bit, while staying 100% ABI compatible.

C is also the symbol for Celsius, and Kelvin is its natural successor. The
step size is identical, so everything you know about C carries over one to
one.

```kelvin
#import <stdio.h> as C

struct node {
    value: int32
    next:  node^
}

let sum(var n:node^):int32 {      // n may move; parameters are lets otherwise
    var total:int32 = 0
    while n != nullptr {
        total += n^.value       // C: n->value
        n := n^.next
    }
    return total
}
```

So far the changes from C are:
- structs, unions and enums are types by their bare name: `var p:point`
  for `struct point`; a struct or a union with no tag is written by its
  members where a type goes, `var v:{x:f64, y:f64} = {3.0, 4.0}`,
  `var u:union{i:i32, f:f32}`
- an `enum` whose cases carry values is a union that knows its case,
  with a byte for the tag: `enum json { null; n: f64; s: String; a:
  Array<json> }`, made as `json.n(1.5)`, read as `j.n` (checked), tested
  with `j.is(n)` and `switch j { case n: ... }`
- `switch` is Swift's: a case ends at the next, `case 1, 2:` shares a
  body, and every value is handled, by every case or by `default:`
- variables are declared with `let`, which never changes (C's `const`), or
  `var`: `let k = 42`, `var n:i32 = 0`; the type follows the name, and
  functions are lets too, `let add(a:i64, b:i64):i64`, whose parameters
  are lets unless written `var`
- pointers are a postfix `^` (`i32^`, `p^`, `p^.m`), and are assigned
  with `:=` (`buffer := malloc(n):i64^`), while `=` assigns values
- XOR is `~`
- there is no `void`: `any^` is C's `void *` and `nullptr` its null, and a
  reference declared without a value is `nullptr`
- numeric types always say their size (`u8`…`u64`, `i8`…`i64`,
  `i128`/`u128`, `f32`, `f64`, or by their full names `uint8`, `int64`,
  `float64`), so `char`, `int`, `long`, `float` and `double` are gone,
  and `let i = 42` is an `i64`
- `bool`, `true` and `false` are built in
- C headers are imported with `#import <stdio.h> as C`
- there are no C casts: convert with `i32(x)`, `malloc(n) as u8^` or
  `0xdead:u16`
- `print()` and `println()` come from a small prelude in `libkelvin`, so
  `println("n = ", n)` works for any type with no import
- every type can have methods, such as `let point.area():f64 { ... }`
- `Bytes` and `String` are owned text on the heap, with
  `b.toBase64(url, nopad)` and `Bytes.fromBase64(text)` built in
- every number, bool, pointer and Kelvin struct has its text as `x.cstr`
  - a struct's is derived, as `{x: 3, y: 4}`, or defined as one template,
    `let point.cstr():cstr { `(${.x}, ${.y})` }`, where `.x` is `self.x`
  - `cstr` is immutable text, C's `const uint8_t *`, with `s.count` for
    its length
  - `toString()` waits for a true string type
- properties
  - `x.size` is `sizeof(x)`
  - integers have `.dec`, `.hex`, `.oct` and `.bin` text, and `f32`/`f64`
    have `.dec` and `.hex` (`(42:i32).hex` is `+0x2a`)
  - pointers and functions have `.addr`, the address as a `uintptr_t`,
    `.hex`, as in `0x000000016ee86888`, and `.isNull`
  - `x.type` is `x`'s type where a type goes, as in `var y:x.type`, and
    `x.typename` its name, as in `"i64"`
- conditions are `bool`, with no parentheses and block bodies:
  `if n > 0 { ... }`, `while p != nullptr { ... }`; comparisons give a
  `bool`, so `println(a == b)` prints `true`, and `let ok = a < b`
  declares one
- assignment is a statement, and `++` and `--` step only a pointer, as
  statements: `p++`; a number takes `i += 1`
- counting loops use ranges: `for i in 0..<n { ... }` and
  `for i in 1...n { ... }`, where `i` is a `let`
- `for c in s { ... }` walks a string up to its NUL, and
  `for n in head { ... }` a list along `next`
- a `;` may be left out at the end of a line, and a function whose body is
  one expression returns it: `let square(x:i64):i64 { x * x }`
- function types are `(T, U):R`, as in `before:(i64, i64):bool`
- anonymous functions enclose nothing, are inline (C's `static inline`),
  and may follow a call as its last argument: `sort(xs, n) { $0 < $1 }`,
  where `$0` and `$1` are the parameters
- `print` and `println` show any value whole: `println(xs, " ", ages)`
  prints `[1, 2] {"ann": 31}`, with Strings inside quoted, and
  `println(cfg.pretty)` the same indented, a line for each item
- quoting text
  - template literals: `` `Hello, ${name}!` `` may span lines, and
    `${x}` is `x`'s text as `print` shows it, kept on the stack (a string
    value is cut at 256 bytes)
  - `"""` on its own lines quotes text as written, with no escapes
  - `$"..."` and `` $`...` `` make a `String`
- converters read numbers from text, as C's `strtol` and `strtod` do:
  `i64("42")`, `i32("755", 8)`, or as a property, `"42".i64`
- functions overload by their parameter types, also C's own: with
  `let sin(z:c64):c64` defined, `sin(z)` is Kelvin's and
  `sin(0.5)` C's
- a function with no result is `let f() { }`, or `let f():() { }` with
  the result written out; the two mean the same
- `extend T { }`, as Swift's `extension`, holds a type's methods
  `let f()`, functions `static let f()`, computed attributes
  `let area:f64 { .w * .h }` read as `r.area`, attributes with a setter
  `var celsius:f64 { get { ... } set(v) { ... } }`, type attributes
  `static var count:i64 = 0` read as `T.count`, operators
  `static let +(a:Self, b:Self):Self`, and subscripts `let [](i:i64):R`;
  in every member `.w` is `self.w` and `Self` is `T`; each also written
  alone, `let T.area:f64 { ... }`
- structs and unions may define operators:
  `let +(a:money, b:money):money { ... }`, then `a + b`
- owners on the heap, each freed when its block ends, moved by `return`
  and by passing, copied only by `.copy()`, borrowed as a pointer
  - `Bytes` is a growable array of bytes: `b += "more"`, `b[i]` checked
  - `String` is a `Bytes` of well-formed UTF-8, counted and walked by
    codepoint, each a `uchr`, which prints as its character;
    `` $`a${x}b` `` builds one from a template, with no bound
  - `Array<T>` is a growable array of any value type, owners included
  - `$"text"` and `$[1, 2, 3]` are a `String` and an `Array` for short,
    and `$[i64]` the type `Array<i64>`
  - `Dictionary<K, V>` is a hash map, `${"ann": 31}`, keyed by integers
    or Strings: `d[k]` checked, `d.has(k)`, `d.find(k)`, `for k, v in d`,
    `d.keys` and `d.values`
  - `Set<T>` is a hash set, `${3, 1, 4}`: `s += x`, `s.has(x)`, `s | t`,
    `s & t` and `s ~ t`
- `IO` is a file as an owner, closed when its block ends, a module:
  `#import <IO>`
  - `let f = IO(path, "r")`, with `f.error` when it did not open
  - `for line in f.lines { }`, `for chunk in f.read(4096) { }`,
    `let s = f.string`
  - `f.write("x")`, `IO.stderr.println("n = ", n)`
- `#import <JSON>` is JSON as an enum with values: `var j = JSON.parse(text)`,
  `j.object["k"].array[0].number`, `JSON.stringify(&j, "  ")` (#113)
- `#import <SION>` is SION, JSON with more, data, dates, exts and any
  value as a key: `SION.parse(text)`, `s["key"]`, `SION.stringify(&s, 2)`;
  `#import <MsgPack>` packs one into MessagePack, `MsgPack.pack(&s)`,
  and back, `MsgPack.unpack(&b)`
- `#import <UnicodeData>` is the Unicode Character Database:
  `s.normalize(nfc)`, `s.graphemes`, the clusters a reader sees as
  characters, `s.upper()`, `s.fold()`, `uchr("é").name` and
  `.category` (#156)
- `#import <RegExp>` is regular expressions, JS's over Strings, with the
  `$/pattern/flags` literal: `re.test(&s)`, `s.match(&re)`,
  `s.replace(&re, "$1")`, `s.split(&re)`, `\p{Script=Greek}` and `\X`
  for a grapheme cluster (#157)
- `OS` and `SYS` are the system and the program, as Python has them, one
  module, `#import <OS>`: `OS.cwd`, `OS.env("HOME")`, `OS.listdir(dir)`,
  `OS.isdir(p)`, `OS.system(cmd)`, `SYS.argv`, `SYS.platform`, `SYS.exit(1)`
- a module is a Kelvin source, `#import <JSON>`, or a header and a
  library, `M.kh` and `libkM` in `modules/`, which `#import <M>` brings
  in and links by itself, as `IO` and `OS` are; `kelvinc --lib M.k`
  builds a Kelvin file into one
- `Result<T, U>` is a value with an outcome, `ok(v)` or `err(e)`
  - `r.ok` checked, `r ?? 0`, `r.is(err)`, `if let v = r { } else { r.err }`
  - `switch r { case ok: ... case err: ... }`, `if let err(e) = r { }`,
    `r.map(f)`
  - `let v = try f()` passes the `err` up
  - `T?` is its special case, a value that may be absent, `none` or
    `some(v)`: `var x:i64? = none`, `x = 3`, `x.some`, `x ?? 0`
- `#import <math>` is `math.h` and its complex counterpart: its
  functions for `f64` and `f32`, each a method too, `x.sin()`, its
  constants as attributes of the type, `f64.pi`, and `c64` and
  `c32` with their arithmetic and elementary functions, `x.i` a
  quarter turn; a Kelvin file's source, from `./modules` or Kelvin's
  own `modules/`

Everything else is C. Each document says whether what it covers is the
core, the prelude, or loaded with an `#import`; versusC.md sums that up.
See [documents/versusC.md](documents/versusC.md) for
all the differences at a glance, and the documents beside it, one topic
each ([strings.md](documents/strings.md), [bytes.md](documents/bytes.md), [arrays.md](documents/arrays.md),
[functions.md](documents/functions.md), ...),
[Design.md](Design.md) for the design decisions,
[Dialogue.md](Dialogue.md) for how they were made, and
[Style.md](Style.md) for how Kelvin code is written.

## Examples

Each one ends with the output it prints, as `// out:` lines, which
`make test` checks.

| File | Shows |
|------|-------|
| [examples/hello.k](examples/hello.k) | the smallest program |
| [examples/fizzbuzz.k](examples/fizzbuzz.k) | ranges, `bool` conditions, `else if` |
| [examples/primes.k](examples/primes.k) | a `bool` array, nested ranges, `continue` |
| [examples/strings.k](examples/strings.k) | `cstr`, `for c in s`, a `u8^` cursor with `p++`, C's string functions, `.hex` and friends |
| [examples/shapes.k](examples/shapes.k) | structs, `extend` blocks of methods and attributes, derived `.cstr` text, `<math.h>` |
| [examples/linkedlist.k](examples/linkedlist.k) | references (`^`, `:=`), `malloc`/`free`, an `extend list` block whose functions of the type change a list through a pointer, `list.push(&l, v)`, and whose methods read it, `for n in head` |
| [examples/sort.k](examples/sort.k) | function types, anonymous functions with `$0` and `$[k]`, C's `qsort` with a written comparator |
| [examples/results.k](examples/results.k) | `Result<T, U>` and `T?` wrapping C's `timespec_get`, `fopen` and `getenv`, a `String` error from text, an `err` passed up by hand, `if let`, `??`, `switch` |
| [examples/bfi.k](examples/bfi.k) | a brainfuck interpreter: a struct that owns a `Bytes` and an `Array`, `Result` and `if let err(why)`, a `switch` on bytes, `argv`, `fopen` and `getchar`; `!` ends the program and starts its input |
| [examples/bfc.k](examples/bfc.k) | a brainfuck compiler to Kelvin source, which kelvinc then compiles: slices, `for c in bytes`, `printf` for escapes, `argv` |
| [examples/complex.k](examples/complex.k) | `#import <math>`, overloaded functions beside C's, operators: roots of a quadratic and of unity, a Fourier transform |

## Build and use

Requires a C11 compiler and make.

```sh
make                        # builds ./kelvinc, modules/libkelvin.{a,so|dylib}, libkIO and libkOS
make test                   # runs tests/run.sh
make install PREFIX=~/.local # bin/kelvinc and lib/kelvin/modules/
./kelvinc hello.k           # builds ./hello
./kelvinc --run hello.k     # builds and runs
./kelvinc --emit-c hello.k  # prints the generated C
./kelvinc --lib geo.k       # builds the module geo: modules/geo.kh, libkgeo.a and libkgeo.dylib|.so
```

## License

MIT
