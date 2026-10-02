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

### 21. Drop `var`; `0xdead:u16`

> drop `var` too: `x: i32 = 0` declares a variable.  `0xdead:u16` also works

**Claude** asked three questions: how inference is written without
`var`, how far `expr:T` reaches, and how labels and `name: T`
declarations are told apart. The answers:

> `i = 42` is inferred as `i:i64 = 42`.  `u = 0xdead:u16` is identical to
> `u:u64 = 0xdead`, also identical to `u = 0xdead as u16`.  Do not use `:=`
> just yet.

- `expr:T`: any expression.
- Labels: declaration wins.

**Claude** implemented:

- **#15:** no `var`. `x: T = v` declares, and so does `x = v` when `x` is
  not declared yet. kelvinc now keeps a table of declared names for this.
- **#16:** `expr:T` is the same as `expr as T`.

`u:u64` in the middle of the answer was taken as a typo for `u:u16`, and
that is recorded in Design.md. Flagged as new open question Q11: kelvinc
cannot see C globals from headers, so `optind = 1;` would declare a local.
`extern optind: i32;` is the workaround. All tests, examples and docs are
converted, with 92 tests in total.

### 22. The prelude: `print` and `println`

> A7: implement `print()` and `println()` as a part of "prelude".  include
> it in`libkelvin.{a,so,dylib}`.

**Claude** implemented #17:

- **Header.** `runtime/kelvin_prelude.h` defines `print`/`println` as C11
  `_Generic` macros over the `kv_print_*` functions.
  - C's own type names are used, because `int64_t` is `long` on Linux but
    `long long` on macOS.
  - `__VA_OPT__` allows zero values. GNU comma elision was tried, and it
    fails in strict C11 mode.
- **Library.** `runtime/prelude.c` is built into `libkelvin.a` and
  `libkelvin.dylib`/`.so`. kelvinc includes the header and links the
  static library, and it finds the runtime in `$KELVIN_HOME`, the source
  tree or the install prefix.
- **Provisional decisions:**
  - P21: formatting
  - P22: layout and linking
  - P23: `true`/`false` are emitted as `bool`s, since C's `true` is an
    `int` and would print `1`
  - P24: decimal literals above `INT64_MAX` get C's `U`, because without
    suffixes C warns about them
- **Tests.** `tests/run/prelude.k` covers every type, and `tests/c/`
  checks the library from C, linked both statically and dynamically.

Q7 is closed, and there are 96 tests.

### 23. Commit, a red CI run, and a fix

> commit and push to main

`2182327` failed CI on Linux, although it had passed every local check
on macOS:

- glibc declares `realpath` only with `_XOPEN_SOURCE`, so the clang and
  sanitizer builds failed.
- glibc on x86 prints the NaN from `0.0 / 0.0` as `-nan`.

**Claude** pushed a narrow fix as `f5fed5a`. `main.c` now uses
`_XOPEN_SOURCE 700`, and the prelude prints every NaN as `nan`. The
prelude test now covers a negative NaN. CI is green on all four jobs with
96/96 tests.

### 24. Methods, `toString()` and `fmt()`

