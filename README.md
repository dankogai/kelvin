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
    value: i32;
    next: struct node^;
};

sum(var n: struct node^): i32       // n may move; parameters are lets otherwise
{
    var total: i32 = 0;
    while n != nullptr {
        total += n^.value;              // C: n->value
        n := n^.next;
    }
    return total;
}
```

So far the changes from C are:
- variables are declared with `let`, which never changes (C's `const`), or
  `var`: `let k = 42;`, `var n: i32 = 0;`; the type follows the name, and
  functions are `add(a: i64, b: i64): i64`, whose parameters are lets
  unless written `var`
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
- every type can have methods, such as `point.area(): f64 { ... }`
- every number, bool, pointer and Kelvin struct has its text as `x.cstr`
  (derived for structs, as `{x: 3, y: 4}`), where `cstr` is `u8^`;
  `toString()` waits for a true string type
- properties: `x.size` is `sizeof(x)`; integers have `.dec`, `.hex`,
  `.oct` and `.bin` text, and `f32`/`f64` have `.dec` and `.hex`
  (`(42:i32).hex` is `+0x2a`)
- conditions are `bool`, with no parentheses and block bodies:
  `if n > 0 { ... }`, `while p != nullptr { ... }`; comparisons give a
  `bool`, so `println(a == b)` prints `true`, and `let ok = a < b;`
  declares one
- assignment is a statement, and there is no `++` or `--`: write
  `i += 1;`, and step a pointer with `p := p.next;`
- counting loops use ranges: `for i in 0..<n { ... }` and
  `for i in 1...n { ... }`, where `i` is a `let`

Everything else is C. See [versusC.md](versusC.md) for all the differences,
[Design.md](Design.md) for the design decisions, and
[Dialogue.md](Dialogue.md) for how they were made.

## Examples

Each one ends with the output it prints, which `make test` checks.

| File | Shows |
|------|-------|
| [examples/hello.k](examples/hello.k) | the smallest program |
| [examples/fizzbuzz.k](examples/fizzbuzz.k) | ranges, `bool` conditions, `else if` |
| [examples/primes.k](examples/primes.k) | a `bool` array, nested ranges, `continue` |
| [examples/strings.k](examples/strings.k) | `cstr`, stepping with `.next`/`.prev`, C's string functions, `.hex` and friends |
| [examples/shapes.k](examples/shapes.k) | structs, methods, derived `.cstr` text, `<math.h>` |
| [examples/linkedlist.k](examples/linkedlist.k) | references (`^`, `:=`), `malloc`/`free`, changing a list through a pointer |

## Build and use

Requires a C11 compiler and make.

```sh
make                        # builds ./kelvinc and libkelvin.{a,so|dylib}
make test                   # runs tests/run.sh
make install PREFIX=~/.local # bin/kelvinc, lib/libkelvin.*, include/
./kelvinc hello.k           # builds ./hello
./kelvinc --run hello.k     # builds and runs
./kelvinc --emit-c hello.k  # prints the generated C
```

## License

MIT
