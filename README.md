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

sum(n: struct node^): i32
{
    total: i32 = 0;
    for (; n; n := n^.next)     // C: n->next
        total += n^.value;
    return total;
}
```

So far the changes from C are:
- every declaration is `name: type`, functions included, with no keyword;
  `i = 42` declares `i` (an `i64`) when `i` is not declared yet
- pointers are a postfix `^` (`i32^`, `p^`, `p^.m`), and are assigned
  with `:=` (`buffer := malloc(n):i64^`), while `=` assigns values
- XOR is `~`
- there is no `void`: `any^` is C's `void *` and `nullptr` its null, and a
  reference declared without a value is `nullptr`
- numeric types always say their size (`u8`…`u64`, `i8`…`i64`,
  `i128`/`u128`, `f32`, `f64`), so `char`, `int`, `long`, `float` and
  `double` are gone, and `i = 42` is an `i64`
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
  `bool`, so `println(a == b)` prints `true`

Everything else is C. See [versusC.md](versusC.md) for all the differences,
[Design.md](Design.md) for the design decisions, and
[Dialogue.md](Dialogue.md) for how they were made.

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