> like Swift and many other lanugages, each type has methods.  and
> `.toString()` is mandatory.  for `printf()` like formats, `.fmt()`a la
> Raku is available e.g. `pi.fmt("5a")` is `"0x1.921fb54442d18p+1"`.  BTW,
> `f64.toString()`defauts to `f64.fmt("%.17g") which is lossless.

**Claude** asked four questions. The answers:

| Question | Answer |
|----------|--------|
| How are methods defined? | `point.toString(): String` (Swift-like, implicit `self`) |
| What do `toString`/`fmt` return? | A fixed inline buffer (`String`) |
| What does "mandatory" require of structs? | An auto-derived default, which can be overridden |
| Does `print` use `toString`? | No, `print` stays as it is |

`pi.fmt("5a")` was read as `pi.fmt("%a")` (Shift+5).

**Claude** implemented #18:

- **Runtime.** `runtime/string.c` provides `String`, plus `toString()` and
  `fmt()` for the built-in types.
- **kelvinc:**
  - parses method definitions and calls
  - dispatches calls with C11 `_Generic`, since there is no type checker
  - derives `toString()` for every struct and union
  - ends a number before `.name`, so literals take methods

The provisional choices are P25–P30: `String` size, dispatch rules,
`toString` formats, the derived format, `fmt` rules, and literal method
calls. There are 103 tests, which also pass with the runtime and the
generated code under ASan/UBSan.

### 25. Commits, `scratch.k`, and the review of #18

> commit and push to main

**Claude** pushed #18 as `f90118b`, and CI passed with 103/103. The commit
had also swept in a rename of the user's own root-level `hello.k` to
`scratch.k`, through `git add -A`.

> remove scratch.k from git and ignore it

> push it

`scratch.k` was untracked and ignored (`e118a64`). Claude now stages only
the files it changed.

**The review of #18** (one round) confirmed 33 findings and rejected 2.
All are fixed in this change.

- **`fmt()`.** Its core was rewritten so the caller's format is never
  passed to `printf`. That fixed:
  - negative `i8`/`i16`/`i32` with `%x`/`%o`/`%u` printing 64-bit two's
    complement
  - 128-bit values losing their sign, flags and precision
  - formats over about 760 bytes being cut into undefined behavior, and
    over 511 bytes being rejected
  - stale stack bytes after the NUL
  - flag combinations C leaves undefined
  - huge widths giving empty Strings
  - `bool` and float conversions
- **kelvinc:**
  - method prototypes of built-in types were hoisted above `#import`
  - methods could not recurse
  - flexible array members broke every struct's derived toString
  - `static` toString overrides failed
  - prototypes on header structs were dropped
  - derived toStrings ignored user toStrings of header structs
  - chained calls doubled the C at each link: 22 links made 260 MB, now
    2.6 KB through a GNU statement expression (P31)
  - derived toStrings clashed at link time (now `static inline`)
  - mangled names could collide
- **Lexer.** The P30 change had broken hex floats (`0x1.f4p+9`) and let
  `1.f`/`1.L` back in. Both are fixed.
- **Prelude:**
  - `i8^` prints as text everywhere
  - complex numbers have `toString` (`1+2i`)
  - volatile fields no longer warn
- **Docs.** The stale passages are updated.

There are 108 tests, plus 36 `fmt` checks from C.

### 26. A gcc note on Linux

`6b496ba` failed one test on Linux gcc. On x86-64, gcc notes that passing
a struct with a flexible array member changed ABI in GCC 4.4
(`-Wpsabi`), and a derived toString takes the struct by value. The note
is informational, but the test runner treats any output as a diagnostic.
kelvinc now passes `-Wno-psabi`.

### 27. `:=` assigns references

> let `:=` be an reference-assignment operator.  e.g. `buffer := malloc(8 *
> 1024):i64`.  Pointer assignments must use it. `=` is restricted to value
> assignments.

**Claude** asked four questions. The answers:

| Question | Answer |
|----------|--------|
| What type is `buffer` in the example? | A typo for `:i64^` (`:T` keeps meaning `as T`) |
| Do pointer declarations use `:=`? | Yes: `p: i32^ := &x` |
| Is `p += 1`/`p++` a pointer assignment? | No, allowed as is |
| How strict is enforcement? | Best effort, where kelvinc can see the type |

**Claude** implemented #19:

- `:=` is a token and an assignment operator, emitted as C's `=`.
- kelvinc's scope table now records types, and it works out the type of
  an assignment target from variables, parameters, `self`, Kelvin struct
  fields, `p^` and `a[i]` (P32).
- 27 pointer assignments across 18 tests, and 5 in the docs, moved to
  `:=`.

New open question Q12: should `n := list` infer `n`'s type from the typed
variable `list`? There are 117 tests.

The review of #19 (one round) confirmed 7 findings, all of which are
fixed. The semantics reviewer stalled and was rerun separately.

- An array parameter (`argv: u8^[]`, `a: i32[4]`) is a pointer in C, but
  it was treated as a value. The rule was reversed for it.
- The hints for a missing type and for `var` suggested `=` even for
  references.
