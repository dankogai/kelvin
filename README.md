# kelvin

Yet another attempt to improve C.

C is also the symbol for Celsius, and Kelvin is its natural successor: the
step size is identical, so everything you know about C carries over one to
one, but it sits on an absolute scale where nothing goes below zero. Kelvin
keeps C's data model, ABI and performance profile while removing the
undefined-behavior basement. Every operation that C leaves undefined either
fails to compile or traps with a source location.

```kelvin
extern fn printf(fmt: *u8, ...) -> i32;

struct Point { x: i32, y: i32 }

fn main() -> i32 {
    var xs = [5, 3, 8, 1];
    for i in 0..xs.len {
        printf("%d ", xs[i]);      // bounds-checked
    }
    let p = Point { x: 3, y: 4 };
    printf("\n%d\n", p.x * p.x + p.y * p.y);  // overflow-checked
    return 0;
}
```

Source files use the `.k` extension.

## Status

This is an early bootstrap compiler, `kelvinc`, written in C11. It translates
Kelvin to C and hands the result to the system C compiler, so interop with
existing C libraries is direct: declare the function with `extern fn` and
call it.

See [docs/design.md](docs/design.md) for the language as it exists today,
the safety guarantees, the known holes and the roadmap.

## Build and use

Requires a C11 compiler (clang or gcc) and make.

```sh
make            # builds ./kelvinc
make test       # runs tests/run.sh
```

```sh
./kelvinc hello.k            # builds ./hello
./kelvinc --run hello.k      # builds into a temp dir and runs it
./kelvinc --emit-c hello.k   # prints the generated C
```

`kelvinc --help` lists all options.

## License

MIT
