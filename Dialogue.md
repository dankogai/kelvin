# Kelvin dialogue log

This file logs the conversation that shapes Kelvin. The user's words are
quoted. Claude's side is summarized. The resulting design lives in
[Design.md](Design.md).

---

## 2026-10-01 — Session 1

### 1. Kickoff

> Let's start implementing kelvin. An attempt to implement a `better C`. It
> is virtually named by you:

**Claude** asked three questions: the implementation language (C, Rust or
Go), the backend (compile to C, LLVM IR or assembly), and the first
priorities. The user dismissed them.

### 2. The name

The user pasted the naming rationale that Claude had written earlier:

> I'd call it **Kelvin**.
>
> C is also the symbol for Celsius, and Kelvin is its natural successor. The
> step size is identical, so everything you know about C carries over
> one-to-one, but it's shifted onto an absolute scale where nothing goes
> below zero. That's a neat metaphor for keeping C's semantics while
> eliminating the undefined-behavior basement. The file extension `.k` is
> short, and "absolute zero overhead" writes its own tagline.
>
> Runners-up: **Sequel**, **P**, **Coda**, **Seam**.
>
> Kelvin wins because the pun is also a design spec.

**Claude** chose the defaults on its own: a compiler written in C11 that
compiles to C. It then built "v0.1" in a single step: a type checker,
runtime traps replacing undefined behavior, slices, `defer`, `let`/`var`,
`i32`-style types, wrapping operators, 59 tests and a design doc.

### 3. Draft PR

> Create a pull request for the changes in this session, as a draft.

**Claude** opened dankogai/kelvin#1. The user merged it.

### 4. CI

> add the GitHub Actions workflow

**Claude** added a workflow that runs on Linux (gcc, clang) and macOS
(clang), plus a sanitizer job. The commit landed on the branch after #1 had
already been merged, so it is not on `main`.

### 5. Reset: bare C, bit by bit

> Hey, you are going too fast! Kelvin is meant to be a quiet alternative to
> C:
>
> * no bloating: no intention to be like `C++`.
>    * abi should be 100% compatible with C.
>    * preprocessor is TODO.
> * Start with bare C and change bit by bit:
>    * postfixing types is good! Exactly what I was asked for
>    * but what about pointers? they must be postfixed, too! `*` is not
>      quite appropriate because they would all look like multiplication
>      operators. let `^` does the job like Pascal. `obj->mem` is now
>      `obj^.mem`
> * log the dialogue in `Dialogue.md` and the cumulative results in
>   `Design.md`.

**Claude** asked three follow-up questions. The user answered:

| Question | Answer |
|----------|--------|
| Pointer type: `^int` (Pascal) or `int^` (postfix)? | **`int^` (postfix)** |
| `^` clashes with XOR (`p^ - 1`). What should XOR become? | **binary `~`** (`~a` stays NOT) |
| What happens to the v0.1 extras (traps, slices, defer, ...)? | **Strip to bare C** |

**Claude** rewrote `kelvinc` as a syntax-only translator (v0.0.1):

- The type checker, runtime and all v0.1 extras are removed. The C compiler
  now does all checking, so semantics and ABI are C's.
- Agreed changes #1–#4 are implemented (see Design.md).
- Decisions the implementation forced are listed as provisional P1–P12 in
  Design.md, for review. The most important is **P1/P2**: array brackets are
  also postfix (`int[4]`), with runs of brackets in C order.
- `#line` directives map C compiler errors back to the `.k` file.
- Tests are rewritten for the baseline, and CI is kept but simplified.

Open for the user: review provisional decisions P1–P12.

### 6. Functions use `name: type` too

> types are always marked with `variable:typename` style even for
> functions. `add64(lhs:i64, rhs:i64):i64` instead of
> `fn add64(lhs:i64, rhs:i64) -> i64`. No need for `fn`, no need for `->`
> operator.

**Claude** implemented this as agreed change #5. `fn` is no longer a keyword,
and a top-level `name(` starts a function. The tests and examples are
converted. Claude asked about two related points instead of deciding them,
recorded as Q1 (drop `var` too?) and Q2 (`i64` type names?) in Design.md.

### 7. Sized integers, and `char` must die

> kelvin builtins `<stdint.h>` features and always specific to int sizes.
> defaults to `i64` when type is inferred like `var i = 42`but when you
> declare with type it is always explicit. `char` should die. use `u8`. so
> should `long`. use `u64`,`i64` or `u128`,`i128` where available.

**Claude** implemented this as agreed changes #6–#8:

- The built-in types are `i8`…`i64`, `u8`…`u64` and `i128`/`u128`.
- `char`, `long`, and also `short`, `int`, `signed` and `unsigned` (reading
  "always specific to int sizes" as covering them) are errors that suggest a
  replacement.