- The user's original typo `:= ...:i64` got a hint toward a wrong
  program. It now suggests `:i64^`.
- Type names in messages dropped `volatile` and array sizes.
- Design.md note (15) still said `:=` was unused, and the #19 table row
  and the count above were off.

### 28. The rerun semantics review of #19

Split into two narrower lenses, the rerun confirmed 6 findings and
rejected 1. All are fixed:

- **Top-level `:=`.** `g := 0 as i32^;` at the top level was rejected,
  while the error for `g = ...` pointed to `:=`.
- **Declaration lists.** A later name that already exists, as in
  `for (i = 0, n = 0; ...)` or `k = 1, n = 40;`, was silently redeclared
  as a new, shadowing variable instead of being assigned. This predated
  #19 and broke the #15 rule. Such names are now assigned. With `:=`, the
  same bug had surfaced as a misleading "needs a type".
- **Forward declarations.** A redundant `struct T;` after T's definition
  switched off the `=`/`:=` check for T's fields.
- **`a^` on an array.** It was not checked, while `a[0]` was.
- **`a = x as void`.** The rejected finding, guarded anyway, declared a
  `void` variable. It now asks for a type.

There are 128 tests.

### 29. No `void`: `any^` and `nullptr`

> abolish type `void`.  to mean C's `void *`, introduce `any^`

**Claude** asked how to discard a value, now that `x as void` would go.
The answer:

> not `any`.  it must be `any^`.  Introduce `nullptr` to mean `(void *)0`.
> `ptr:any^;` means `ptr := nullptr`

**Claude** implemented #20:

