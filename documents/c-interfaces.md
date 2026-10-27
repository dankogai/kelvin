# C interfaces

Kelvin is C: every function, struct and pointer is C's, with C's ABI, so
a Kelvin program calls C and C calls it with nothing in between. This
document has the ways in and out: C headers, C of your own in
`#inline C`, typedef names, C's own functions beside Kelvin's, the
prelude from C, and what the C compiler checks.

**Where it lives:** explicitly loaded. A C header's names come only with `#import <x.h> as C`; `libkelvin` and `kelvin_prelude.h` are the prelude, which Kelvin links without an import and which C may use too.

## Headers and the preprocessor

- `#import <header.h> as C` includes a C header, and everything it declares
  can be used: functions, typedef names, macros like `stdout`, `NULL` or
  `EOF`, and enums.
- `#import "mylib.h" as C` is looked up next to the `.k` file first.
- C looks for headers and libraries in `./modules` and Kelvin's
  `modules/` too (`-I` and `-L`), so `#import <mylib.h> as C` may be
  there.
  - `KELVIN_CFLAGS=-lmylib` links its `libmylib.a` (#46).
  - `KELVIN_CFLAGS` go after the program, as a library must on Linux.
- `as C` is required for a C header. A Kelvin file is imported without
  it (see [modules.md](modules.md)).
- Every other directive (`#include`, `#define`, `#if`, ...) is an error.
  - Kelvin leaves C's preprocessor out on purpose, inside
    `#inline C { ... }` too (#296): see [Inline C](#inline-c).
- Without an import you can still declare C functions by hand:
  `let printf(fmt:const u8^, ...):i32`.
  - Don't do both, because a hand-written prototype conflicts with the
    header's.

A header macro that expands to nothing or to an operator can change how C
reads the code around it. Kelvin cannot see macro definitions and treats
every macro as an ordinary name.

`_Pragma("...")` is allowed only as a statement of its own.

## Inline C

`#inline C { ... }` is C of the program's own (#197), written into the
generated C where it stands: at the top level, or in a function as its
statements (#198).

```swift
#import <ctype.h> as C
let twice(x:int64):int64 { x * 2 }

#inline C {
enum { LOUD = '!' };
static int shout(int c) { return toupper(c); }
int64_t quad(int64_t x) { return twice(x) * 2; }   /* C calls Kelvin */
}

let main():int32 {
    println(quad(3), " ", shout(97), " ", LOUD)    // 12 65 33
    return 0
}
```

- **Where:** at the top level of a file, or among a function's
  statements (#198), with `{` on the line of `#inline C`.
  - Not in a struct, a union or an enum, and not as the body of a
    statement without braces.
  - It ends at the `}` that matches that `{`, counted as C counts them:
    a brace in a string, a character or a comment does not count.
  - Nothing but a comment may follow the closing `}` on its line.
- **What it may hold:** C at file scope: functions, globals, types and
  their constants.
  - Assembly too, GNU C's `__asm__ __volatile__(...)`, which Kelvin
    leaves to C (#399): `#inline C { __asm__ __volatile__("nop"); }`
    among a function's statements.
  - No line of C's preprocessor (#296): a `#` that begins a line,
    `#include`, `#define`, `#if`, is an error.
    - A header is `#import <x.h> as C` before the block; a constant is
      an enum's, `enum { LOUD = '!' };`, or a Kelvin `let`.
    - A macro a program needs is written in a header and imported.
  - No Kelvin directive nests in it: `#import` and `#inline` stand at
    the top level, or among a function's statements.
  - A `#` in a string, a character or a comment is as written.
- **No trigraphs** (#220), as in the rest of Kelvin:
  - in its strings, characters and comments, `??!` is as written:
    kelvinc writes a `?` after a `?` as `\?`;
  - a `??` in its code is an error, since it could only be a trigraph;
  - so is a `??` in the name of a header imported as C, which has no
    escapes.
- **Kelvin's side:** its names are used as an imported header's are.
  - kelvinc does not read C, so a call is not checked by kelvinc; the C
    compiler checks it.
  - Its typedef names are types after a colon, as
    [C typedef names](#c-typedef-names) says: `let p:cpoint = corigin()`.
  - A Kelvin function calls it once it is written above the call, as a C
    function must be declared before its use.
- **C's side:** it calls a Kelvin function written above it, by its C
  name, as [The ABI](#the-abi) says: `twice`, or `twice__i64` where it
  is overloaded or imported.
  - It may use the prelude's types, as `kv_string`, since the generated
    C includes `kelvin_prelude.h` first.
- **Errors:** the C compiler's errors name the `.k` file and its line.
- **Ownership:** Kelvin's rules (see [ownership.md](ownership.md)) end
  at the block; what C does there is C's.
- **Modules:** a module built by `kelvinc --lib` (#146) has the block in
  its library, and its declarations in its `.kh`, in an `#inline C` of
  their own (#199), so a program that imports the module uses its names:
  - its preprocessor lines, as they are;
  - a function's prototype, its body dropped;
  - its types: a `typedef`, and a `struct`, `union` or `enum` written
    alone;
  - a global, `extern`, its initializer dropped: `int64_t n = 0;` is
    `extern int64_t n;`;
  - a type and a variable at once, both (#200):
    `struct p { int x; } v = {1};` is `extern struct p { int x; } v;`;
  - not what is `static` or `inline`, which is the file's own, but the
    type a `static` variable defines with it, where it has a tag:
    `static struct c { int n; } now;` is `struct c { int n; };`.
  - An `#inline C` in a function stays in the library.

### In a function

```swift
let sum(n:int32):int64 {
    var total:int64 = 0
    #inline C {
        for (int i = 1; i <= n; i++) { total += i; }
    }
    return total
}

let main():int32 {
    println(sum(10))                    // 55
    return 0
}
```

- **What it may hold:** C statements and declarations, as a C block's.
- **The locals:** it sees the function's parameters and locals by their
  C names, which are their own: `n` and `total` above.
  - An anonymous function's `$0` is `_kv_arg0`.
  - A `let` is `const` in C, so C cannot assign it; write a `var`.
- **Jumps:** a C `return`, `break`, `continue` or `goto` leaves as C
  leaves.
  - The owners it leaves are freed still: Kelvin frees them by C's
    `cleanup` attribute, which any leaving runs; `longjmp` and `exit`
    do not.
  - C must not return an owner, as `return s;`: the owner is freed as it
    leaves. Return it from Kelvin, which moves it out (see
    [ownership.md](ownership.md)).
  - A function whose value C returns needs no Kelvin `return`.

## The ABI

- Kelvin writes C: `i64` is `int64_t`, `u8^` is `uint8_t *`, a struct is
  `struct point`, a function is a C function of its name.
  - A program's one function of a name keeps that name.
  - A function with overloads, or one imported from a Kelvin file, is
    named by its parameter types (`twice__i64`), as
    [functions.md](functions.md) says.
- `let main(argc:i32, argv:[cstr]):i32` is C's `main`, and `argv` is
  written `char **`.
- `u8` and C's `char` mix freely; see [strings.md](strings.md).
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

- C's `int64_t`, `uint8_t` and `double` are Kelvin's `i64`, `u8` and
  `f64`, or `int64`, `uint8` and `float64` by their full names (#151),
  each the same C type; a header's own typedef of those names, where
  one has it, is shadowed by Kelvin's.

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

- kelvinc runs `$CC` (`cc` by default) with `-std=c11`, `-I` of the
  `.k` file's directory and of the `modules/` directories,
  `-ffp-contract=off` (so clang and gcc round `a * b + c` alike), and
  `libkelvin.a`.
- `KELVIN_CFLAGS` adds flags, and `kelvinc -v` prints the command.
- `kelvinc --emit-c` writes the C instead of compiling it.
- `kelvinc --lib M.k` builds a module instead of a program: `M.kh` and
  `libkM.a` in `./modules`, which `#import <M>` brings in and links,
  and `libkM.dylib` or `libkM.so` (#146, #147, [modules.md](modules.md)).
  The library is C, so a C program links the shared one too, calling
  the module's functions by the names `--emit-c` shows.

For the C features Kelvin cannot spell yet, see
[versusC.md](versusC.md).
