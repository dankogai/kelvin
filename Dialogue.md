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

### 15. Commit and push

> commit and push to main

**Claude** committed #14 as `cd53342` and pushed. CI passed all four jobs
with 39/39 tests.

### 16. Review findings for #14, and fixes

Under ultracode, **Claude** ran an adversarial review in the background.
Three reviewers (grammar, generated C, docs) each hunted for breakage by
running kelvinc, and an independent verifier tried to reproduce every
finding. There were 20 findings: 19 confirmed and 1 rejected, which come
down to 8 distinct issues. All are fixed, and the repro for every
confirmed finding was re-run against the new build.

- **`x as i64 * 2` did not parse.** After `as`, `*` was taken for a C
  pointer declarator. It is now multiplication.
- **C casts to typedef names could slip through and change meaning.** With
  an operand that starts with `-`, `(`, `&`, `*` or `+`, as in
  `(size_t)-1` or `(int32_t)*p`, Kelvin parsed arithmetic but C read a
  cast. A parenthesized lone name is now emitted as `((name))`, so C
  rejects these at the `.k` line instead.
- **Misleading errors:**
  - `(int32_t)!x` and similar got a generic parse error; they now get the
    C-cast hint.
  - `(int)c` got two rounds of errors; it now gets one message.
  - The `int^` pointer hint was not Kelvin; it now says `i32^`.
- **Statements starting with a converter** were rejected as C
  declarations.
- **`i32(a, b)`** silently became a comma expression; it is now an error.
- **Compound literals** with typedef names (`(div_t){...}`) and under
  `sizeof` failed; both now work.
- **Stale docs:**
  - Design.md note (8) still said `var f = 1.5` needs a type.
  - The #13 examples and the suffix hint omitted `var`.
  - versusC.md filed `as` under P11.

The rejected finding: `sizeof(FILE^)` cannot work, because Kelvin reads
`FILE^` as a dereference. It predates #14 and is now documented as a
limitation. Eight regression tests were added.

### 17. Second review round

A second adversarial round aimed at regressions from the fixes found 11
problems. All 11 were confirmed, and all are fixed:

- **A regression from round one.** `i32(x)` had stopped grouping its
  argument, so `i32(TOTAL)` with `#define TOTAL 1.5 + 2.5` converted only
  the `1.5`. Converters emit `((T)(v))` again.
- **More casts that slipped through.** A parenthesized call or index could
  also be a C type name, as in `(__typeof__(x))-1` or `(_BitInt(9))(x)`.
  Double parentheses now cover calls and indexes too.
- **C declarations that slipped through.** `size_t(n) = 7;` and
  `size_t * p = &n;` compiled as C declarations. Such statements are now
  parenthesized, at the cost of `(printf(...));` in the generated C, or get
  the `var` hint.
- **Typedef compound literals with suffixes** (`(size_t[2]){...}`,
  `(div_t^){...}`) now work.
- **Hints:**
  - `v as T*` gets the pointer hint again.
  - The C-declaration hint now names a real type, e.g. `var x: struct pt`.
  - `(long double)x` no longer suggests `i64`.
  - `u8^(p)` and `sizeof i32` get accurate hints.
  - `(void)x` points to `v as void`.
  - `(int){1}` is no longer called a cast.

Every repro was re-run against the new build, and 11 regression tests
were added (59 in total).

### 18. Third review round

A third round, aimed at the round-two changes, confirmed 13 findings and
rejected 1.

**Revert.** The round-two statement wrapping was a bad trade.
`(timeradd(...));` broke every header macro that expands to a statement:
do/while macros, `SLIST_INIT`, `static_assert`, `__asm__` and `_Pragma`.
All of these had worked before. C has no construct that forces
expression-statement parsing without breaking such macros, so **Claude**
reverted it. Instead, Kelvin now rejects every C-declaration shape it can
recognize at the start of a statement or `for` initializer:

- `i32 * r = &x;` suggests `var r: i32^`
- `size_t ** r` suggests `var r: size_t^^`
- `size_t m = 3;` suggests `var m: size_t`
- `struct pt *p;` suggests `var p: struct pt^`
- `F ~ cb = 0;` is rejected too, since Apple's clang reads `F ^ cb` as a
  block pointer

The one shape that cannot be told apart, `typedefname(x);`, is documented
as a limitation.

**Other fixes:**

- GNU and C23 keywords like `__extension__ * p` and `__real__(U8)(300)`
  smuggled in C's prefix `*` and casts, so they are rejected (P20).
- `sizeof (T * (U8))` compiled as the size of a C function type, so a
  parenthesized sizeof operand now gets double parentheses.
- Hints:
  - `(uint8_t*)p` and `(FILE **)p` now get the cast hint.
  - `v as u8* : q` and `v as u8* == q` get the pointer hint.
  - `sizeof i32^` now suggests `sizeof(i32^)`.
  - `(size_t)++x` gets the cast hint.
- A missing `;` before a block is no longer misread as a compound literal.

The generated C is clean again: `printf(...)` is emitted unwrapped. The 72
tests pass with clang and gcc and under the sanitizers.

### 19. Fourth review round

The fourth round confirmed 15 findings and rejected none. Four were
regressions caused by the round-two and round-three guards themselves:

- Double parentheses broke `__attribute__((fallthrough))`. They are now
  emitted only where an operand follows, which is the only place C could
  read a cast.
- The C-declaration detector rejected valid expressions such as
  `n * sq(3) == 18 || puts(...)`. It now requires the declarator to end
  in `;`, `,` or `=`.
- Nested brackets like `[sizeof t / sizeof t[0]]` defeated the
  compound-literal check.
- `__asm__ __volatile__` got a bogus hint.

The detector also missed `size_t * (p) = …` and `size_t * p^ = …`, and
its hints dropped qualifiers, array sizes, storage classes and
`_Complex`. All of this is fixed, along with:

- `_Pragma` is now allowed only as a statement of its own, since
  `_Pragma("") * p` smuggled in a dereference.
- `__signed__` and `__complex__` are added to P20.
- Function prototypes and function-pointer declarators get their own
  messages.

**A pattern worth noting.** Each round closes one way for C to read
Kelvin text differently from Kelvin's parse, and the fixes add new edges
of their own. The root cause is that kelvinc does not read C headers, so
it cannot know which names are typedefs or macros. Two residual classes
are documented: a `typedefname(x);` statement, and header macros that
expand to nothing or to an operator. The remaining choice belongs to the
user: keep heuristic guards, teach kelvinc to read headers, or keep the
guards minimal. There are 87 tests.

### 20. Strategy for C misreading Kelvin text

**Claude** asked how far Kelvin should go:

1. keep the heuristic guards
2. read C headers with `cc -E` to learn typedef names
3. keep only minimal guards

> Keep the guards, stop here

The current guards stay, the residual cases remain documented
limitations, and no further review rounds are run.