- `any` is valid only as `any^` (C's `void *`), and `void` is rejected
  with a hint everywhere.
- `nullptr` is a keyword meaning `(void *)0`, and it infers `any^`.
- A reference declared without a value is `nullptr`.

Two readings are recorded as provisional P33:

- The null default is applied to every pointer declaration, not just
  `any^`.
- With `as void` gone and no replacement chosen, a value is discarded by
  writing it as a statement.

The tests' `void^` became `any^`. There are 134 tests.

### 30. Properties: `.size`, `.dec`, `.hex`, `.oct`, `.bin`

> * each variable has `.size` property that returns `sizeof()`.
> * each integer variable {i,u}{8,16,32,64,...} has `.dec, .hex, .oct, and
>   .bin` attributes that return its text representation in `u8^`.
>    * buffer is allocated in stack, not heap we can precalculate the size
>      of the buffer needed.
>    * `.hex, .oct and .bin` prepend `0x, 0o and 0b`
>    * do not omit sign for `i{8,16,32,64...}`.  That is the differentiator
>      from `u{...}`.
> * and give `f{32,64}``.dec` and `.hex`.

**Claude** asked two questions. The answers:

| Question | Answer |
|----------|--------|
| What is `.size` on a struct with a `size` field kelvinc cannot see? | The field wins when unsure |
| What do float `.dec`/`.hex` produce? | `%.17g` / `%a`, always signed |

**Claude** implemented #21:

- **Dispatch.** A property is chosen by `_Generic`. Its text is written
  into a compound literal on the caller's stack, sized from
  `sizeof(x)`, and returned as `u8^`.
- **Fields win.** A field with the property's name wins in Kelvin and C
  structs.
- **Errors.** kelvinc reports misuse it can see, such as `.hex` on a
  pointer or `.oct` on a float.

The details are recorded as provisional P34: sign and magnitude, no
padding, buffer lifetime, and properties on receivers kelvinc cannot see.
There are 141 tests.

### 31. The review of #21

> check the review results

One adversarial round, with a text lens and a resolution lens, confirmed
8 findings and rejected 2. All are fixed:

- **Text dying early.** Text made among a method call's arguments, as in
  `v := a.pass(b.dec)`, lived only inside the GNU statement expression
  that the call becomes, so `v` dangled. Text made in a brace-less `if`
  or `for` body died with that body. **Claude** changed the buffers from
  compound literals at the use site to arrays declared at the top of the
  enclosing block, so the text now lasts until that block ends in both
  cases.
- **Buffer size.** The buffers were sized from `sizeof(x)`, which fails on
  a C bit-field and repeated the receiver a third time. Each buffer now
  fits the text of any type (at most 132 bytes, for `.bin`). It is still
  sized in advance and on the stack. The size had to stop naming the
  receiver anyway, because the declaration now sits at the top of the
  block, where the receiver may not be in scope.
- **Nesting.** Each property repeated its receiver, so `x.hex[2].hex...`
  grew exponentially in C. A receiver that holds a property or a method
  call now goes into a temporary, as a method's receiver does.
- **Pointers kelvinc cannot see.** `getenv("HOME").hex` was only a C
  warning, then a link error. `kv_no_such_property` and
  `kv_no_such_method` now take a struct of their own by value, so any call
  is a C error naming them, with both gcc and clang.
- **Docs.** The README said floats have `.oct` and `.bin`. The
  `snprintf("%#x")` pairing in versusC.md and Design.md differed for zero
  and for signed values, and now reads `"0x%x"` for an unsigned `n`.
  versusC.md now says how enums and C bit-fields behave: gcc's `_Generic`
  does not match a bit-field's type, so one is converted first.

The 2 rejected findings:

- An enum's sign depending on its C type. Both lenses found it; this
  verifier called it C's rule, and the other confirmed it as a
  documentation gap, which is now filled.
- `get().hex` on a call returning a struct with a `hex` field reads the
  property. That is P34's documented rule for receivers kelvinc cannot
  see.

There are 144 tests.

### 32. `.cstr` and `cstr`; `toString()` shelved

> table `.toString()` till we implement a true `string` type (a la C++,
> et al) and add `.cstr` which returns its default text representation in
> `u8^`. and `typedef u8^ cstr`.

**Claude** read "table" as "shelve until later" and asked three
questions. The answers:

| Question | Answer |
|----------|--------|
| What happens to `String` and `fmt()`, which `toString()` shares its `String` with? | Shelve all three |
| What is `.cstr` of a struct or union? | Derived text, `{x: 3, y: 4}`, with a buffer kelvinc sizes from the member types; not overridable for now |
| Is `typedef u8^ cstr` a built-in name or a new `typedef` declaration? | A built-in name |

**Claude** implemented #22:

- **Shelved.** `toString()`, `fmt()` and `String` are gone from the
  prelude and the runtime. The names stay reserved, and using them is an
  error that points at `.cstr`. A call through a C struct's field of that
  name still works.
- **`.cstr`.** Every type's text, as `.dec` writes it: into a buffer
  declared at the top of the enclosing block, returned as `u8^`. Numbers
  are plain decimal, floats lossless, a string is its own text, and other
  pointers are addresses. Each struct gets a derived function and a size
  constant that C computes from the member types; where kelvinc cannot
  see the receiver, the buffer fits every struct so far.
- **`cstr`.** A keyword the parser expands to `u8^`, so `:=` and the
  other reference rules apply. `.cstr` can still name a C struct's field.

Claude's own choices are provisional P35 (sizes, strings in structs,
arrays) and P36 (how the shelved names and `cstr` read). The tests of
`toString()` and `fmt()` became tests of `.cstr` and of the shelving
errors.

An adversarial review round (two lenses) confirmed 8 findings, 7 of them
distinct, and rejected none. All are fixed:

- **A char array behind a C typedef** (`typedef char label_t[16]`) as a
  struct member crashed `.cstr`: its characters were read as a pointer.
  It now shows the text in the array, never past its end.
- **Receivers kelvinc could not see** got a buffer that fit every struct
  declared so far, so one large struct (`u8[1048576]`) made
  `abs(-1).cstr` overflow the stack. kelvinc now sees what Kelvin
  functions and methods return, and anything still unseen gets one
  value's 64 bytes; a Kelvin struct there is a C error naming
  `kv_cstr_unseen_struct`.
- **`const`.** `.cstr` of a `u8 const^` returned a writable `u8^`. It now
  stays const, so C warns as it does for the plain assignment.
- **Warnings.** clang `-Wall` flagged every unused derived function (as it
  did for `toString()`), and `.cstr` of a `u8 volatile^` warned and
  printed an address. Derived functions are now marked unused, and
  volatile bytes are an address without warnings, as members too.
