# Self-hosting Kelvin: a proof of concept

**Can Kelvin compile itself?** For a subset, yes. `kc` is a compiler
written in Kelvin alone. It reads the subset it is written in, writes C
as kelvinc does, and hands that C to `cc`. Built in stages, as gcc
bootstraps itself, it reaches a fixpoint (#204).

- **Kelvin, and the platform's C:** a self-hosted Kelvin may depend on
  libc, or libSystem on macOS, as C does: Kelvin embraces C rather than
  refusing it.
  - What would be cheating is C of its own: `#inline C`, or C headers
    and libraries written for it.
  - kc uses less still: the prelude (`String`, `Array`, `println`) and
    `<IO>` to read the source, write the C and run `cc`.
- **No CI yet:** `selfhost/bootstrap.sh` is run by hand.

## Files

| File | What it is |
|---|---|
| [kc.k](kc.k) | the driver: options, reading files and their imports, writing the C, running `cc` |
| [lex.k](lex.k) | the tokens |
| [parse.k](parse.k) | the tree and the types |
| [gen.k](gen.k) | the C |
| [sample.k](sample.k) | a program of the subset, built by both compilers, which must print the same |
| [bootstrap.sh](bootstrap.sh) | the stages and their checks |

## The stages

```sh
selfhost/bootstrap.sh
```

| Stage | Built by | From |
|---|---|---|
| stage1 | kelvinc | `selfhost/kc.k` |
| stage2 | stage1 | `selfhost/kc.k` |
| stage3 | stage2 | `selfhost/kc.k` |

- **The fixpoint:** stage2 and stage3 are both kc built by kc, so the C
  each writes of kc is the same, byte for byte (`build/selfhost/stage2.c`
  and `stage3.c`).
- **The sample:** stage3 builds `sample.k`, whose output must be what
  kelvinc's build of it prints.
- Checked by hand as well:
  - kc built with gcc 15 (`-cc gcc-mp-15`), and stage1 built by kelvinc
    with gcc 15, write the same C;
  - kc's C, built with ASan and UBSan, compiles kc cleanly to the same C.
- Everything goes into `build/selfhost/`; nothing is removed.

## Using kc

```sh
build/selfhost/stage3 program.k -o program [-c program.c] [-m modules] [-cc compiler]
```

- `-c` keeps the C there; without `-o`, kc writes the C alone.
- `-m` names the directory of `kelvin_prelude.h` and the libraries:
  `modules`, from the top of the repository, when none is given.
- `-cc` names the C compiler, `cc` when none is given.

## The subset

kc reads what it is written in, and little more.

- **Declarations:** `let f(x:T, ...):R { }`, a prototype without a body,
  `struct` of plain members, global `let` and `var`, `#import <IO>` and
  `#import "x.k"`.
- **Types:** `int64`, `int32`, `uint8`, `uint32`, `bool`, `cstr`,
  `String`, `IO`, `uchr`, a struct, `$[T]`, `T^`, and main's `[cstr]`.
- **Statements:** `var` and `let` with a type, always; `=`, `+=` and the
  rest; `if`, `else if`, `else`; `while`; `for i in a..<b`; `for x in s`
  of a String or an Array; `return`, `break`, `continue`.
- **Expressions:** numbers, characters, `"..."` and `$"..."`, `true`,
  `false`, calls, `.member`, `.method()`, `a[i]`, `&x`, `p^`, `x as T`,
  `{a, b}` of a struct, `$[]`, and `! - * / % + - < <= > >= == != && ||`.
- **Of the prelude and IO:** `.count`, `.copy()`, `.cstr`, `.pop()`,
  `.uchr`, `.utf32`, `String(text)`, `println`, `IO(path, mode)`,
  `.string`, `.write(&s)`, `.close()`, `.error`, `.status`,
  `IO.exec(args, mode)`.
- **Ownership:** a `String`, an `Array` or an `IO` is freed by C's
  `cleanup` attribute; `return x` of a local one moves it out.
- **Each statement is one line,** but inside `( )` and `[ ]`.

## Difficulties in the way of self-hosting kelvinc

What kc met, and what a Kelvin kelvinc would meet, so that the next
steps can take them on one at a time.

### The size of the language

- **kelvinc is 17,000 lines of C** (parser.c alone 11,800), and kc's
  1,900 lines of Kelvin read a few percent of what kelvinc reads.
- **Left out of the subset:**
  - type inference;
  - overloading, and the names it mangles (`twice__i64`);
  - enums with values, `switch`, `Optional`, `Result`, `??`, `try`;
  - `extend`, methods, attributes, subscripts, operators;
  - anonymous and nested functions;
  - templates;
  - `Dictionary` and `Set`;
  - the moves and temporaries of ownership (O5, O11, O12);
  - `$/.../` and its check, `#inline C`, `--lib` and `.kh`;
  - `#line`;
  - and kelvinc's hundreds of messages.
- **There is no specification but kelvinc:** grammar.md is partial, and
  the 815 tests of tests/run.sh are the nearest thing. A Kelvin kelvinc
  would take passing them as its acceptance.

### A bug found on the way

- **C's order of evaluation leaks into Kelvin.** kelvinc writes
  `nodes[n].a = parse_expr()` as `(*_kv_array_node_at(&nodes, n)).a =
  parse_expr();`.
  - When `parse_expr` grows `nodes`, gcc has already taken the old
    element's address and writes into freed memory; clang happens not
    to.
  - kc's stage1 built by kelvinc with gcc lost three functions of kc.k
    this way.
  - kc's source sets children through `set_a(n, parse_expr())`, and kc's
    own C computes such a value before the place.
  - kelvinc still has the bug.

### libc, and C of our own

libc is allowed, as it is to any C program; C of our own is not.

- **libc takes these off the list:** kc wrote them around, and need not.
  - The environment: `getenv` reads `KELVIN_HOME`, `CC` and `TMPDIR`,
    where kc takes `-m` and `-cc`.
  - A temporary directory: `mkdtemp`, where kc writes the C beside the
    program.
  - Ending: `exit`, where kc returns from main.
  - Running cc: `posix_spawn` or `system`, beside `<IO>`'s `IO.exec`.
- **What kc needs for them:** it reads `#import <x.h> as C` and passes
  the names it does not know to C, unchecked, as kelvinc does: a small
  addition to the subset.
- **What libc does not give:**
  - **The `$/.../` check:** kelvinc links runtime/regexp_parse.c, C of
    our own, to check a pattern while compiling. A Kelvin kelvinc needs
    that parser in Kelvin, or the `RegExp` module, whose engine is C of
    our own too.
  - **The runtime:** libkelvin, `<IO>` and `<OS>` are C of our own. A
    compiler of Kelvin uses them as any Kelvin program does; writing
    them in Kelvin is a self-hosting of its own, beyond the compiler's.
  - **No `.o` of its own:** kc writes C and needs `cc`, which is no C
    of ours. Writing objects would take a backend, an assembler and a
    linker of Kelvin's own.

### Writing a compiler in Kelvin

- **Methods cannot change `self`:**
  - the parser's state is in globals;
  - the readers of examples/lambda.k are functions of a `reader^`.
- **No recursive types:** the tree is an Array of nodes linked by
  index, as in examples/ski.k.
- **Declared before use:** mutual recursion needs prototypes first, as
  `let parse_expr():int64` and `let gen_expr(n:int64)`.
- **Inference stops at arithmetic:** `var j = n - 1` is an error, so
  every variable says its type.
- **Characters:**
  - a character literal is C's `int`, and a `uchr` is a struct;
  - a String cannot be indexed, `s[i]` being an error;
  - so the source is held as `$[uint32]`, four bytes a character.
- **No switch on text:** a keyword is found by a chain of `tok_is`.
- **No constants:** `let T_ID:int64 = 2` is a global, not a C constant,
  so it cannot label a `case`.
- **Text:**
  - `+=` appends text, a `uchr` or `&s`;
  - a number is written by kc's own `put_int`, since `.cstr` and
    templates live in buffers of their block;
  - `String(n)` would do, beyond the subset.
- **Errors:**
  - kc sets a global `failed` and moves the parser's cursor to the end,
    so that every loop stops;
  - `Result` would carry them, at the price of every parser.
- **Lines:**
  - a statement ends with its line, so a long condition is one long line;
  - `as` is a keyword, so nothing is named `as`.
- **Speed:** a name is found by walking every declaration and every
  local, and a keyword by comparing codepoints. That is quadratic, fine
  for kc's 1,900 lines; kelvinc would want `Dictionary`.

### The runtime is part of the language

- **The C must fit kelvin_prelude.h:**
  - kc writes `KV_ARRAY(...)`, `KV_STRING_APPEND`, `kv_io_*` and the
    `_kv_array_i64` names as kelvinc does;
  - GNU C's statement expressions and `cleanup` attribute;
  - all of it read from kelvinc's output, with nothing to say what is
    fixed.
- **Modules:** a module built by kelvinc names its functions by their
  types. To link one, kc would have to mangle as kelvinc does; `<IO>`
  works because its functions are C's.

## Next steps

Each of these is one change of its own:

1. Fix kelvinc's order of evaluation, `a[i].f = g()`.
2. Let kc read `#import <x.h> as C`, and use libc: `getenv` for
   `KELVIN_HOME`, `CC` and `TMPDIR`, `mkdtemp`, `exit`.
3. Write down the C a program becomes: the prelude's macros, the names
   kelvinc makes, the mangling. A second compiler then has a contract.
4. Grow kc's subset, keeping the fixpoint, and rewrite kc in each new
   part as it comes:
   - `switch` on enums;
   - `Dictionary` for names;
   - `String(n)`;
   - methods of `extend`;
   - inference of literals;
   - `Optional` and `Result`.
5. Run kc on the tests of tests/run.sh that fit the subset, to count how
   far it reads.
6. Then CI: `selfhost/bootstrap.sh` as a job.
