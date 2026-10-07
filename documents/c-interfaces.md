# C interfaces

Kelvin is C: every function, struct and pointer is C's, with C's ABI, so
a Kelvin program calls C and C calls it with nothing in between. This
document has the ways in and out: C headers, typedef names, C's own
functions beside Kelvin's, the prelude from C, and what the C compiler
checks.

## Headers and the preprocessor

- `#import <header.h> as C` includes a C header, and everything it declares
  can be used: functions, typedef names, macros like `stdout`, `NULL` or
  `EOF`, and enums.
- `#import "mylib.h" as C` is looked up next to the `.k` file first.
- C looks for headers and libraries in `./modules` and Kelvin's
  `modules/` too (`-I` and `-L`), so `#import <mylib.h> as C` may be
  there, and `KELVIN_CFLAGS=-lmylib` links its `libmylib.a` (#46).
  `KELVIN_CFLAGS` go after the program, as a library must on Linux.
- `as C` is required for a C header. A Kelvin file is imported without
  it (see [modules.md](modules.md)).
- Every other directive (`#include`, `#define`, `#if`, ...) is an error.
  The rest of the preprocessor is TODO.
- Without an import you can still declare C functions by hand:
  `let printf(fmt:const u8^, ...):i32`. Don't do both, because a
  hand-written prototype conflicts with the header's.

A header macro that expands to nothing or to an operator can change how C
reads the code around it. Kelvin cannot see macro definitions and treats
every macro as an ordinary name. `_Pragma("...")` is allowed only as a
statement of its own.

## The ABI

- Kelvin writes C: `i64` is `int64_t`, `u8^` is `uint8_t *`, a struct is
  `struct point`, a function is a C function of its name. A program's
  one function of a name keeps that name; a function with overloads, or
  one imported from a Kelvin file, is named by its parameter types
  (`twice__i64`), as [functions.md](functions.md) says.
- `let main(argc:i32, argv:[cstr]):i32` is C's `main`, and `argv` is
  written `char **`.
- `u8` and C's `char` mix freely; see [cstrings.md](cstrings.md).
- A Kelvin function may overload a C function of the same name, which
  still takes the numbers: `let sqrt(v:vec):f64` beside C's `sqrt`
  ([functions.md](functions.md)).
- C's `_Complex` types are `f32 _Complex` and `f64 _Complex`; Kelvin's
  own complex numbers are structs ([modules.md](modules.md)).

### C typedef names

After a colon, any identifier is accepted as a type, so typedefs from
imported headers work: `let f:FILE^ := stdout` and
`let n:size_t = strlen(s)`. The same holds after `as`: `n as size_t`,
`p as FILE^`.

Where only C sees a type, the C compiler decides what kelvinc could not:
which overload a call takes, whether a condition is a `bool`, which
property a value has. Its errors then name `kv_no_such_overload`,
`kv_condition_is_not_bool` or `kv_no_such_property` at your line.

## `libkelvin` from C

The prelude lives in `libkelvin`, which kelvinc links statically
*(provisional P22)*. The same library works from C:
`#include <kelvin_prelude.h>` and link `-lkelvin`, both in Kelvin's
`modules/` (#46).

```c
#include <kelvin_prelude.h>
int main(void) { println("n = ", 42); return 0; }   /* cc -I... -L... -lkelvin */
```

## The C compiler

The C compiler checks Kelvin programs, and `#line` directives make its
errors and warnings point at your `.k` file and line. Kelvin's own syntax
errors also carry hints for C habits, such as `*p`, `p->m`, `int x;`,
`long`, `10UL` or `(int)x`.

kelvinc runs `$CC` (`cc` by default) with `-std=c11`, `-I` of the `.k`
file's directory and of the `modules/` directories, `-ffp-contract=off`
(so clang and gcc round `a * b + c` alike), and `libkelvin.a`;
`KELVIN_CFLAGS` adds flags, and `kelvinc -v` prints the command.
`kelvinc --emit-c` writes the C instead of compiling it.

For the C features Kelvin cannot spell yet, see
[versusC.md](versusC.md).