- **`.cstr =` as a designator** for a C struct's field named `cstr` was
  rejected.
- **`String` in `v:String` and in a for-loop declaration** gave unrelated
  errors instead of the shelving one.
- **Docs.** They said every value has `.cstr`; C struct values do not.

There are 150 tests.

### 33. The second review of #22

> run the review of #22 again

The second round, with the same two lenses on the committed code,
confirmed 6 findings, 5 of them distinct, and rejected 1. All are fixed:

- **Members spelled in C.** Inside a struct, a pointer to a C typedef
  (`xmlChar^`, `uint8_t^`) printed an address instead of its text, a
  `void *` or complex typedef printed `{...}`, and a `char *restrict`
  typedef printed the pointer's own bytes as text. A char array is now
  recognised by its exact type, byte strings and `void *` by name, and
  anything else kelvinc cannot print shows as `{...}`.
- **Seeing through results.** kelvinc saw `get().cstr` but not
  `get().a.cstr`, `first()^.cstr` or `(v as T^)^.cstr`, which failed in
  C; through a call, `.cstr` of an array also slipped past the array
  check. kelvinc now sees through `^`, `[i]` and fields of call, method,
  `as` and compound-literal results.
- **Code for structs never printed.** Every struct got a derived `.cstr`,
  so a method named `cstr_size` clashed with the size constant, and a
  flexible array member behind a C typedef broke `sizeof` in programs
  that never used `.cstr`. The constant is now `kv_cstr_size_point`, and
  only structs whose `.cstr` is used get the derived code.
- **Docs.** They said `toString` and `fmt` stay reserved, but plain
  functions and variables may use those names (`printf(fmt: ...)`). Only
  the method names and the type name `String` are reserved. Three code
  comments still mentioned `toString()`.

The rejected finding: defining `point.cstr()` gives the parser's generic
error, as any keyword used as a method name does.

There are 151 tests.

### 34. Conditions are `bool`

> add `bool`type in core. `b.cstr()` is `true` or `false`.  `if (cond)
> {...}`and `while (cond)` are now `if cond {...}`and `while cond {...}`
> and `cond` must be strictly `bool`.  `while (fgets(...)){...}` is no
> longer allowed.  you have to write `while fgets(...) != nullptr {...}`