- `var i = 42;` is an `i64`. Only integer literals are inferred for now.

Claude recorded one consequence as provisional P13. C's string literals and
libc are typed `char`, but `u8` is `unsigned char`. They are ABI-identical,
so kelvinc silences C's warnings about the mix and emits `main`'s `argv` as
`char **`.

Q2 is answered. New open questions Q3–Q7 cover `float`/`double`, `_Bool`,
`size_t`, literal suffixes like `10UL`, and printing `i64` without
`PRId64`.

### 8. Floats and bool

> f32 and f64 for floats, bool builtin.

**Claude** implemented these as changes #9 (`f32`/`f64`; `float` and
`double` are rejected) and #10 (built-in `bool`; `_Bool` is rejected). It
added `true`/`false` alongside `bool` as provisional P14, since
`<stdbool.h>` provides all three together. Q3 and Q4 are closed. The new
Q8 asks whether `var f = 1.5` should infer `f64` and `var b = true` should
infer `bool`.

### 9. f64 inference, importing C headers, versusC.md

> infer C's `double` as `f64` as well. `#import <whatever.h> as C` does
> `#include <whatever.h>`. C's .h are importable. Document differences
> from C to `versusC.md`.

**Claude** implemented:

- **#11:** `var d = 1.5;` infers `f64`. `1.5f` and `1.5L` are not inferred.
- **#12:** `#import <x.h> as C` and `#import "x.h" as C` become `#include`.
  Any other `#` directive is still an error.
- **versusC.md:** a C programmer's reference to every current difference.

Supporting headers needed two provisional decisions:

- **P15:** any identifier after `:` is a type name, so `FILE^` and `size_t`
  from headers work.
- **P16:** a quoted header is searched next to the `.k` file.

A test imports `<stdio.h>`, `<stdlib.h>` and `<string.h>` plus a local
header, and passes a Kelvin function to `qsort`. New open question Q9:
casts to typedef names like `(size_t)x` do not parse. That is C's typedef
ambiguity, and it would need either header reading or a different cast
syntax. Q7 is updated: once `<stdio.h>` is imported, C's format checking
shows that `%ld` versus `%lld` for `i64` differs between Linux and macOS.

### 10. Merge to main

> merge kelvin-v0.1 to main

**Claude** committed the uncommitted bare-C rewrite onto `kelvin-v0.1`,
merged the branch into `main` (non-fast-forward, since `main` held the #1
merge commit) and pushed.

### 11. First CI run

> check the CI result

All four jobs passed with 26/26 tests: Linux gcc, Linux clang, macOS clang,
and sanitizers. GitHub warned that `actions/checkout@v4` runs on the
deprecated Node 20.

### 12. No literal suffixes; checkout@v5

> for Q6 and Q8: No. no more size hint in the literal. val:u64 = 10
> instead of val = 10UL, f:f32 = 1.5 instad of f = 1.5f. update `ci.yml`
> to use `checkout@v5`.

**Claude** implemented:

- **#13:** C literal suffixes are errors. The message suggests the matching
  typed declaration: `10UL` suggests `x: u64 = 10`, `10L` suggests
  `x: i64 = 10` and `1.5f` suggests `x: f32 = 1.5`.
- **Q8 answered no:** `var b = true;` needs `: bool`.
- The workflow now uses `actions/checkout@v5`.

versusC.md has a new "Literals" section, including the one gotcha: C's
`1UL << 40` becomes `(u64)1 << 40`, because a bare `1` is still C's `int`.

### 13. CI check, always

> check the CI result. always do

The run on `030c450` passed all four jobs with 33/33 tests, and the Node 20
warning was gone after the `checkout@v5` bump. **Claude** now checks CI
after every push without being asked.

### 14. No C casts: `T(v)` or `v as T`

> abolish typecast as `(type)v`. It must be either a "converter function"
> as `type(v)` or `v as type`. The latter is appropriate for
> `malloc(...) as type`.

**Claude** implemented this as #14. `as` is a new reserved word, and both
forms have C's cast semantics. Implementation choices, recorded as
provisional:

- **P17:** `as` binds like C's cast, tighter than binary operators and
  looser than prefix ones.
- **P18:** `T(v)` works only for built-in types, since `size_t(n)` would be
  indistinguishable from a call.
- **P19:** compound literals `(T){...}` stay.

`v as T` resolves Q9 (`n as size_t`). New Q10 asks whether compound
literals should get a Kelvin spelling. `(T)v`, and C-style casts to
typedef names like `(size_t)n`, are errors with a hint.
