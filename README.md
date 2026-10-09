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
    value: i32
    next:  node^
}

let sum(var n:node^):i32 {      // n may move; parameters are lets otherwise
    var total:i32 = 0
    while n != nullptr {
        total += n^.value       // C: n->value
        n := n^.next
    }
    return total
}
```

So far the changes from C are:
- structs, unions and enums are types by their bare name: `var p:point`
  for `struct point`
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
  `i128`/`u128`, `f32`, `f64`), so `char`, `int`, `long`, `float` and
  `double` are gone, and `let i = 42` is an `i64`
- `bool`, `true` and `false` are built in
- C headers are imported with `#import <stdio.h> as C`
- there are no C casts: convert with `i32(x)`, `malloc(n) as u8^` or
  `0xdead:u16`
- `print()` and `println()` come from a small prelude in `libkelvin`, so
  `println("n = ", n)` works for any type with no import
- every type can have methods, such as `let point.area():f64 { ... }`
- every number, bool, pointer and Kelvin struct has its text as `x.cstr`
  (derived for structs, as `{x: 3, y: 4}`, or defined as one template,
  `let point.cstr():cstr { `(${self.x}, ${self.y})` }`), where `cstr` is immutable
  text, C's `const uint8_t *`, with `s.count` for its length;
  `toString()` waits for a true string type
- properties: `x.size` is `sizeof(x)`; integers have `.dec`, `.hex`,
  `.oct` and `.bin` text, and `f32`/`f64` have `.dec` and `.hex`
  (`(42:i32).hex` is `+0x2a`); pointers and functions have `.addr`, the
  address as a `uintptr_t`, `.hex`, as in `0x000000016ee86888`, and
  `.isNull`;
  `x.type` is `x`'s type where a type goes, as in `var y:x.type`, and
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
- template literals: `` `Hello, ${name}!` `` may span lines, and
  `${x}` is `x`'s text as `print` shows it, kept on the stack (a string
  value is cut at 256 bytes)
- converters read numbers from text, as C's `strtol` and `strtod` do:
  `i64("42")`, `i32("755", 8)`, or as a property, `"42".i64`
- functions overload by their parameter types, also C's own: with
  `let sin(z:complex64):complex64` defined, `sin(z)` is Kelvin's and
  `sin(0.5)` C's
- structs and unions may define operators:
  `let +(a:money, b:money):money { ... }`, then `a + b`
- `Bytes` is a growable array of bytes on the heap that its variable
  owns: freed when the block ends, moved by `return` and by passing,
  copied only by `.copy()`, borrowed as `Bytes^`; `b += "more"`,
  `b[i]` checked; `String` is a `Bytes` of well-formed UTF-8, counted
  and walked by codepoint, each a `uchr`, which prints as its character;
  `Array<T>` is a growable array of any value type, owners included
- `#import <complex.k>` brings in a Kelvin file's source, here
  `complex64` and `complex32` with their arithmetic and elementary
  functions, from `./modules` or Kelvin's own `modules/`

Everything else is C. See [documents/versusC.md](documents/versusC.md) for
all the differences at a glance, and the documents beside it, one topic
each ([cstrings.md](documents/cstrings.md), [arrays.md](documents/arrays.md),
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
| [examples/shapes.k](examples/shapes.k) | structs, methods, derived `.cstr` text, `<math.h>` |
| [examples/linkedlist.k](examples/linkedlist.k) | references (`^`, `:=`), `malloc`/`free`, changing a list through a pointer, `for n in head` |
| [examples/sort.k](examples/sort.k) | function types, anonymous functions with `$0` and `$[k]`, C's `qsort` with a written comparator |
| [examples/complex.k](examples/complex.k) | `#import <complex.k>`, overloaded functions beside C's, operators: roots of a quadratic and of unity, a Fourier transform |

## Build and use

Requires a C11 compiler and make.

```sh
make                        # builds ./kelvinc and modules/libkelvin.{a,so|dylib}
make test                   # runs tests/run.sh
make install PREFIX=~/.local # bin/kelvinc and lib/kelvin/modules/
./kelvinc hello.k           # builds ./hello
./kelvinc --run hello.k     # builds and runs
./kelvinc --emit-c hello.k  # prints the generated C
```

## License

MIT