**Claude** noted that `bool` was already built in (#10) and that `b.cstr`
already gives `true`/`false`, and that without parentheses a body has to
be a block. It asked four questions. The answers:

| Question | Answer |
|----------|--------|
| Which conditions must be strictly `bool`? | All: `if`, `while`, `do`, `for`, `?:`, and the operands of `&&`, `||` and `!` |
| Which statements drop their parentheses? | `if`, `while` and `do-while`; `for (...)` and `switch (...)` keep them for now |
| How is "strictly `bool`" enforced where kelvinc cannot see a type? | The C compiler checks it, and comparisons and logical operators give a real `bool` |
| `b.cstr()` or `b.cstr`? | Keep the property, `b.cstr` |

**Claude** implemented #23:

- **Syntax.** `if cond { ... } else if cond { ... } else { ... }`,
  `while cond { ... }` and `do { ... } while cond;`. Parentheses around a
  condition are grouping; C's `if (c) x = 1;` is an error asking for a
  block.
- **Checking.** kelvinc rejects conditions it can see are not `bool`,
  with a hint (`'x != 0'`, `'p != nullptr'`). Elsewhere a condition goes
  through `_Generic((c), bool: kv_bool, default:
  kv_condition_is_not_bool)(c)`, so `while fgets(...)` is a C error
  naming `kv_condition_is_not_bool`.
- **`bool` values.** Comparisons, `&&`, `||` and `!` are `(bool)` in
  value positions, so `println(a == b)` prints `true` and
  `sizeof(a < b)` is 1.

Claude's own choices are provisional P37: `do`'s body is a block too,
`for` keeps a statement body, a `(...)` before a condition's `{` is never
a compound literal, `?:` between two `bool`s is a `bool`, and a
discarded `a && f();` keeps C's form. The tests moved to the new syntax;
two lost a brace-less `if` body, which now only a `for` can have. There
are 160 tests.

### 35. `t = true` infers `bool`

> The following should not be an error since `true` is a bool literal so
> the type is obviously inferrable.
>
>     scratch.k:8:5: error: 't' needs a type: write 't: T = ...' ...
>           t = true;

**Claude** agreed: the note on #11 had `b = true;` need `: bool`, and #24
reverses it. `true` and `false` now infer `bool`, like `42` infers `i64`.
Only the literals do: `ok = a < b;` still needs `: bool`. There are 160
tests.

### 36. Every `bool` infers; assignment is a statement

> `ok = a < b;` should be okay. `println(0 < 1)` works as expected. All
> bool expressions yields an assignable value. Should there be no
> exception. If there should, tell me. (there is a chance `ok = a < b`
> may be parsed as `(ok = a) < b`? Oh, I think we should abondon lvalue
> assignment as well).

**Claude** answered that `ok = a < b` is always `ok = (a < b)`, since
assignment has the lowest precedence, and that the one exception is a
`bool` kelvinc cannot see, such as a C function's result. It asked three
questions. The answers:

| Question | Answer |
|----------|--------|
| Does assignment become a statement, and what about `++`/`--`? | "`++` and `--` should be trashed as well as Swift have done that. as for pointers, add `.next` and `.prev` attributes. Forbid index value mutation within `[]`. good old days of `*p++ = *q++;` are gone." |
| May `for` clauses hold comma lists of assignments? | Yes |
| A `bool` kelvinc cannot see? | Keep the exception: it needs `: bool` |

**Claude** implemented #25 and #26:

- **#25.** A comparison, `&&`, `||`, `!`, `true`/`false`, `bool(x)`,
  `x as bool`, and any `bool` value kelvinc sees (variables, fields,
  Kelvin functions' results) infer `bool`.
- **#26.** `=`, `:=` and `+=` and friends appear only at the top of a
  statement or a `for` clause, where they take a comma list. `++` and
  `--` are errors that suggest `x += 1` or `p := p.next`. `p.next` and
  `p.prev` are `p + 1` and `p - 1` for a pointer kelvinc sees; elsewhere
  `.next` is a field, so `n := n^.next` still walks a list. With no
  assignment inside expressions, nothing can change inside `[...]`.

Claude's own choices are provisional P38: comma lists of assignments are
allowed in any statement, `.next` of an array is an error, `any^` has no
`.next`, and `p += 1` stays. Tests that used `++` or `--` now use
`+= 1`, `-= 1` or `.next`. There are 168 tests.

### 37. The review of #23-#26

**Claude** ran one adversarial round, with two lenses, on #23-#26
before the commit. It confirmed 8 findings, 5 of them distinct, and
rejected none. All are fixed:

- **`?:` between two `bool`s kelvinc sees.** `c ? x : y` with `bool`
  variables stayed C's `int`: it printed `1`, failed as a condition, and
  did not infer. It is now a `bool` whenever both branches are.
- **`sizeof(T)` before the body's `{`.** `if n > sizeof(i64) {` read the
  body as a compound literal, and `if n == sizeof(i32) {} { ... }` even
  made the second block the body without a word. A compound literal in a
  condition now needs the expression to go on after its `}`, as in
  `(struct point){1, 2}.x == n`, which also stopped calling that a C cast.
- **A comma expression as a condition**, `if f(), ok {`, split into two
  arguments of the C check.
- **Comma lists.** Whether `a = 1, b = 2;` declared or assigned was
  decided by its first name, so `b` stayed undeclared, and
  `k = 1, a += 1;` was rejected. Each item now decides on its own.
- **Docs.** The README's first example, a loop in versusC.md and one in
  Design.md used a pointer as a `for` condition, and two places still
  said `:=` works inside expressions.

There are 169 tests.

### 38. `let` and `var`; ranges

> I now remember why it had `var`. I wanted mark mutability of the
> variable and `var` is obviously mutable. Which one is sounds better,
> `let` or `val`? `let mut` for `var` is way too ugly.

**Claude** recommended `let`: `val` and `var` differ by one letter, while
`let`/`var` is Swift's pair, which Kelvin already follows elsewhere.

> I agree and as a Swift programmer I am used to it. go for `let`.
>
> * let i = 42; i+= 1 is error.
> * function parameters are `let` unless you explicitly say `var`. var
>   f(p:i32^){ p := p.next } is error.
> * `for(var i = 0; ...)` should be discouraged. Let's introduce range.
>   `..<` and `...` and `for i in 0..<count {}` where `i` is immutable
>   within `{}`.

**Claude** asked four questions. The answers:

| Question | Answer |
|----------|--------|
| How are declarations written? | Always `let` or `var`, as in Swift; a plain `x = 0;` assigns |
| The type of `i` in `for i in a..<b`? | From the bounds; `for i: u8 in` writes it |
| How far do ranges go? | Only in `for ... in` for now |
| A mutable parameter, and `self`? | `f(var p: i32^)`; `self` is a mutable copy |

**Claude** implemented #27 and #28:

- **#27.** `let` and `var` start every local and global declaration
  (`let k = 42;`, `var n: i32 = 0;`, `static var calls: i32;`). A `let`
  is C's `const`: assigning to one kelvinc sees is an error, and C
  enforces the rest. A let pointer is fixed, while what it points to is
  not. Parameters are lets unless written `var`, and are `const` where
  the function is defined. `x: i32 = 0;` without a keyword gets a hint,
  and `again: n = 0;` is a label, as in C.
- **#28.** `for i in a..<b { }` and `for i in a...b { }` evaluate the
  bounds once and give the body a `const` copy of the counter. A closed
  range up to a type's maximum ends rather than wrapping. `for _ in`
  needs no variable.

Claude's own choices are provisional P39 and P40. All the tests were
converted with the previous compiler's own record of where each
declaration starts; a few that tested the old rules were rewritten. The
README's first example is now a test too. There are 180 tests.

### 39. The review of #27 and #28

> check the review results

The round confirmed 8 findings, 6 of them distinct, and rejected none.
All are fixed:

- **A let parameter of a C typedef that is an array**, such as `jmp_buf`
  (or `va_list` on x86-64), became `const jmp_buf`, which C turns into a
  pointer to const elements, so the definition no longer matched its
  prototype. kelvinc now leaves such parameters without `const` and
  checks assignments to them itself.
- **A range up to a const bound** made the hidden counter const, which C
  rejected naming a variable nobody wrote. The counter now drops `const`
  and `volatile`; only the loop variable is const.
- **Non-integer ranges** got through when only the lower bound was a
  float or the type was written (`for y: f64 in`). Both bounds and a
  written type are checked now.
- **Hints.** Assigning to a range variable suggested `var`, which a
  range variable cannot take; it now suggests a copy, `var k: i64 = i;`,
  and a let parameter suggests `var p` in the parameter list. A
  brace-less range body got an example that is not Kelvin, and `0..n`
  was reported as member access.
- **Docs.** Two versusC.md samples declared variables whose type cannot
  be inferred, and Design.md still described #15's rules in P11, Q11,
  note (19) and the implementation table. Q11 is answered by #27.

There are 185 tests.

### 40. More examples

> add more examples. how about `linkedlist.k`that demos linked lists?

**Claude** added five examples next to `hello.k`:

- `linkedlist.k`: a list of `malloc`ed nodes, changed through a pointer
  by `push`, `pop`, `reverse` and `clear`, and read by the methods `sum`,
  `contains` and `show`. A node's `next` is a field, read as `n^.next`.
- `fizzbuzz.k`: a range, `bool` conditions and `else if`.
- `primes.k`: the sieve of Eratosthenes, with nested ranges.
- `strings.k`: `cstr`, pointers stepping with `.next` and `.prev`,
  `<string.h>` and `<ctype.h>`, and `.hex` and friends.
- `shapes.k`: structs with methods, derived `.cstr` text, and `<math.h>`.

Each ends with `// out:` lines, and `tests/run.sh` now checks an
example's output when it has them. The README lists the examples. There
are 190 tests.
