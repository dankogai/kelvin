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

### 41. The review of the examples

> run the review of the examples

One round, with a correctness lens and a teaching lens, confirmed 5
findings, 3 of them distinct, and rejected 2. The examples themselves
were sound: their output, memory use (ASan, UBSan and `leaks`) and
comments all held. All three findings were in the test runner and the
README, and are fixed:

- **`hello.k` was not checked.** It had no `// out:` line, so the README's
  "each one ends with the output it prints" was false for it. It now has
  one.
- **Missing markers turned the check off.** An example without `// out:`
  lines was only built and run, so deleting or mistyping every marker
  silently stopped checking its output. Examples are now compared
  exactly like the tests in `tests/run`.
- **"exited with status 0".** After `if ! cmd`, `$?` is the status of the
  negation, so every crash or non-zero exit was reported as status 0,
  since the first commit. The runner now saves the status first, also
  for `tests/c`.

The 2 rejected: the runner ignores stderr, as its header says, and
`primes.k`'s expected line ends in a space, as several older tests do.
There are 190 tests.

### 42. Struct, union and enum names without the keyword

> struct st and union un are auto-typedef'd so you don't have to add
> structand unionwhen you use them

**Claude** asked two questions. The answers:

| Question | Answer |
|----------|--------|
| Enums too? | Yes, as in C++ |
| May `struct point` still be written? | Yes, both forms |

**Claude** implemented #29: kelvinc reads a bare tag name as the tag
wherever a type is read, including inside the struct itself
(`next: node^`), in `sizeof(point)` and in `(point){1, 2}`, and writes
`struct point` in the C. No C typedef is emitted, so a variable or
function may share the name. Its choices are provisional P41. The
examples, the README's first example and versusC.md's samples now use
the bare names. There are 192 tests.

The review of #29 confirmed 6 findings, 5 of them distinct, and
rejected none. All were about a bare name where an expression could
stand too, and are fixed:

- **A constructor named like its struct.** With `node(v: i64): node^`,
  `sizeof(node)` meant the function, which C sizes as 1 byte, so
  `malloc(sizeof(node))` under-allocated. In `sizeof`, a function of the
  tag's name no longer counts.
- **Header names.** After `struct timezone;`, the header's variable
  `timezone` became the struct in `(timezone)` and `sizeof(timezone)`.
  A struct only declared in Kelvin now leaves its name to C there.
- **A variable's own initializer.** `let point: i16 = sizeof(point)` read
  the tag, and `let p: node^ := malloc(sizeof(p^))` allocated a pointer's
  size. A variable is now in scope from its declarator, as in C.
- **Hints.** `point^ p;` and `sizeof point` lost Kelvin's hints, and
  Design.md still listed tags as unchanged from C.

There are 195 tests.

### 43. A style guide

> style guide. functions should be
>
>     f(...):T {
>       ...
>     }
>
> like other blocks.

**Claude** asked about two details of the snippet that differed from
the code in the repository. The answers:

| Question | Answer |
|----------|--------|
| Indent by 2 spaces, as in the snippet, or 4, as now? | 4 spaces |
| `f(...):T` without a space after the colon, or `f(...): T` as now? | No space |

**Claude** wrote `Style.md` and applied it everywhere Kelvin code
appears: a function's `{` on its header line, and no space after a type's
colon (`x:i32`, `f(a:i64):i64 {`). The tests and examples were
reformatted with kelvinc itself reporting where each type's colon is, so
labels, `case`, `?:`, strings and expected output kept their spaces; six
error tests that name a line moved up by one. kelvinc's hints now
suggest code in the same style (`var x:i32`), and the samples in the
README, versusC.md and Design.md follow it too. This file keeps the
earlier entries as they were written. There are 195 tests.

### 44. `for x in s`

> the following types of loops are frequent enough to...
>
>     while s^ != 0 {
>             if strchr("aeiouAEIOU", s^) != nullptr {
>                 n += 1;
>             }
>             s := s.next;
>         }
>
> make iterators available as:
>
>     for c in s  {
>             if strchr("aeiouAEIOU", c) != nullptr {
>                 n += 1;
>             }
>         }
>
> can you handle this pattern? The same logic also applies to linked list
> anything the sequence is terminated by a terminator value (usually
> '\0' or `nullptr`

**Claude** proposed choosing the walk by `s`'s type and asked three
questions. The answers:

| Question | Answer |
|----------|--------|
| What is the loop variable of a list, and how is the link found? | Each node's pointer, through the `next` field |
| An array of known length? | "up to the number of elements it is known but break early on terminator value" |
| A `nullptr` string? | Empty |

**Claude** implemented #30: a pointer to numbers or pointers walks to the
first 0 or `nullptr`, a pointer to a struct with `next` walks the list,
an array walks up to its length or the terminator (all of an array of
structs, which has none), and a pointer kelvinc cannot see is walked like
a pointer. Its choices are provisional P42. `vowels()` in strings.k and
the list walks in linkedlist.k now use it. There are 202 tests.

### 45. The review of #30

**Claude** ran a review round of #30 before reporting it. The round
confirmed 8 findings, 6 of them distinct, and rejected none. All are
fixed:

- **`for x:T in s` read the sequence as `T`.** The hidden pointer took
  the written type, so `for b:u8 in xs` with `xs:i32[3]` read each `i32`
  as bytes, past the array's end. The pointer now reads the elements as
  what they are, and only `x` converts each one. A list's loop variable
  must be the node's pointer.
- **A row of a variable length array was evaluated twice**, once more
  by `sizeof`, so `for x in m[row()]` called `row()` twice. An array is
  now reached through a pointer to it, taken once.
- **An array in a value that a call returns**, as in
  `for x in make().xs`, was read after C had discarded the value. It is
  an error now, which suggests copying the value into a let first.
- **An array parameter**, which C passes as a pointer, was walked past
  its declared length, up to a terminator. A let array parameter now has
  its declared length, when that length is made of numbers, lets and C's
  constants, and is an error otherwise. A var one may have moved, so it
  is walked as a pointer.
- **`for arg in argv`** in `main`, whose `argv` C types `char **`, warned
  in clang and failed in gcc. The hidden pointer now converts it.
- **Compound literals in the head**, such as `(i64){1}..<3` and
  `(i32[3]){1, 2, 3}` before the body, were taken for the body. This also
  broke ranges that #28 accepted. Both work again.

The hidden lines of a loop now map to the `for`'s line, where C's
warnings about them belong. There are 207 tests.

### 46. Function types and anonymous functions

> let us support anonymous functions. True closures are too much for
> normal C (ignore GNU extensions) but ordinary functions which does not
> enclose any external variables should be okay. Like Swift, the last
> function can be an anonymous function defined as `{...}`.
>
> * `$` means entire argument stack where each argument can be accessed
>   `$[idx]`.
> * `$0` is `$[0]`.
> * add `examples/sort.k` this anon functions are in action

**Claude** noted that `$0` needs a type, and Kelvin had no function types,
while kelvinc cannot see a C function's parameter types (such as
`qsort`'s comparator). It asked four questions. The user took each
recommendation:

| Question | Answer |
|----------|--------|
| How is a function type written? | `(T, U):R`, a function's head without names |
| Where no type is in sight, how does an anonymous function write its parameters? | `{ (a:T, b:U):R in ... }`, as in Swift |
| May one expression be the body, without `return`? | Yes: `{ $0 < $1 }` |
| What may index `$`, and where? | A number only, and only in anonymous functions |

**Claude** implemented function types as #31 and anonymous functions as
#32. Its choices are provisional P43 and P44. These are:

- An anonymous function becomes a static C function placed before the
  declaration around it.
- Using a local of the function around it is an error.
- A trailing `{ }` ends a statement without `;`.
- In the head of `if`, `while` or `for`, a `{` after a call starts the
  body, as in Swift.
- A body without a result may be one assignment, as in
  `each(xs, n) { total += $0 }`.

A C function with `char` parameters cannot be stored in a function type
with `u8` ones, since C sees two different function types; an anonymous
function wraps it. `examples/sort.k` sorts with a Kelvin insertion sort
that takes the order as a function, and with C's `qsort`. There are 227
tests.

### 47. The review of #31 and #32

**Claude** ran a review round of #31 and #32 before reporting them. The
round confirmed 38 findings, about 20 of them distinct, and rejected 6.
All are fixed:

- **A statement after a trailing function could be glued on.** Without a
  `;`, a next line starting with `(`, as in `(p as i64^)^ = 42;`, was read
  as a call of the previous call's result. That could write to the wrong
  place without a warning. As in Swift, a new line after the trailing `}`
  now ends the expression. Two such statements in one body are
  statements now, not one broken expression.
- **Names in parameter types escaped the no-closure check.** An array
  length in a written parameter, `(a:i64[k])`, could name a local of the
  function around it, which C then read as a global of the same name.
  That is an error now. An array parameter whose type comes from
  elsewhere keeps its length only when it is a number, and is otherwise
  a pointer, as C makes it.
- **`$4294967296` meant `$0`, and `$[2147483648]` crashed kelvinc.** Large
  indexes are out of range now, and `$00` asks for `$0`.
- **Globals.** An anonymous function in a global's initializer could not
  use that global, or one declared before it in the same `let`. Each is
  now declared before its declaration and defined after it, which also
  ends doubled C diagnostics about the head of the function around it.
- **Initializer lists.** `{ (n:u8):i64, 2 }`, valid before, was taken for
  an anonymous function. A list now types its items from the struct's
  members or the array's elements, so `{ $0 - $1 }` works for a member of
  a function type.
- **Smaller fixes.**
  - `sizeof($0)` wrote `$0` into the C.
  - A trailing function inside a converter's parentheses or a compound
    literal in a condition was taken for the body.
  - `c ? f as (i64) : g` took the `?:`'s `:` for a result type.
  - A function's name had no function type, so `add.cstr` printed an
    address.
  - `print(f)` converted a function to a data pointer.
  - `{ $0.hex }` returned a dead buffer, and is now an error.
  - Unused `$k` parameters warned under `-Wextra`.
- **Messages.** Too many arguments before a trailing function now say
  so. The hint about conditions appears only in a condition. Pointers to
  function types and bare `f:(T):R` declarations say what is wrong.
- **Docs.** The docs cover all of the above, and P43, P44, Q12 and
  versusC.md's type inference list are updated. The style for anonymous
  functions is marked provisional. Names starting with `kv_`, which the C
  kelvinc writes uses, are reserved.

The rejected 6 were these:
- A struct member called like a method follows the documented P26
  dispatch rule.
- `break` out of an anonymous function is checked by C, as in any
  function.
- `sizeof(point)` naming a local of the function around it follows the
  no-closure rule.
- `{ $0 + 1; }` without a result matches named functions.
- One example comment was accurate.
- One finding repeated another.

There are 244 tests.

### 48. The review of #31 and #32, again

> run the review of #31 and #32 again

The second round confirmed 48 findings, about 25 of them distinct, and
rejected 2. Several came from the first round's own fixes. All are fixed:

- **The new-line rule went too far.** The first round ended an expression
  at any new line after a trailing `}`. A continuation such as `- apply(4)
  { ... }` on the next line was then silently dropped as a statement of
  its own. Now, as in Swift, only a `(` on the next line starts a new
  statement, and only at the top level of one. An operator or `.member`
  goes on with the expression. Another statement on the same line needs
  a `;`, in a block and in an anonymous function's body alike.
- **Initializer lists, again.** `{ (n:i64) * 2, 3 }` and `{(p:i64^)^, 1}`
  were taken for anonymous functions. The `(a:T)` shape now counts only
  where no expression can go on after it.
- **Lengths from another scope, again.** The first round decayed only a
  parameter's outer array. Now kelvinc records, where a type is written,
  whether an array length names a local or a parameter. In a type taken
  from elsewhere, such a length makes the outer array a pointer, and is
  an error anywhere else (`(i64[2][n])`, `(i64[k]^)`). Lengths of numbers
  and globals are kept, so `(i64[N])` with a global `N` walks `N`
  elements, as in a named function.
- **The dead-buffer check** looks through `as`, `?:` and the comma, and
  treats `.cstr` of a value kelvinc cannot see as text in a buffer.
- **`kv_` names** are now rejected as loop variables, tags, methods and
  labels too. `for kv_i1 in ...` had read garbage.
- **Placement.** A global of a `let`/`var` list is now its own C
  declaration, after its anonymous functions' prototypes. A struct, union
  or enum gets its anonymous functions placed too. Their prototypes print
  array parameters as pointers, as the definitions do.
- **Smaller fixes.**
  - `c ? f as (i64) : nullptr` misread the `:`.
  - `add.size` was 1, and is now a pointer's size.
  - `println(&add)` and `?:` between functions printed addresses.
  - A method with a prototype lost its context type.
  - `:=` through a cast or a call gave no context.
  - After C's brace elision or `.a.b = ...`, items got the wrong
    member's type.
  - A compound literal ending a line in a one-expression body made it a
    block.
  - `again: (x) = 1;` was called a declaration.
  - An anonymous function that writes its parameters may now stand
    anywhere a value may, such as in `?:`.
- **Messages.** C's `T (*f)(...)` gets the `(...):T` spelling. Messages
  spell `$[k]` as written. A dropped C typedef parameter asks whether an
  argument is missing, and too many arguments name the right callee.
  `i64[2][3]` prints in order.

The rejected 2:
- A literal receiver, such as `3.times()`, is a C `int` that P30
  documents.
- Struct members and C prototypes named `kv_` can clash with the
  runtime's own names.

There are 258 tests.

### 49. The review of #31 and #32, a third time

> run the review of #31 and #32 again

The third round reviewed the commit. It confirmed all 35 of its
findings, about 20 of them distinct. All are fixed:

- **A list passed to a C function compiled silently.**
  `memcpy(buf, {'a', 'b'}, 2)` became a function with no parameters, and
  its address was copied as data. Before #32 this was an error. A
  function without a result must now do something (a call or an
  assignment). A list where a value is meant, also for a struct
  parameter, an assignment or `println`, asks for a compound literal.
- **Tables.** In `{"inc", { $0 + 1 }}`, a string for an array member
  (or a value of a struct's type for a struct member) was taken for
  brace elision, so the next member's function lost its type. Now only
  real brace elision does that, and a C typedef member is taken as a
  scalar.
- **Lengths from another scope, a third time.** A local inside
  `sizeof(i64[k])`, a conversion or a compound literal in a length was
  missed, and so was a written signature that takes the context's result.
  Lengths that C never sees, inside a function type's parameter, no
  longer count. `for x in $0` checks a kept length against the names C
  will see.
- **Dead buffers** are now caught through `+`/`-` and `&x[i]`, and in
  `return` statements of an anonymous function.
- **Values.** Where a `{` may start a function, it is now parsed as an
  expression. So `{ (a:i64):i64 in a * 2 }(3)` and `!= nullptr` work as
  an argument, an initializer, an assigned value and a return value.
- **Smaller fixes.**
  - `$0 as i64 * $1` was taken for a C pointer type.
  - `&fp` of a function-pointer variable was taken for a function.
  - `.size` and `sizeof` of an anonymous function, and `sizeof(f)` of a
    named one, gave 1; they are now a pointer's size.
  - `out: (i64(n));` was called a declaration again.
  - A struct naming itself in an anonymous function inside a member's
    length failed in C, and now gets a `struct s;` first.
  - `$` inside an anonymous function nested in a written signature was
    rejected.
- **Messages.** C's `T (*f)(...)` gets the `(...):T` hint also for
  Kelvin type names, at the top level, as a member and as a parameter.
  Inferring a type with a parameter-named length says why it cannot.
- **Docs and tests.** The docs note that `main` is not a
  `(i32, u8^^):i32` value, since C types its `argv` as `char **`. The
  documented behaviors without tests have tests now.

There are 275 tests.

### 50. Inline anonymous functions

> anonymous function are inlined by default.

**Claude** asked two questions. The user took each recommendation:

| Question | Answer |
|----------|--------|
| What does "inlined" mean in the C that kelvinc writes? | `static inline`, C11's own hint, not GNU's `always_inline`, and not kelvinc specializing the callee |
| A way to opt out? | Not yet; it may come with a Kelvin `inline` for named functions |

**Claude** made every anonymous function, its prototype included,
`static inline` (#33). They keep `__attribute__((unused))`, since clang
still warns about an unused `static inline` function in a `.c` file.
With `kelvinc -O`, clang folds the comparators of `examples/sort.k`
into the Kelvin `sort` that calls them, and keeps only the one that
`qsort` needs. Inlining does not change what a program prints, so the
tests show only that the C compiles cleanly. There are 275 tests.

### 51. `.type` and `.typename`

> every variable has an attribute `v.size` == `sizeof(v)`. And pointers
> have `(p0 - p1).diff` which returns `ptrdiff_t`

**Claude** was about to ask how this related to the existing `x.size`
and how to read `.diff`. The user declined the questions and wrote
instead:

> every variable has `.type` where `v.type == typeof(v).` if possible,
> add `.typename` which returns a `cstr`.

**Claude** asked four questions. The user took each recommendation:

| Question | Answer |
|----------|--------|
| Where may `v.type` stand? | Where a type goes; in an expression, `x.type` stays a field |
| What does it become in C? | The type kelvinc sees (without a let's own const), else `__typeof__(v)` |
| What text does `.typename` give? | The Kelvin spelling, else `_Generic`'s name of a built-in type, else `"?"` |
| `(p0 - p1).diff`? | Later, as a change of its own (Q13) |

**Claude** implemented #34. Its choices are provisional P45:

- `v` is a name or `$k` with `.member`, `^` and `[i]` steps.
- In `sizeof(x.type)` and `(x.type)`, a field wins where there may be
  one.
- `point.type` of a tag is an error.
- `kv_typename` in the prelude covers C's built-in types and pointers to
  characters and `void`.

There are 280 tests.

### 52. The review of #34

**Claude** ran a review round of #34 before reporting it. The round
confirmed 56 findings, about 30 of them distinct, and rejected 5. All
are fixed:

- **The prelude included `<limits.h>`** only to spell C's `long`, which
  broke Kelvin names such as `INT_MAX` or `LINE_MAX`. The prelude now
  asks the compiler with `__SIZEOF_LONG__`.
- **Copied types re-evaluated their expressions.** `var b:a.type` for a
  variable length `a` printed `a`'s length again where `b` is declared.
  There it could name another variable, take a changed value, or call
  a function twice. Where the type holds such an expression, it is now
  C's `__typeof__(a)`, and kelvinc keeps the type it saw for its own
  checks. The same goes for a parameter whose declared type kelvinc
  cannot see (`jmp_buf`), and for a function, whose fallback is a
  function value.
- **Qualifiers.** `const xs.type` dropped its `const` on an array; it is
  now on the elements, as in C. A `for` counter typed by a `__typeof__`
  no longer keeps the bound's `const`.
- **Result types** that name a parameter through `__typeof__` are an
  error, since C writes the result first.
- **More places.**
  - `$0.type` works in compound literals and annotations.
  - `(errno.type){5}` and `(const errno.type){5}` work.
  - So do a `for` head over `(xs.type){...}` and a written result
    `{ (x:i64):x.type in ... }`.
  - `sizeof(inc.type)` and `sizeof(red.type)` work.
  - An anonymous function may be passed to a `.type` parameter.
- **`.typename`.**
  - A literal is C's (`42` is `i32`, as `42.size` is 4), and `nullptr`
    is `any^`.
  - A type holding a `__typeof__` asks `_Generic`; it was the source
    text, as `"errno.type^"`.
  - A pointer to a function type reads `((i64):i64)^`, and the text is
    escaped for C.
  - A C struct is spelled `struct cpt`, and a `?:` between two values
    of one type is that type, which also lets `(c ? p : q).cstr` work.
- **Messages.** `(k.type)` as a value, `point.type` and `i64.type`,
  `p^.type` of an `any^`, and `.type` arrays of functions get Kelvin's
  own errors.
- **Docs and tests.** The docs now spell out the fallback, the field
  rules, and `_Generic`'s limits (arrays decay, enums, bit-fields). The
  error test that did not test #34 is replaced.

The rejected 5:
- `argv.type` is the documented `u8^^` (P13).
- `point.x.type` gets C's error, as `point.x` already did.
- `abs.type` is C's function type, the agreed fallback (now
  documented, with `f.type^`).
- `(k.type)` was an error either way, and now names `.type`.
- The implementation table is a summary.

There are 285 tests.

### 53. Optional `;` and implicit `return`

> like many modern languages, `;` can be omitted if the statement ends in
> line and `return` is not necessary for expressions.

**Claude** asked three questions. The user took each recommendation:

| Question | Answer |
|----------|--------|
| When may `;` be left out? | At the end of a line, Swift-like: an operator, `.member`, `[`, `?`, `:` or `as` on the next line goes on; a `(` or `{` starts the next statement |
| Where is `return` not needed? | Where a body is one expression, as in Swift and in anonymous functions |
| Should the repository drop its `;`s? | `;` stays valid; Style.md, the examples and the docs leave it out, and the tests keep both forms |

**Claude** implemented #35. Its choices are provisional P46:

- The rule also covers declarations, struct members, structs and
  prototypes.
- `return`, `break`, `continue` and `goto` end at their line, so a bare
  `return` returns nothing, as in Go.
- A trailing function starts on the line of its call's `)`.
- Bodies are parsed as statements, so the one-expression rule is the
  same for named and anonymous functions.
- `count:i32` and `size_t n` at the end of a line still get their
  hints.

The one test that checked a missing `;` before a block on the next line
now checks the same code written on one line, which is still an error.

The examples and the Kelvin samples in the README, versusC.md and
Style.md lost their line-final `;`s, and one-line bodies such as
`descending(a:i64, b:i64):bool { a > b }` lost their `return`. There are
290 tests.

### 54. The review of #35

**Claude** ran an adversarial review in four lenses: regressions of code
with `;`, code without it, implicit `return`, and the docs. Skeptics
confirmed 40 of the 49 findings. Two were questions for the user:

| Question | Answer |
|----------|--------|
| `main():i32 { printf("hi\n"); }` exited 0 before #35 and now exits 3, and `main():i32 { println("hello") }` is a C error. How far does the one-expression rule reach? | It returns unless kelvinc sees the expression has no value (`println`, a function with no result, `_Pragma`), and `main` keeps C's rule that its end returns 0 |
| `return` at the end of a line: Swift takes the next line, and #35 had followed Go | Swift's, in a function with a result; in one with no result it ends at its line, and kelvinc reports a statement after it in the same block |

**Claude** fixed the rest; the details are in P46 and P44:

- Many C-habit checks ignored line breaks. `(a + b)`, `n.hex`, `7:i64`,
  `sizeof(T)` and `(n)` at the end of a line misread the next line as a
  C cast, a method call, a conversion or a compound literal, and so did
  `do { } while (n > 0)`.
- A trailing `{ }` on the next line inside brackets had become an error.
  The new-line rule now applies only at the top level of a statement,
  and `$0` in such a block says why.
- The C-declaration hints fired on `w * h` broken before `+ 1` and on
  `{ x * x; }`. They missed `FILE *fp` before a `}`, which reached C as
  a declaration. A shape now counts at a line end only when the next line
  cannot go on, and also before a `}`. `a * b` is left alone where `a` is
  a name kelvinc sees, or where it is the expression the body returns.
- A body starting with an annotation, `{ (n:i32):i64 in n:i64 * 2 }`,
  had become a label. It is an annotation again, and so is
  `widen(n:i32):i64 { n:i64 }`.
- An assignment or a no-value call as the one expression is an error
  in named functions too. So is a body of more statements that ends in a
  dropped value, as in Rust's `let y = x * 2; y`. Explicit `return x.hex`
  is now caught in named functions as well.
- `*p = 1` at the start of a line keeps its hint. `.typename` is no
  longer taken for buffer text. Hints for anonymous functions name `$0`
  again.
- Docs: stale prose about `;`, inline samples that still ended with `;`,
  and Style.md's "any layout".

New tests cover each rule the review's mutants showed untested. There
are 302 tests.

### 55. The review of #35, a second time

> run the review of #35 again

**Claude** ran the same four lenses on 34568ff. Skeptics confirmed 27 of
the 29 findings. None needed the user's decision. **Claude** fixed them
within the agreed rules, and the details are in P46:

- A value dropped at the end of a branch went unreported, and the
  function fell off its end. Examples are `if x < 0 { -1 } else { 1 }`,
  a case's `"zero"` and a block's `{x, y}`. gcc gave no diagnostic.
  kelvinc now follows every path to the end of a body with a result. It
  also reports a final call that it sees has a result, as in Rust's
  `let y = x + 1` followed by `compute(y)`. In `main` it reports only a
  value with no effect.
- `{ (n:i64):size_t in n:size_t }`, with any C typedef, had become a label
  and returned garbage. It is an annotation again.
- `count:i32` became a no-op annotation when a global was named `count`,
  so a C-era declaration silently wrote the global. Only the expression a
  body returns is an annotation now.
- The `*p` check rejected products broken before a touching `*`, as in
  `*M_PI*r` and `*(1.0 + rate)`. It now fires only when the operand is
  assigned, as in `*p = 1`.
- The never-runs check fired after a `return` that was a `for`'s body,
  and before a block that holds a `goto` label.
- Hints: an Allman trailing function that writes its parameters or fills
  a missing function argument, an Allman `(point)` compound literal, the
  constructor-named `node *head = node(1)`, and `BUFSIZ * count` now get
  hints that fit. Messages point at the statement, and `main` always gets
  its own message.
- Docs: versusC's rules for no-value calls, the never-runs exemptions and
  `*p`, the last Kelvin samples with `;`, and four one-expression bodies
  in samples that still wrote `return`.

Tests now cover returned_statement, the never-runs exemptions, `break`
and `goto` at a line end, the `?` and `as` annotations, and the other
rules whose mutants survived. **Claude** mutated each of 36 new rules in
turn, and every mutant now fails a test. That run found one more case:
`size_t n` before a line starting with `(` had read the next line as the
parameters of a C function declaration. There are 320 tests.

### 56. Struct members in the style guide

> style guide.
>
>     var v:T;  // no space between : and T
>     struct node {
>       value: f64. // spaces between : and type.  preferably pretty indent.
>       next:  node^
>     }

**Claude** asked where else the spaced colon goes. The user chose struct
and union members only, also on one line
(`struct point { x: i32; y: i32 }`). On lines of their own, the types
line up one space after the longest name's colon. Variables, parameters,
results and annotations keep `x:i32`. The snippet's two-space indent and
the `.` after `f64` read as a sketch: indentation stays at four spaces.

Style.md, the examples, the README, versusC.md and Design.md follow the
new layout. The tests keep the layout they were written in, and no hint
of kelvinc suggests member syntax.

### 57. Numbers from text

> add numerical string to numerical value converters as `i64("42")`,
> `"42".i64` and such. You can add base as `i32("755",8)`. You can use
> C's `strtol`(and friends) and `strtod`.

**Claude** asked three questions. The user took each recommendation:

| Question | Answer |
|----------|--------|
| `i64(p)` of a pointer converted its address. Which arguments are read as text? | Strings: a literal, `cstr`, `u8^`/`i8^`, C's `char *` through `_Generic`. Numbers and other pointers convert as before |
| What do `i64("abc")`, `i64("42abc")` and `i8("300")` give? | As `strtol` reads them: the longest number, else 0; out of range clamps to the type's limits (`i8("300")` is 127) |
| The base without one? | 10, as in Swift; with a base, Kelvin's `0x`, `0o` and `0b` are accepted, so `i64(x.oct, 8)` reads `.oct` back |

**Claude** implemented #36. Its choices are provisional P47:

- `v.T` is `T(v)` for every converter type, numbers too (`300.u8` is
  44). A field of that name in a Kelvin struct or a C struct wins.
- A clamp sets `errno` to `ERANGE`. An unsigned type's lowest value is
  0, so `u8("-1")` is 0, where C's `strtoul` would wrap.
- A NULL text, or a bad base at run time, gives 0. A written base
  outside 2 to 36 is an error.
- `bool`, `i128` and `u128` read no text yet.
- Text properties such as `n.hex` count as text, and a number read from
  text may be returned from the function that read it.

Where kelvinc cannot see whether a value is text, macros in the prelude
let `_Generic` choose. They evaluate the value once and stay constant
expressions for numbers, so `let big = u64(UINT32_MAX)` still
initializes a global.

### 58. The review of #36

**Claude** ran an adversarial review in four lenses: the runtime, the
parser and codegen, regressions, and the docs and tests. Skeptics
confirmed 29 of the 33 findings. None needed the user's decision. The
fixes, now in P47:

- A converter of a value kelvinc cannot see pasted it into C ten times.
  Each C diagnostic inside it came out ten times, and nested converters
  grew tenfold per level (six levels: 75 MB of C, seconds to compile).
  Inside a function, the value now goes into a temporary first, and
  plain arithmetic on numbers kelvinc sees (`i64(x + 1)`) converts as
  before.
- A base after a number kelvinc could not see was silently dropped
  (`i32(atoi(s), 8)`); C now rejects it, naming `kv_base_needs_text`. A
  written base is checked in any radix, negated, or as a float. A
  run-time base is taken as 64 bits, not narrowed to `int`.
- "A field named like a type wins" held only for C structs kelvinc sees.
  Now it follows #21's rule for `.size`, that a field wins when kelvinc
  is unsure, so msgpack-style `o.via.i64` is the field, and designators
  take such names too.
- Pointers to C char typedefs (`xmlChar^`, `gchar^`) are left to
  `_Generic` and read. A `?:` of texts is text. A volatile `u8^`
  converts as before.
- `bool(p)` of a `cstr` is the `nullptr` test again; only a string
  literal or a text property is an error. `i128` and `u128` now read text
  too, so every integer converter does.
- `s.i64(16)` gets a kelvinc error, and a union is no longer called a
  struct.
- Docs: the float rules apart from the integer ones, "exactly one value",
  "exactly C's cast", and the last member samples written `name:type`.

Tests cover the runtime rules whose mutants had survived, C's text types
through header functions, and each new check. There are 336 tests.

### 59. `.diff` set aside

> Forget about `(p0 - p1).diff` for now.

Q13, the difference of two pointers as a `.diff` property (a
`ptrdiff_t`), is set aside and no longer pending. `p0 - p1` remains C's
`ptrdiff_t` subtraction.

### 60. `.addr` and `.hex` of pointers

> Add `p.addr` to pointer types which always returns its own numerical
> value. `p.hex` returns its stringified value in a printf format
> `%016p` or `%08p` depending on the size of the pointer. cf:
> (a claude.ai conversation)

The linked conversation needs a claude.ai sign-in, so **Claude** did not
read it. It checked C: `%016p` counts the `0x` in its width
(`0x0000016ee86888` on both compilers here), and the `0` flag with `%p`
is undefined. **Claude** asked three questions, and the user took each
recommendation:

| Question | Answer |
|----------|--------|
| The type of `p.addr` | `uintptr_t`, as wide as a pointer on any target |
| The text of `p.hex` | `0x` and all the digits: `0x000000016ee86888`, 8 digits on a 32-bit target |
| Which values have them | every pointer and function value; an array is an error, pointers keep no `.dec`, `.oct` or `.bin`, and `.cstr` stays as it is |

**Claude** implemented #37. Its choices are provisional P48:

- Where kelvinc cannot see the receiver, `.addr` is a field, as `.size`
  is, since C structs often have one.
- `.hex` there reaches every pointer through GCC's and clang's
  `__builtin_classify_type`.
- `.addr` needs a written type in a declaration.

Two error tests that had pointers without `.hex` now use `.dec` and
`.oct`, which pointers still lack. A third, about a struct, got the new
message. There are 343 tests.

### 61. The review of #37

**Claude** ran an adversarial review in four lenses: the runtime, the
parser, regressions, and the docs and tests. Skeptics confirmed 30 of
the 32 findings. None needed the user's decision. The fixes:

- `.hex` of a compound literal's member, as in `(div_t){.quot = 3,
  .rem = 1}.quot.hex`, had stopped compiling. The new macro's argument
  was not parenthesized, so the literal's comma split it. The older
  `kv_typename` macro had the same flaw. Both are parenthesized now.
- `.addr` treated `&x` of a C name, and text properties such as
  `n.hex`, as unknown values, so it took them for fields. kelvinc now
  sees these as pointers, along with a pointer stepped with `+` or `-`
  and a `?:` of pointers.
- Docs: `.addr` of a pointer only C sees is a field, and is written
  `x as uintptr_t` there. An array only C sees decays in `_Generic`, so
  its `.hex` is an address, as its `.typename` and `.cstr` are. Other
  fixes: the Errors bullet, the `.cstr` sentence, the C column of row
  #37, a quick-table row, and this file's own count of changed tests.
- Tests pin that `.addr` is unsigned, that `.hex` has lowercase digits,
  string literals, `p.addr.hex`, returning `p.addr`, the compound
  literals, and `.hex` of an unseen C struct. There are 344 tests.

Not changed: a method on `u64` does not reach `p.addr` where
`uintptr_t` is `unsigned long`, which `.size` already shares (noted in
P48).

### 62. Hidden names

> When you add hidden variables when translating to C, `kv_` doesn't look
> automatic enough. use `_kv_` instead and trailing word should be the
> one the variable is derived. `_kv_varname_text[36]` instead of
> `kv_text3[36]` or when you resort the the latter style, count the
> prefix number from `0` instead of `1`

**Claude** asked two questions, and the user took each recommendation:

| Question | Answer |
|----------|--------|
| Which hidden names? (C reserves file-scope names starting with `_`, which gcc and clang accept) | Everything kelvinc writes, file-scope names included; the runtime's API keeps `kv_` |
| Numbering | A repeat in a function gets 1, 2, ...; with no source, a number from 0 |

**Claude** implemented #38. The details are provisional P49:

- Each name is `_kv_`, its source and its kind: `_kv_n_text`,
  `_kv_p_self`, `_kv_i_count`, `_kv_x_ptr`, `_kv_main_fn`, `_kv_arg0` and
  `_kv_point_cstr`.
- Names are unique within each C function, so nothing shadows.
- Methods keep `point__area`, since the program named them.
- Kelvin may declare neither `_kv_` nor `kv_` names. Two of the
  reserved-name tests now use `_kv_` names.

### 63. Template literals

> implement the template literal a la JS.
> * backquote up to backquote. multi-line
> * `${expression}` is substituted with the string representation of
>   `expression`

**Claude** asked two questions, and the user took each recommendation:

| Question | Answer |
|----------|--------|
| A template's text can be of any length, so where does it live? | On the heap, freed automatically when the enclosing block ends (GCC's and clang's `cleanup` attribute), with the lifetime `.cstr` text has |
| Which text is `${x}`? | As `print` shows it, so `println(`${x}`)` prints what `println(x)` does |

**Claude** implemented #39. The details are provisional P50:

- The lexer reads the text between backquotes as C string literals,
  with each `${...}`'s tokens in between, so values may nest.
- Escapes are C's plus `` \` ``, `\$`, `\{` and line joining.
- A template without `${...}` is a plain string literal.
- `print`'s text functions are shared with the templates, and a struct
  shows its `.cstr` text.
- Returning a template's text is an error, and so is initializing a
  global with one.

There are 354 tests.

### 64. The review of #38 and #39

The user asked to commit before the review finished, so b311a9c went
out first and the review's fixes follow it. **Claude** ran four lenses:
hidden names, the template lexer and parser, template codegen and the
runtime, and the docs and tests. Skeptics confirmed all 37 findings.
None needed the user's decision. The fixes, now in P49 and P50:

- A template in a switch case, or in a block that a goto jumps into,
  failed with clang and aborted with gcc. C cannot jump past a cleanup
  variable's initializer, so such a block now keeps its templates in
  storage at the top of the function.
- `` c ? `${n} items` : `none` `` printed an address with clang and did
  not compile with gcc 15. A template's text is now a `char *`, as a
  string literal is.
- Re-evaluating a template that reads its own earlier text was a heap
  use-after-free. Each evaluation now builds new text and frees the old
  text only after that. Values go through temporaries, which keeps
  nested templates linear in size.
- `.cstr` of a template slipped past the check against returning its
  text, and assigning a template to a variable of an outer block, or to
  a global, kept freed text. Both are errors now, and so is a `static`
  initialized with one.
- CRLF files, C trigraphs (`??!`), `\}`, the end line of a multi-line
  template, and the positions of unterminated templates are handled.
- Hidden names: an anonymous function in a struct is named after the
  struct. The runtime's `KV_` macros are reserved. The struct text
  helper's own variables are `_kv_buf` and `_kv_p`. Each name stem keeps
  its own count, since searching all names made kelvinc cubic on a
  template with thousands of values. A loop takes only the names it
  uses.
- Tests: the runner now also checks text in the generated C (`// c:`
  lines). That pins the #38 names and the cleanup attribute. More values,
  switch and goto cases, re-evaluation, the reserved names and the new
  errors have tests. There are 363 tests.

### 65. Floats print in plain decimal

> `println(10.0)` prints `1e+01`, `println(100.0)` prints `1e+02` and
> `println(1500.0)` prints `1.5e+03`, while `println(123456.0)` prints
> `123456.0`. [...] 10.0 should print as `10.0`.

The cause: print tried `%.*g` at precision 1, 2, ... and took the first
text that read back as the same value. `%.1g` of 10.0 is `1e+01`, which
reads back exactly, and an exponent got no `.0`. Template literals share
the text, so `${10.0}` was `1e+01` too.

**Claude** compared how Swift, Python and JavaScript print the same
values and asked which rule to follow. The user took the recommendation:

| Question | Answer |
|----------|--------|
| When is a float plain decimal? | Swift's rule: from 0.0001 up to 2 to the power of the type's mantissa bits (2^53 for `f64`, 2^24 for `f32`), where every integer is exact; an exponent otherwise. Python's repr (below 1e16 for every type) and JavaScript's (from 1e-7 to below 1e21, with padded zeros such as `72057594037927940` for 2^56) were the other choices |

**Claude** changed the runtime, recorded in P21:

- The digits are still the shortest that read back the same. Plain text
  pads them with zeros or puts `0.` and zeros in front, and always has a
  `.`: `10.0`, `1500.0`, `9007199254740992.0`, `0.0001`.
- Above the range, and below 0.0001 as written, the text keeps C's
  exponent form: `1e+16`, `9.5e+15`, `1e-05`, `1e+300`. `nan`, `inf` and
  `-inf` are unchanged.
- C's `long double` uses its own `LDBL_MANT_DIG` (64 on x86, 53 on
  Apple's arm64).
- The output matched Swift's `print` for all 1,199,639 `Double` and
  `Float` values tried (random bit patterns, powers of 2 and 10 and
  their neighbours, integers around 2^54 and 2^26), with clang and with
  gcc 15.
- Two tests that expected `1e+03` and `1e+05` now expect `1000.0` and
  `100000.0`. The new tests/run/float_text.k covers the edges and
  templates, and tests/c/prelude.c covers `long double`.

There are 364 tests, and all pass with clang and with gcc 15.

### 66. The review of the float text

**Claude** reviewed b7a3a5a and found seven things:

- Under a C locale with `,` as its decimal point (a C program calling
  `setlocale`), plain text used `.` but exponent text kept the
  locale's `,`: `1.5 1,5e+16`. The old code printed `1,5.0`.
- No test had a negative number below 1 in plain form, or a long double
  fraction.
- `kelvin_prelude.h` did not say when a float has an exponent.
- P21 said "the user's choice" in a table headed "None of them has been
  explicitly agreed yet".
- In tests/c/prelude.c, an `// out: ` line had lost its trailing space,
  a `(bool)!!` had a needless `!!`, and a comment overstated which
  platforms have which long double.

> fix them all, use . in exponent form too

**Claude** fixed them:

- The exponent form is now rebuilt from the digits as the plain form
  is, so both use `.` whatever the locale. The new tests/c/locale.c
  checks this under a `de_DE` or `fr_FR` locale when one exists (macOS
  has them; a bare Linux image may not, and then it checks the C
  locale). Against the old runtime, it prints `-1,5e+16`. The output
  still matched Swift's for all 1,199,639 values, in the German locale
  too, with clang and with gcc 15.
- tests/run/float_text.k now has negative numbers in both forms and the
  extremes (`5e-324`, `1.7976931348623157e+308`, f32's `1e-45` and
  `3.4028235e+38`), and tests/c/prelude.c has long double fractions.
- `kelvin_prelude.h` describes the rule. The provisional table's header
  now allows rows that say "as agreed", as P21 and P27 do. versusC.md
  notes that the point does not follow the locale, as `printf`'s would.
- The test file's line, cast and comment are fixed.

There are 366 tests, and all pass with clang and with gcc 15.

### 67. Complex numbers, imports, overloading and operators

> * add `lib/complex.k`  That implements complex arithmetics including
>   elementary functions.
>    * DO NO USE C99's Complex.  `struct complex { real:f64; imag:f64 }`.
>    * `exp(z) = exp(z.real)*{cos(z.imag), sin(z.imag) }`, for instance.
>    * you can `#import <lib/complex.k>`
>    * ensure that kelvin is multi-dispatch.  `sin(r:f64):f64` is
>      distinct from `sin(z:complex):complex`.
>    * maybe `complex` should be named `complex64` with corresponding
>      implementation of `complex32`.
>    * we are yet to go for generics (even I am tempted to).

**Claude** split the request into four changes, #40 to #43, and asked
five questions:

| Question | Answer |
|----------|--------|
| How does `#import <lib/complex.k>` work? | Include its source, once per program (recommended), rather than compiling it separately |
| What C names do Kelvin functions get? | Only overloaded and imported functions are named by their types, as `sin__complex64` (recommended); not every function, as C++ does |
| How is complex arithmetic written? | Operators, `z + w`, which Kelvin code defines (recommended); not functions or methods |
| What are the types named? Claude recommended `complex128` and `complex64`, by total size, as Go and NumPy name them | "complex{32,64,128} where f{32,64,128} are available. the last one might not be available for some platforms. complex128 iff f128 is available on the platform." |
| `complex128` needs an `f128`, which Kelvin does not have yet | `complex32` and `complex64` now, and `f128` and `complex128` later (recommended) |

**Claude** implemented the four changes. The details are provisional
P51 to P54:

- #40: `#import "x.k"` and `#import <lib/x.k>` put the file's tokens in
  place of the import, once per program. `<...>` is found in Kelvin's
  home, as the runtime is, and `make install` installs `lib/`.
- #41: Calls are resolved by the argument types kelvinc sees, and by C's
  `_Generic` over the arguments only C sees. That `_Generic` falls back
  as a number kelvinc sees would: to the one overload that takes a
  number there; to C's own function of the name where none does; and
  to a C error, `kv_no_such_overload`, where several do. A tie between
  conversions is an error, and open question Q14 asks whether a number
  should prefer its own kind.
- #42: `+ - * / % == != < <= > >=` and unary `-` may be defined for
  structs and unions, and `x op= y` is `x = x op y`.
- #43: `lib/complex.k` has the arithmetic, `conj`, `abs`, `arg`,
  `norm`, `polar`, `exp`, `log`, `sqrt`, `pow`, and the six
  trigonometric and hyperbolic functions with their inverses. Checked
  against C's `<complex.h>` on 39 values, including signed zeros on the
  branch cuts, they agree to 1e-13. The exceptions are four special
  values where macOS's libm departs from Annex G. The inverses use
  Kahan's formulas and `log1p`, so they keep their accuracy near 0 and
  ±1 and do not overflow for large arguments.

While testing, Claude noticed that `println(10.0)` printed `1e+01`, a
bug in the runtime's float text that predated these changes; a separate
session fixed it (entries 65 and 66). There are 386 tests, and
`examples/complex.k` shows the library.

### 68. The review of #40 to #43

**Claude** ran five lenses: imports, overloading, operators, the
numerics of lib/complex.k against C's `<complex.h>` and Python's
`cmath`, and the docs and tests. Skeptics confirmed 66 of 69 findings.
None needed the user's decision, though the dispatch where only C sees a
type was redone. The fixes, now in P51 to P55:

- Imports: kelvinc compared line numbers across the boundary of an
  imported file, so whether a program compiled depended on how many
  comment lines came before a declaration. An unfinished declaration at
  the end of an imported file was reported in the importing file, an
  import inside a function was spliced into it, a `"header.h"` next to
  an imported file was not found, and a directory named `x.k` imported
  nothing. Each import and the end of each imported file are now marked
  for the parser. C functions declared by hand in an imported file keep
  their C names.
- Overloading where only C sees a type: `_Generic` matched exact C
  types, so `char *` missed a `u8^` overload, `long` and `long long`
  went different ways on macOS and Linux, two typedefs of one type
  clashed, and C's own function was named as the default even where it
  did not exist, which broke calls that matched. Numbers are now chosen
  by their Kelvin type (`KV_NUMBER`), other types by C's, each in a
  `_Generic` of its own; a number or pointer of another type goes to
  the one overload that takes one; and C's function is the default only
  where the program calls it.
- Overloading where kelvinc sees types: arithmetic, negated literals,
  bools, enumerators and `nullptr` now have their types, so
  `fact(n - 1)`, `twice(-3)` and `count(nullptr)` choose by them. An
  exact fit on the arguments kelvinc sees wins also when another
  argument is unseen, a pointer may not lose `const`, a parameter's own
  `const` makes no other overload, an overloaded function given to an
  overloaded function chooses by its type, anonymous functions are
  typed only where the overloads agree, and C's function of an
  overloaded name can be used as a value. Function types get distinct
  C names, and two functions with one C name are an error. A struct
  given where a function takes none is reported by C, not taken for
  C's own function of the name.
- Operators: a definition after a global's value or a prototype was read
  as part of it, variadic operators were accepted, an operator for a
  struct declared without its body was refused, a struct that a
  dispatched call returns got C's operator, and `m == a;` was silently
  dropped (C now warns). The tests had overwritten tests/run/operators.k,
  the only test of `~` and `~=`; it is back, and the struct operators
  are in tests/run/struct_operators.k.
- lib/complex.k: `sqrt` of an infinite part recursed until the stack
  overflowed, which also crashed `asin`, `acos`, `asinh` and `acosh`.
  Subnormal arguments, a tiny imaginary part next to ±1 for `atanh`,
  `exp`, `sinh` and `cosh` near overflow, parts near `DBL_MAX`, the sign
  of zero far out, and `pow(0, -1)` are handled. clang fused `a * b + c`
  into `fma()`, so `z * w` differed from `w * z`; kelvinc now compiles
  with `-ffp-contract=off` (P55).
- Tests cover each rule the mutants showed untested: import paths and
  boundaries, the ranking, the dispatch defaults, compound assignment,
  every guard in lib/complex.k and the rest of complex32. There are
  402 tests.

### 69. The review of #40 to #43, a second time

**Claude** ran the review again on the fixes, with four lenses, and
skeptics confirmed all 53 findings. None needed the user's decision. The
fixes, now in P51 to P55:

- Overloading: with lib/complex.k imported, `tanh(atof(s))`, `asin`,
  `atan`, `acosh`, `atanh`, `pow` and `abs` of a number only C sees did
  not compile unless the program called that C function elsewhere.
  lib/complex.k now declares C's functions of the names it overloads,
  and a declared C function is one of the overloads. A program's one
  function given a value only C sees no longer takes its name for C's,
  which renamed it and broke `area(FIRST(shapes))`; an imported function
  of one overload is treated as one in the main file; and C's function
  is a value wherever no Kelvin overload has the type wanted.
- The choice: an enum overload took any `int` only C saw, so numbers
  now come before enums. A seen `i64` given to a `time_t` or `size_t`
  overload chose differently on macOS and glibc, so a seen number fits
  a C typedef by conversion. Two exact fits are a tie; a candidate beats
  another only where both take the same type at the arguments only C
  sees; a literal in arithmetic has C's type, a character is a `u8`, and
  a literal given to a call C chooses is cast to its Kelvin type;
  `&` of a `let` points to `const`; and a pointer loses no qualifier
  below the first level either. A variadic overload takes what no other
  takes in its `...`, and where C's function is known every argument
  only C sees is checked. Function types compare with their array
  parameters as pointers.
- Imports: a hard link, a symlinked header, a CRLF after `#import`, a
  `"` in a directory's name, and a string ending in a backslash at the
  end of a file are handled, and the message about two functions with
  one C name names the other's file.
- Operators: an annotated value such as `(width:f64)` going on to the
  next line was taken for an operator's definition, which is now told by
  its whole head, `op(a:T, ...):R`.
- lib/complex.k: division by a value with an infinite part recursed
  until the stack overflowed; it now gives C's zeros. `acos` beyond
  1e300 lost its real part, `sqrt` beyond 1e300 its small part, `sqrt`
  turned a NaN beside an infinity into 0, `pow(0, NaN)` was infinite, and
  Smith's division lost bits where the ratio of the divisor's parts was
  subnormal.
- Docs: P55 names `-ffp-contract=on`, which brings fusion back without
  `-O`, and says that clang may combine `sin` and `cos` under `-O`;
  versusC's table has rows for #40 to #43; and the claims that entry 68
  made for the tests now hold: the ranking, the result types of calls C
  chooses, each C type's Kelvin number type, every guard in
  lib/complex.k and every complex32 function have tests. With the float
  text of entries 65 and 66, there are 410 tests.

### 70. Template literals without the heap

> let's make template literals heap-free. so far as I know that is the
> only feature of kelvin which implicitly use heap.

**Claude** ran a design workflow. An audit confirmed the claim: kelvinc's
C, the prelude and libkelvin called `malloc`, `realloc` and `free` only
for templates (a counter showed 3001 allocations for 1000 evaluations,
and 1, libc's stdout buffer, for everything else). libc's own stdout
buffer and macOS's small cache for formatting floats remain, as they do
for C's `printf`. Three designers proposed a bounded buffer, exact
lengths, and an explicit capacity; two judges chose the bounded one,
which alone kept today's behavior apart from a cut for long strings
(exact lengths printed the wrong text after a `goto` and changed the
order of evaluation; a 60-byte cap cut ordinary paths). **Claude** asked
four questions, and the user took each recommendation:

| Question | Answer |
|----------|--------|
| How long may a string value be before it is cut? | 256 bytes, with `...`, as P35 cuts a string member; `-DKV_TEMPLATE_STR=n` changes it |
| How does each evaluation write its text? | In a buffer of its own, then copied, as today, so the order and ``s := `${s}b` `` stay |
| The check that text does not outlive its block misses fields, elements and `p^`, as for `.hex` and `.cstr` | Leave it, reword its message; close it later for all block text |
| What is there for longer text? | The macro for now; writing a template into a byte array, later, as its own change |

**Claude** implemented #44. The details are provisional P56:

- A template's storage is a `char` array at the top of its block, with
  room for the literal parts and each value's longest text, which C
  computes and checks with a static assertion. It has no initializer
  and no cleanup attribute, so the switch and goto hoisting is gone.
- Numbers, bools, addresses, a struct's text, the number properties,
  string literals, nested templates and byte arrays of known length are
  shown whole; other strings are cut at 256 bytes with `...`.
- libkelvin's writers take a place and a limit; `kv_template`,
  `kv_template_take`, `kv_template_free` and libkelvin's only `malloc`,
  `realloc` and `free` are gone.

There are 411 tests, and all pass with clang and with gcc 15.

### 71. The review of #44

The user asked to commit #44 before its review finished, so da8e26e
went out first. **Claude** ran three lenses: the runtime's bounds, the
code kelvinc writes, and the docs and tests. Skeptics confirmed 22 of
23 findings, all fixed, none needing the user's decision; P56 has the
details:

- A chain of `?:` between texts made C that doubled with each arm (a
  16-arm chain of month names gave 10 MB of C, and 20 arms more than
  clang could take), and a chain of numbers made kelvinc's own time
  double. The longer arm is now taken through a `union`, and each arm
  is looked at once.
- A byte array whose length was not a literal (`u8[N]`, `u8[2 * 4]`)
  was read past its end; now every byte array is read no further than
  `sizeof` of it tells, and written without a temporary, so the array of
  a struct a function returns (`mk().tag`) is still alive. A byte array
  longer than 256 bytes reserved its whole length twice on the stack
  and crashed where the heap had coped; it is now cut as a string is.
- gcc gives an enum beyond 64 bits an `__int128` type, which the static
  assertion rejected; an enum now has an `i128`'s room. The storage is
  marked unused, as `assert` under `NDEBUG` drops a template, and a
  template in an anonymous function's written parameter types is an
  error, where kelvinc crashed (also before #44).
- The bounds of `.dec`, `.hex`, `.oct` and `.bin` now come from the
  constants their buffers use. A C test checks `KV_TEMPLATE_BOUND`
  against the longest text of each type, and new run tests cover every
  bound, the `?:` bound, byte arrays, storage per call and kept
  pointers, which the mutants showed untested. The docs no longer call
  `.cstr` of a string a property shown whole, and say what growth and
  the stack cost.

There are 415 tests, and all pass with clang and with gcc 15.

### 72. `let` for functions, and `modules/`

> cosmetic changes:
>
> * make `let` mandatory for toplevel functions. Kelvin allows anonymous
>   functions meaning internal functions are available like
>   `var idi64:(x:i64):i64 = { x }` possible. mandating `let` makes the
>   language a little more consistent.
> * move `lib/` to `modules/` and move `libkelvin.{a,dylib,*.so}`
>   therein. add `./modules/` default search directories of the
>   language. Both "include" files and compiled libraries can reside.

**Claude** asked four questions, and the user took each recommendation:

| Question | Answer |
|----------|--------|
| Where does `#import <x.k>` look? | `./modules` of the directory kelvinc runs in, then Kelvin's own `modules/`; `<lib/complex.k>` becomes `<complex.k>` |
| Is a `modules/` a C search directory too? | Yes, `-I` and `-L`; kelvinc still links only libkelvin |
| Where do the prelude header and an installation go? | The header moves to `modules/` too; `make install` copies `modules/` to `$PREFIX/lib/kelvin/modules` |
| Does `let f(...) { }` declare a function inside a function? | No, functions stay at the top level; there it is an error that shows the anonymous function a let holds |

**Claude** implemented #45 and #46. The details are provisional P57 and
P58:

- A function, a method and an operator are declared with `let`, after
  `static` or `extern`: `let main():i32`, `let point.norm():f64`,
  `let +(a:vec, b:vec):vec`. Without it, or with `var`, each is an
  error that shows where `let` goes. Every Kelvin file in the repository
  now says `let`. Since an operator's definition starts with a keyword,
  the rule that its head on a new line ended the value before it (#42)
  is gone.
- `lib/complex.k` and `runtime/kelvin_prelude.h` are in `modules/`, and
  `make` builds libkelvin there. kelvinc finds Kelvin's `modules/` as it
  found the runtime, also under `lib/kelvin/modules` after
  `make install`, and gives C `-I` and `-L` of it and of `./modules`.
- So that a library in `./modules` links on Linux too, `KELVIN_CFLAGS`
  now come after the program's C file.

There are 422 tests, and all pass with clang and with gcc 15. A new
`tests/project/` is built from inside itself, so that its `modules/` is
`./modules`.

### 73. The review of #45 and #46

**Claude** ran three lenses: the parser, the driver and the build, and
the docs and tests. Skeptics confirmed 16 of 25 findings, all fixed,
none needing the user's decision; P57 and P58 have the details:

- A C function-pointer declaration after `var` in a body was told it
  declared a function there, naming the C type; it gets #31's message
  again. A top-level call or `_Pragma(...)` was told to take `let`; only
  a name that parameters follow is told so now, and a statement out of
  place is an error that says so.
- A `./modules` that holds another Kelvin's `kelvin_prelude.h` would
  have given C that header beside this Kelvin's `libkelvin.a`; it now
  comes after the system's headers.
- New tests cover `extern let`, `var` before a method or an operator
  and inside a body, a library in `./modules` linked through
  `KELVIN_CFLAGS`, and Kelvin's `modules/` as `make install` lays it
  out, next to kelvinc and through `KELVIN_HOME`. The last Kelvin file
  without `let` has it, four comments are aligned again, and the docs
  say `let` in the provisional rows and where C looks for a header.

While fixing them, **Claude** made `tests/run.sh` turn its temporary
directory into an absolute path through `cd` and `pwd`, and ran it with
a `TMPDIR` that did not exist. `mktemp` failed, the path became the
repository's root, and the script's exit trap removed the repository,
`.git` included. The user restored it; **Claude** copied back its own
edits to the docs from a review agent's copy, opened the draft PR #3,
and redid the fixes. The runner now stops when `mktemp` fails and makes
the path absolute without `cd`; unusual `TMPDIR`s were tried on a copy
only.

There are 432 tests, and all pass with clang and with gcc 15.

### 74. Inferring from any seen type

> ```
> #import <complex.k>
>
> let main(argc:i32, argv:cstr[]): i32 {
>     var i:complex64 = complex64(0.0, 1.0);
>     println(i.real, i.imag);
> }
> ```
>
> why can not you infer the type of `i`? RHS is obviously `complex64`.

**Claude** answered that it was the rule, not an inability: #11, #24
and #25 let only literals, bools and annotated values infer a type,
from the days when kelvinc knew no types at all. Since #41 it tracks
the result type of every Kelvin function and method, and #25 already
infers `bool` from one, so `complex64(0.0, 1.0)` has a type it sees.
What remains a real limit is a value only C sees, a C function's result
or a macro: `__auto_type` could declare it, but kelvinc would then be
blind to the type, and the checks that depend on it (`=` against `:=`,
lets, overloads, templates' room) with it. **Claude** proposed #47,
inferring from every value kelvinc sees, and asked about arithmetic,
whose type is C's promotion (`small + 1` is an `i32`, not an `i8`).

> go ahead, with arithmetic excluded

**Claude** implemented #47. The details are provisional P59: a
declaration takes the type of its value as overloading sees it, so a
function's or method's result, a variable, a field, `p^`, `a[i]`, `&x`
(to `const` for a let), a compound literal, a text property, a
template, an enumerator, a character, `sizeof` and a `?:` between two
values of one type infer; an array gives the pointer C makes of it.
Arithmetic, string literals, `.size`, `.addr` and what only C sees
still need a written type, and the message says so. `var t = &x` is now
told to write `:=`, as a written reference is.

There are 435 tests, and all pass with clang and with gcc 15.

### 75. Arrays in brackets

> use `[]` for array initializations. `[0,1,2,...]` instead of
> `{0,1,2,...}`. struct/union inits remains the same.

**Claude** asked three questions, and the user took each
recommendation, writing the third answer in full:

| Question | Answer |
|----------|--------|
| `{...}` for an array kelvinc sees, and `[...]` for a struct? | Errors with a hint; where only C sees the type, either is accepted |
| Does `let a = [1, 2, 3]` infer `i64[3]`, as #47 infers from seen values? | Yes, from items of one type |
| Do array compound literals take `[...]` too? | "`(i32[])[1,2,3]`. the number of the elements are inferred from rhs." |

**Claude** implemented #48. The details are provisional P60:

- `[...]` is an array's initializer and `{...}` a struct's or union's,
  nested too: `{1, [7, 8, 9], {5, 6}}`. A `[2] = 5` inside is a
  designator, told from a nested array by the `=` after it.
- `(i32[])[10, 20, 30]` is an array's compound literal, told from
  `(p)[i]` by the type ending with `]`; `T[]` with `[...]` is `T[N]` to
  kelvinc, so `for x in (i32[])[5, 6, 7]` and `.size` know the length.
- `let a = [1, 2, 3]` is `i64[3]`, `[[1, 2], [3, 4]]` is `i64[2][2]`,
  and `[p, q]` of points `point[2]`.
- Every array initializer in the repository was rewritten by a script
  driven by kelvinc's own error positions, 93 of them.

There are 439 tests, and all pass with clang and with gcc 15.

### 76. Array types in brackets, with a count

> * change array type from `T[]` to `[T]` like swift.
> * `[T]` has an attribute `.count` that is set during initialization
> * `var a = [0,1,2,3]` is a type `[i64]` and `a.count` is 4. The size
>   never changes. Variable-sized array like python, swift, etc is to do.
> * to make an empty array, you go `[T](count)`. You get `count` number
>   of zero-filled elements.
> * an array also has `.size` attribute which is simply
>   `a.count * sizeof(T)`.
> * `var` arrays don't expand or shrink but its elements are mutable.
>   `let` arrays locks its elements as well.
> * kelvin promotes array logic rather than pointers. We use pointers
>   only when it is necessary.
> * yet `var p := a` still works. `p^`is now `a[0]`.

**Claude** asked three questions, and the user took each
recommendation:

| Question | Answer |
|----------|--------|
| A member or an uninitialized global needs a count in its type: how? | `[T](N)`, the same spelling as the value |
| May `[T](n)` take a count computed at run time? | Yes, as C's VLA, in a local `var` |
| A parameter `a:[i64]` is a pointer in C: `.count` there? | Allowed; `.count` is an error that says to pass the count |

**Claude** implemented #49. The details are provisional P61:

- `[T]` and `[T](N)` replace `T[]` and `T[N]`, suffixes as before:
  `[i32^](4)`, `[i32](4)^`, `[[i32](3)](2)`. `[const u8]` carries the
  elements' qualifier.
- `[T](n)` is a value of n zero-filled elements; a local `var` of a
  count C computes is a VLA, declared and then zeroed with `memset`.
- `.count` is `sizeof(a) / sizeof a[0]`, so it holds for a VLA; on a
  pointer it is an error that says to pass the count.
- A compound literal `([i32])[10, 20, 30]` now declares the array
  itself; `let q := ...` of it still makes a pointer.
- `T[N]` is an error whose hint spells the type the new way from the
  source as written; a script driven by those hints rewrote every array
  type in the repository.

There are 444 tests, and all pass with clang and with gcc 15.

### 77. `.isNull`

> add `.isNull` to pointer types. `p.isNull` is more concise and easy
> to read than `p == nullptr`.

**Claude** implemented #50 as a property with `.addr`'s rules (#37):
`p.isNull` is `p == nullptr`, a `bool`, of every pointer and function
value kelvinc sees, `nullptr` included; a field named `isNull` wins,
and a value only C sees keeps its field; an array, never null, is an
error. The details are provisional P62.

There are 447 tests, and all pass with clang and with gcc 15.

### 78. The 17th value of `print`

> fix the println limit: make kelvinc report more than 16 arguments

`print` and `println` take up to 16 values (P22). A 17th gave C's
error about a pasted token; kelvinc now says "println takes up to 16
values, and this is the 17th: write two calls".

### 79. The documents

> make `doucments` folder and split documents there. roughly:
>
> * integers
> * pointers
> * c strings (special attention. not just a zero-terminated [u8])
> * struct
> * union
> * modules
> * C interfaces
> * grammar
> * flow controls
>
> also move `versusC.md` there.

**Claude** made `documents/` and split `versusC.md` into it, one topic
a document, keeping the text of each section and adding what the split
needed: an index in `versusC.md`, which keeps the table at a glance,
the reserved words, what is not available yet and the diagnostics;
cross-references between the documents; and new prose where the old
text had none, for C strings (`cstrings.md`: the four kinds of text,
making, reading, walking, comparing and printing it, and where it
lives), unions (`unions.md`) and arrays (`arrays.md`). Beyond the list,
`arrays.md`, `functions.md`, `printing.md` and `properties.md` hold what
fit nowhere else. Every code example in the new prose was compiled and
run. README.md and Design.md link to the new place.

### 80. `p++`

> * reintroduce `++` and `--` just for pointers, postfix only.
>   `p := p.next` seems a little too wordy. if p is not `var` it is a
>   compile-time error.

**Claude** implemented #51: `p++` and `p--` are statements, as every
assignment is (#26), read where an assignment is and errors inside an
expression or as a prefix; the target follows assignment's rules, so a
`let` pointer is an error, and where kelvinc sees the type it must be
a pointer other than `any^`. A pointer only C sees steps as C allows.
The details are provisional P63.

There are 453 tests, and all pass with clang and with gcc 15.

### 81. `cstr` is immutable text

> Let us make it clear that `cstr` is more strict than `char *`:
>
> * it is `[u8]`, not `u8^`
> * lt is immutable. so `s = "I love to hate C"; s[0] = 'U'"` is a
>   compile error.
> * `var p:u8^ := cstr` is still allowed but not encouraged.
> * promote `cstr` over `char *`

**Claude** asked about `.count`, stepping and the escape hatch. The
user wrote the first answer in full:

> strlen(s) for the first use, then sticks till the end of the scope.
> It is okay because It never expands. in C it will be stored in
> `_kv_` variables iff it is actually used.

and then "errors for stepping, implicit cast". **Claude** implemented
#52. The details are provisional P64:

- `cstr` is a pointer to `const u8` that kelvinc knows as text, named
  `cstr` in messages and `.typename`; a string literal, a text property
  and a template are `cstr`, and a string literal infers it.
- Writing through it and stepping it are errors with hints; `&s[i]` is
  the rest of the text, a `cstr` too.
- `s.count` is `strlen`, kept in a `_kv_` variable from the first use
  to the end of the scope, declared only where `.count` is used, and
  measured again after `s := t`.
- A `u8^` takes a `cstr` with a cast kelvinc writes, in declarations,
  `:=`, initializer lists and calls of Kelvin functions; a C function's
  `char *` needs `s as u8^`.
- `examples/strings.k` now reverses through a `u8^` cursor with `p++`,
  and reads through a `cstr`.

There are 457 tests, and all pass with clang and with gcc 15.

### 82. `&` and `operators.md`

> mention the prefix `&` in `documents/pointers.md`. adding
> `documents/operators.md` is also nice.

**Claude** added a section on `&` to `pointers.md` (a let's address
points to `const`, `&a[i]` and `&s[i]`, `&f` is `f`, where it binds,
and that there is no `*`), and `operators.md`: the precedence table,
highest first, with C beside it; what moved and why; operators on
structs; and what is not an operator. The index in `versusC.md` lists
it.

### 83. A struct's own text

> ```
> struct vector2d { x:f64, y:f64 }
> let vector2d.cstr():cstr {
>   `{${self.x}, ${self.y}}`
> }
> ```
>
> does not work with an error like: `expected ':', found '.'`

**Claude** explained the two walls: `cstr` is a keyword, so the method
head did not parse; and the derived text is written into a buffer the
caller owns, which a method's own template could not be returned
into. It proposed `let T.cstr():cstr { ... }` with a body of one
template, which kelvinc compiles into that writer, sized from the
template (#44).

> go with the cstr override, one template body

**Claude** implemented #53. The details are provisional P65: the size
of the text is the template's room, in the enum at the struct; the
writer is defined where the method is, building the template in its
own block and copying it into the caller's buffer; `v.cstr`, `${v}`
and the text of a struct that holds a `T` use it. Any other body, a
parameter, a built-in receiver or a second definition is an error.

There are 461 tests, and all pass with clang and with gcc 15.

### 84. Ownership, and `Bytes`

> is there any kelvin spec that implicitly use heap so far?

**Claude** checked the runtime, what kelvinc writes, and every test's
C: none since #44; what remains is libc's own.

> We have avoided heaps for the sake of memory safety. Buffer overrun
> in still possible but we have made it harder and harder by
> introducing `for in`, `.cstr, .count`, etc. IMHO time is high to
> introduce expandable `String`, `Array` and even `Dictionary`, etc to
> safely use heap, avoiding raw `malloc()` and `free()`. What is your
> recommended strategy?
>
> * Rust-like borrow checking?
> * Object-C-like refcount?
> * Go-like GC?
>
> Though Kelvin is modern, I want to keep it lightweight enough to
> allow `--emit-c`. So we deliberately avoided generics (I love it
> myself), built-in GC, etc.

**Claude** recommended none of the three: ownership by scope with moves
and borrows, the rule kelvinc can enforce from what it sees, and that a
copy through C cannot break, since an owner is never copied implicitly.
Borrow checking needs a type checker with lifetimes; counting needs
every copy seen, which the C ABI denies; a collector is a runtime. The
containers would be plain C structs freed at their block's end with
C's cleanup attribute, moved by `return` and by passing, borrowed as
pointers with the escape rules text already has, and typed without
generics by a prelude macro per element type.

> 0. `Bytes` or `Data` which is simply `var [u8]` which can grow (or
>    shrink if we add a method like `.compact()`, not necessarily `\0`
>    terminated.
>    1. `String` is a sequence of Unicode codepoints. it iterates by
>       codepoints and malformed byte representation is forbidden.
>    2. Generically speaking it is `Array<u8>` but should be treated
>       specially.
>    3. Which do you recommend, `Bytes` or `Data`?

**Claude** recommended `Bytes`: it says what it holds, it pairs with
`String` as Python, Rust and Go pair them, and a capitalized type
would mean "owns heap". It proposed that a `Bytes` keep a NUL after
its last byte, uncounted, so `b.cstr` is a borrow in O(1), and that
`String` be a `Bytes` with the invariant.

> go with Bytes. start the design with the ownership rules (I
> personally like `Data` since I am used to Swift but you are
> convincing enough).

**Claude** wrote the rules O1 to O10 in Design.md, under "Proposed:
ownership", with the surface of `Bytes`, and asked the user the
questions that are theirs.

### 85. `Bytes`

> implicit moves, copy only by .copy(), abort out of range, doubling

**Claude** implemented #54: `Bytes` as a keyword and a type, its
runtime in `runtime/bytes.c` (one struct, its functions, two `_Generic`
macros for `append` and `insert`), and the ownership rules in kelvinc:
the cleanup attribute on locals and parameters, moves on `return` and
on passing with the name dead afterwards, no copy by `=`, borrows as
`&b` with the escape rules text has, a derived free for a struct that
owns, no owner to a C function, and a checked index. Every rule has a
test; the generated C of the main test runs under ASan with every
allocation freed at exit. The details are provisional P66, and the
rules are in `documents/ownership.md`.

There are 474 tests, and all pass with clang and with gcc 15.

### 86. The inner counts of `[[[i32]]]`

> `var array3d:[[[i32]]] = [[[0,1],[0,1]],[[0,1],[0,1]]]` does not
> work: `error: array has incomplete element type 'int64_t[]'` while
> `var array3d = [[[0,1],[0,1]],[[0,1],[0,1]]]` does. Why? Needs to be
> fixed.

Inference (#48) counted every dimension from the literal, while a
written `[[[i32]]]` took only the outer count from the value, leaving
C `int32_t[2][][]`, which it rejects. **Claude** made the written type
count the inner dimensions too, from the first row, which every row
must match, since C has one inner count; a row that is a string is an
error that asks for the count in the type.

### 87. `String`

> now add `String`, a sequence of codepoints on `Bytes`

**Claude** implemented #55 on the owner rules of #54: `String` is a
`Bytes` that holds well-formed UTF-8 and keeps its count of codepoints;
making or appending malformed text ends the program with a message,
`b.isUTF8` asks first, and `b.string()` converts. `for c in s` gives
each codepoint as a `u32`, `s.count` the codepoints, `s.bytes` a
read-only borrow of the bytes. There is no `s[i]`, which would walk
the text, and no `insert` or `remove` yet. A borrow of the other kind
into `append` is an error naming `b.string()` or `s.bytes`, and `print`
of an owner an expression gives, which nothing would free, is an error
too (found while counting allocations). `String` stops being a shelved
word; `toString` and `fmt` stay reserved. The details are provisional
P67, and the codepoint type is Q15.

There are 481 tests, and all pass with clang and with gcc 15.

### 88. `uchr`

> `var s = string("コガイ ダン"); for c in s {...}` gives a stream of
> integers representing codepoints which is a little inconvenient. It
> should be `uchr` type on a stack which is a Unicode codepoint
> internally yet stringified as a utf-8 `cstr` so it prints fine with
> `print()` and friends. `uchr` types has `.utf32` attribute which
> returns `u32`. `.codepoint` can be its alias. Also give array types
> `.uchr` attribute which converts its integer value to `uchr`,
> `U+0000` if failed (is `U+FEFF` better?)

**Claude** implemented #56: `uchr` is a four-byte value, a codepoint
in a struct of its own so that C's `_Generic` can tell it from a
`u32`; `print`, templates and `.cstr` show its UTF-8, `.utf32` and
`.codepoint` give the number, comparisons compare the numbers, and
there is no arithmetic. `n.uchr`, `uchr(n)` and `uchr(text)` make one,
with U+FFFD, the replacement character, where the number is no
codepoint: Unicode defines it for this, where U+0000 is a NUL that ends
C text and U+FEFF a byte order mark. "Array types" was read as integer
types. `for c in s` gives a `uchr` now, and `s += c` appends it. The
details are provisional P68, and Q15 is answered.

There are 484 tests, and all pass with clang and with gcc 15.

### 89. `Array<T>`

> now add `Array`, a growable array of `T` on the heap

**Claude** implemented #57: `Array<T>`, spelled with the element type
in angle brackets, since Kelvin has no generics and this is the one
built-in one: each element type a program uses gets one C struct and
its functions from a prelude macro, emitted before the first top-level
declaration that uses it. It is an owner under the rules of #54,
through the same code as `Bytes`; its elements may own (a `Bytes`, a
`String`, an `Array`), and are then freed, copied and replaced with it,
and the element each loop turn gives cannot be moved. Every allocation
of the tests' C is freed at exit under ASan. The details are
provisional P69.

There are 490 tests, and all pass with clang and with gcc 15.

### 90. `Array([0, 1, 2, 3])`

> Why doesn't `var va = Array([0,1,2,3])` work? It should work as:
> `var va = Array<i64>()` and `va.append(0); va.append(1); va.append(2);
> va.append(3)`

**Claude** found two reasons: `Array` was a constructor only as
`Array<T>(...)`, and `[...]` was a value only as a declaration's
initializer. #58 lets `Array(...)` infer `T` from its argument, and
takes a `[...]` argument as the elements, typed as a fixed array's
initializer is, so that `Array([0, 1, 2, 3])`, `Array<f64>([1, 2.5])`,
`Array([String("a"), String("b")])`, `Array([Array([1, 2]), squares(3)])`,
`Array(fixed)` and `Array(&other)` all work.

> and `Array([ [0], [0] ])` should be parsed as
> `Array([Array([0]),Array([0])])`.

So it is: a `[...]` among the elements is an Array in turn, inferred
or of the written type's element, and `Array([[[1, 2, 3]], [[4], [5,
6]]])` is an `Array<Array<Array<i64>>>`; `Array()` and `Array(n)`
have nothing to infer from and ask for `Array<T>`. The details are
provisional P70.

There are 495 tests, and all pass with clang and with gcc 15.

### 91. A struct with no tag

> add an anonymous `struct`, like `var v:{x:f64, y:f64} = {0.0, 0.0}`

**Claude** added #59: `{x:f64, y:f64}` where a type goes is a struct by
its members alone. One spelling is one type, unlike C's anonymous
structs, each a type of its own: kelvinc declares one tagged C struct
per spelling, `_kv_anonN`, before the first top-level declaration that
writes it, so a value passes to a parameter or an `Array<T>` written
alike. Everything a tagged struct has comes with it: initializers,
the derived text, nesting, arrays, pointers, owners as members. Two
different structs given to each other now get a Kelvin message, since
C's would name `_kv_anonN`. The details are provisional P71.

There are 500 tests, and all pass with clang and with gcc 15.



### 92. A union with no tag, and an enum that knows its case

> add an anonymous `union` too, like `var u:union{i:i32, f:f32}`. And
> "smart union" like Swift's enum which knows its current effective
> type *runtime*. It will lose a byte (beyond 255 types are quite
> unlikely) but it will benefit handling data types like JSON.

**Claude** asked how to spell the smart union and how to read a case;
Dan chose `enum` with typed cases, as Swift spells it, and members
checked at run time. #60 is `union{i:i32, f:f32}` where a type goes,
as #59's struct. #61 is `enum json { null; b: bool; n: f64; s: String;
a: Array<json> }`: one byte of tag and a union of the cases' values;
`json.n(1.5)` and `{.n = 1.5}` make one, `j.n = x` sets the case and
frees what it held, `j.n` reads it and ends the program if another
case is current, `j.is(n)` tests, `switch (j) { case n: ... }`
branches by name, and the text is `n(1.5)`. For JSON the enum holds an
Array of itself and owns, so a struct that owns now has `.copy()` and
may be an Array's element, and the prelude's Array is declared in two
parts around the element's declaration. Every allocation of the JSON
test is freed at exit under ASan. Details are provisional P72 and P73.

There are 509 tests, and all pass with clang and with gcc 15.

### 93. `$"text"` and `$[a, b, c]`

> `String("...")`and `Array([...])`seems too long, may keep users away
> from using. as a human I feel the need for the shortcut. How about
> prefixing them with `$`? `$"I needed it"` is `String("I needed it")`,
> `$[[1,0],[0,1]]` is `Array([[1,0],[0,1])`

**Claude** added #62: `$"text"` is `String("text")` and `$[...]` is
`Array([...])`, nested lists included, through the same code; inside
an anonymous function, `$[k]` of one number stays its parameter k. The
details are provisional P74.

There are 511 tests, and all pass with clang and with gcc 15.

### 94. `switch` without `break`

> Regarding `switch`-`case`, does the current kelvin need `;break;`
> like C? If not, make it unnecessary like `Swift` and many other
> modern languages. And make it exhaustive too. Duff's devices should
> be blown in the wind. You may add `default:` keyword

**Claude**: it did need `break`, as C does. #63 makes `switch` Swift's:
a case ends at the next, `case a, b:` shares a body, an empty case
before another and a case inside a statement are errors, every value
is handled (every case of an enum with values, every enumerator of a
Kelvin enum, or `default:`, C's keyword already), and the parentheses
go: `switch n {`. The C gets a `break` per case, and
`__builtin_unreachable()` where the cases are exhaustive. Two tests
that leaned on fallthrough or had no default were rewritten. Details
are provisional P75.

There are 518 tests, and all pass with clang and with gcc 15.

### 95. `$[T]` as a type

> `var va:$[[i64]]` should work as an alternate expressions as `var
> va:Array<Array<i64>>`. `$` magic applies to type declarations as
> well.

**Claude** added #64: `$[T]` where a type goes is `Array<T>`, and a
`[...]` inside is an Array in turn, so `$[[i64]]` is
`Array<Array<i64>>`, matching the value `$[[1, 0], [0, 1]]`. It goes
wherever a type goes. On the way, indexing an Array an expression
gives, which nothing would free, became an error, as reading its
count was. The details are provisional P76.

There are 522 tests, and all pass with clang and with gcc 15.

### 96. `Dictionary<K, V>`

> now add `Dictionary`, a hash map on the heap. Here it comes!

**Claude** added #65: `Dictionary<K, V>`, or `$[K: V]`, an owner under
the rules of #54, keyed by integers or Strings (the text copied in and
looked up by text), holding any value an Array holds. `$["ann": 31]`
makes one, `d[k] = v` adds or replaces, `d[k]` is checked as `xs[i]`
is, `has`, `find` (a `V^` or nullptr) and `get` (a default) stand in
for an optional, and `for k, v in d` walks the entries in the order
they were added. The C is one struct and its functions per key and
value type, from the prelude, as an Array's is; every allocation of
the tests' C is freed at exit under ASan. The details are provisional
P77.

There are 532 tests, and all pass with clang and with gcc 15.

### 97. `keys`, `values`, `` $`...` ``, and the documents

> now add `keys` and `values` to `Dictionary`, as `Array`s. Also edit
> `documents/arrays.md` and others so it covers dynamic, heap-allocated
> versions as well besides `documents/ownership.md`. Also add `` $`...` ``,
> a dynamic version of template string.

**Claude** added #66, `d.keys` and `d.values`, Arrays of copies in the
order the entries were added, and #67, `` $`a${x}b` ``, a template
built as a String on the heap with no bound on its length, each value
appended as the bounded template would show it and a String whole.
The documents now carry the heap versions beside the C ones:
arrays.md has `Array<T>`, cstrings.md `Bytes` and `String`, and
dictionaries.md is new, with ownership.md keeping the rules. Details
are provisional P78 and P79.

There are 535 tests, and all pass with clang and with gcc 15.

### 98. Slices, and braces for a Dictionary's entries

> now add slicing to `Array` and `String`. Also change Dictionary
> literal notation from `$["key":value]`to `${"key":value}`. Being a
> Swift user I like the former better but the rest of the world is
> more accustomed to braces than brackets :(

**Claude** added #68, slices: `xs[lo..<hi]`, `xs[lo...hi]`,
`xs[lo...]`, `xs[..<hi]` and `xs[...hi]` of an Array, of a String by
codepoint, and of a Bytes, each a new copy, the range checked at run
time; and #69, `${k: v, ...}` for a Dictionary's entries, `${:}` for
none, and `{k: v}` where the type is written, with `$[k: v]` now an
error that names the braces. The type stays `$[K: V]`. Details are
provisional P80 and P81.

There are 541 tests, and all pass with clang and with gcc 15.

### 99. `${K: V}`, and a synopsis per type

> now change the Dictionary type to `${K: V}` too. Also add at least a
> synopsis of properties/attributes or description if necessary, to
> example/T.md. You are squeezing too much in properties.md.

**Claude** moved the type to braces (#70): `${String: i64}`, nested as
`${String: ${String: i64}}` and `${i64: $[String]}`, with `$[K: V]`
now an error that names the braces. Each type's document ends with a
"Properties and methods" table now: integers, pointers, cstrings
(with Bytes, String and uchr), arrays (with Array), structs, unions,
enums (with enums with values), dictionaries and functions; and
properties.md keeps the shared ones in detail, with an index to the
tables. On the way, a string literal where a String is expected
(`var s:String = "x"`, a member, an element, an entry) became a
String by itself; it had reached C as bytes into a struct. Details
are provisional P82.

There are 544 tests, and all pass with clang and with gcc 15.

### 100. `Set<T>`

> now add `Set`, a hash set on the heap

**Claude** added #71: `Set<T>`, or `${T}`, a Dictionary with no
values: `${3, 1, 4}` makes one (braces without colons, as Python
reads them), `${}` is the empty one where the type is known, `s += x`
and `insert` add, `has` tests, `remove` removes, `union`,
`intersection` and `difference` take a borrow and give new Sets,
`elements` is an Array of copies, and `for x in s` walks the elements
in the order added. Every allocation of the test's C is freed at exit
under ASan. Details are provisional P83.

There are 552 tests, and all pass with clang and with gcc 15.

### 101. `T?`, and `|`, `&`, `~` on Sets

> now add `Optional`, a value that may be absent. Also add binary `|`,
> `&`, and `~` operators to `Set`

**Claude** added #72, `Optional<T>` or `T?`: an enum with values with
the cases `none` and `some: T`, made per `T`, so that `.some`
(checked), `.is`, `.case`, `switch`, the text `some(3)`/`none` and the
ownership rules come as they are; a `T` where a `T?` is expected
becomes `some` by itself, `none` is the absent value, and `x ?? y`
gives the value or a default. And #73: `s | t`, `s & t` and `s ~ t`
are the union, the intersection and the symmetric difference of two
Sets, with `|=`, `&=` and `~=` in place. Details are provisional P84
and P85.

There are 560 tests, and all pass with clang and with gcc 15.

### 102. `if let`, and `Result<T, U>`

> now add `if let`, binding an optional's value when present. Also
> implement a `Result<T,U>` As a smart union as `{ ok:T, err:U }` and
> reimplement `Optional<T>` as its special type.

**Claude** added #74 and #75. `if let v = e { ... } else { ... }`
binds the value of an Optional or a Result when it is present, read
once, a let the variant still owns. `Result<T, U>` is an enum with
values with `ok: T` and `err: U`, and `Optional<T>` is now made by the
same maker with `none` and `some`; a `T` where either is expected is
wrapped by itself, `ok(v)` and `err(e)` are words where a Result is
expected, and the type names spell the cases out. Details are
provisional P86 and P87.

There are 566 tests, and all pass with clang and with gcc 15.


### 103. `results.md`, with Optionals as the special case

> Optional<T> is a special case of Result<T, R>, not vice versa. Yet
> `documents/results.md` is absent

**Claude** wrote [documents/results.md](documents/results.md), the
document of `Result<T, U>`: the type, `ok(v)` and `err(e)`, `.ok` and
`.err` checked, `??`, `if let`, `switch`, the text, the C, and `T?` as
its special case in one section. `optionals.md` now opens as that
special case, keeps the Optional's own spelling and examples, and
points at `results.md` for the rest; `properties.md`, `versusC.md`,
`flow-controls.md`, `enums.md` and the README link both, Result first.
No code changed.

There are 566 tests, and all pass with clang and with gcc 15.

### 104. Results in practice, before `try`

> Hold "now add `try`, passing an `err` up". We need more examples and
> practices. Take a look at `lstat(path, buf)` while it has been long
> okay to `a = b` where a and be are structs.

**Claude** held `try` and wrote the practice down first.
[examples/results.k](examples/results.k) wraps C's `timespec_get`,
`fopen` and `getenv`, whose value comes back through a pointer or as a
null with the error beside it, into functions that return a
`Result<timespec, i32>`, a `Result<FILE^, i32>` and a `cstr?`, reads
numbers from a file as `Result<i64, String>`, and passes an `err` up
by hand, the line `try` would write. `results.md` has a section "From
C" with the `lstat` wrapper the user named, `Result<stat, i32>`, and
why the example uses ISO C instead: glibc hides `lstat` under
`-std=c11`. Found on the way: `v ?? "unset"` of a `cstr?` is no text
in C (clang prints an address, gcc refuses), so the literal needs
`as cstr`; a wart to fix.

There are 567 tests, and all pass with clang and with gcc 15.

### 105. `v ?? "unset"` of a `cstr?`

> now fix the wart: `v ?? "unset"` of a `cstr?`

**Claude** fixed it in `??`: a string literal, or text of another
spelling, on the right of a `cstr?`, `u8^?` or `i8^?` is cast to the
value's type, as a declaration casts it, so C's `?:` sees one type of
text. examples/results.k and the documents drop the `as cstr`. Details
in provisional P87.

There are 568 tests, and all pass with clang and with gcc 15.

### 106. `try`, passing an `err` up

> now add `try`, passing an `err` up

**Claude** added #76. `try r` is the `ok` value of a Result, or the
`some` of an Optional, and otherwise returns from the function with
the `err`, or `none`, passed up as it is: `let n = try parse(s)`,
`return try f(a) + try f(b)`, or `try f()` alone. It is a prefix, as
`-x` is. The function must return a Result whose `err` has the same
type, or an Optional for an Optional; `try` of a variable whose value
owns is an error, since it would move the value out. examples/results.k
now passes its error up with `try`, and the documents say so. Details
are provisional P88.

There are 575 tests, and all pass with clang and with gcc 15.

### 107. `return {0, 0}` into a Result

> now make `return {0, 0}` wrap into a `Result<point, U>`

**Claude** added #77: `return {...}` takes the function's result type,
as a declaration's `{...}` does. Of a `Result<point, U>` or a `point?`
the list is the value's initializer, wrapped; of a `point` it is the
struct's, with designators, as it is of a union, a C struct, and an
enum with values' `{.n = 0.5}`. A number's result still takes a value.
Details are provisional P89.

There are 577 tests, and all pass with clang and with gcc 15.

### 108. `if let` of the error

> now add `if let` of the error

**Claude** added #78: `if let err(e) = r { ... } else { ... }` names
the case and binds its value when that is `r`'s case, so the error is
read as the value was; `if let ok(v) = r` spells `if let v = r` out,
and `if let some(v) = x` an Optional's. Since the form names any case,
it works for every enum with values, `if let n(x) = j`, which the same
code gives. A case with no value has nothing to bind, and says so.
Details are provisional P90.

There are 581 tests, and all pass with clang and with gcc 15.

### 109. `==` on Results and Optionals

> now add `==` on `Result` and `Optional`

**Claude** added #79: `==` and `!=` on a Result, an Optional, and,
by the same derived function, any enum with values: the same case, and
equal values, a String's by its bytes and a nested variant's by its own
`==`. The other side is wrapped as where one is expected, so `x == none`,
`r == 42` and `r == err(2)` read as they sound. A value with no `==` of
its own, a struct or an Array, leaves the type without one, and the
message names the case; an owner made on the spot, `err($"x")`, is not
taken, since nothing would free it. Details are provisional P91.

There are 586 tests, and all pass with clang and with gcc 15.

### 110. Mapping on Results and Optionals

> now add mapping on `Result` and `Optional`

**Claude** added #80: `x.map(f)` and `x.map { ... }` give a `U?` or a
`Result<U, E>` of `f`'s result when the value is there, and carry the
other case over; `r.mapErr(g)` maps the err instead. `f` is a function
by name, a function value, or an anonymous function whose result
kelvinc sees, as a `let` infers, or which writes it. A variable that
owns is not mapped, since `f` would take its value: map the call, or a
copy; calls chain. Details are provisional P92.

There are 591 tests, and all pass with clang and with gcc 15.

### 111. `flatMap` on Results and Optionals

> now add `flatMap` on `Result` and `Optional`

**Claude** added #81: `x.flatMap(f)` takes an `f` that gives the
`U?` or the `Result<U, E>` itself, with the same `E`, and is that
when the value is there, else `none` or the `err` carried over. It
reads as `map` does, by name or as a trailing function, and chains
with it. On the way, `{ positive($0) }` was refused: a one-expression
body that gives an owner was judged as dropping it before it was known
to be the result. The check now waits for the body's end, so such a
function, written or trailing, returns its owner. Details are
provisional P93.

There are 597 tests, and all pass with clang and with gcc 15.

### 112. A brainfuck interpreter and compiler

> add `bfi.k` and `bfc.k` that are brainfuck interpreter and compiler,
> respectively, to `examples/`. See https://github.com/dankogai/swift-bf
> for brainfuck syntax with `!` extension.

**Claude** added [examples/bfi.k](examples/bfi.k) and
[examples/bfc.k](examples/bfc.k), after swift-bf: the tape is 65536
cells that wrap, as the pointer does; the first `!` ends the program
and starts its input, so a source carries its own data, and `,` then
reads it; without one, `,` reads stdin. The interpreter halts at the
end of input, the compiled program stores 0, as swift-bf does. Both
take the program from the file named on the command line, and report
an unmatched bracket with its offset; run with no file, the
interpreter runs Hello World and the echo program with embedded input,
and the compiler prints the echo program as Kelvin source, which
kelvinc compiles. The interpreter is a struct that owns a `Bytes` of
commands and an `Array` of jumps, given as a `Result`, read with
`if let err(why)` and run through a borrow; the compiler slices the
input off after the `!` and writes it as a string literal with C's
escapes.

There are 599 tests, and all pass with clang and with gcc 15.

### 113. `IO`: stdio as an owner

> Let us add Kelvinized version of stdio to the prelude.
> `let f = try IO(path, mode)` where path is either cstr or String;
> `f.bytes` returns the entire content of the path in `Bytes` or err if
> it fails; `f.string` returns the UTF-8 string or fails if it was not a
> valid UTF-8; `f.read(nbytes)` is an iterator used like `for bytes in
> f.read(nbytes) {}`; `f.lines` is also an iterator; `IO.stdin, IO.stdout,
> IO.stderr` are predefined; `IO` instances are dynamic objects which are
> like `String`, `Array`, and `Dictionary`, auto-`.close` when the scope
> ends.

**Claude** added #82, in [documents/io.md](documents/io.md). `IO(path,
mode)` is a `Result<IO, i32>`, the IO or `errno`, of a text, a String
or a Bytes path; `f.bytes` and `f.string` are the rest of the file as a
Result, `EILSEQ` for text that is not UTF-8; `for chunk in f.read(n)`
and `for line in f.lines` walk it, the loop owning the Bytes or String
it holds; `f.write(x)` takes text, a borrow or an owner an expression
gives, with `f.flush()` and `f.close()` beside it; `IO.stdin`,
`IO.stdout` and `IO.stderr` are never closed and work where they
stand. An IO closes when its block ends, moves and borrows as the other
owners do, and is not copied. The prelude holds the `FILE *` as a
`void *`, so that it needs no `<stdio.h>`, whose names a program may
declare itself. CI's Linux jobs then found a double `fclose`: the
test closed an IO through the copy that `if let ok(f)` binds, and the
Result closed its own at the block's end, which glibc reports and
macOS tolerated. `close` now needs the var that owns the IO, as
`append` needs a String's: `r.ok.close()`. Details are provisional
P94.

There are 607 tests, and all pass with clang and with gcc 15.

### 114. `print` and `println` on an IO

> now add `print` and `println` to `IO`

**Claude** added #83: `f.print(a, b, ...)` and `f.println(...)` show
values to an IO as `print` and `println` show them to stdout, by each
value's type, up to 16 at a time, `IO.stderr.println("warning: ", n)`.
The runtime's printers now take a FILE, with `print` the stdout case.
Details are provisional P95.

There are 610 tests, and all pass with clang and with gcc 15.

### 115. An IO's position

> now add `.eof` and seeking to `IO`

**Claude** added #84: `f.eof`, true once a read has met the end, as
C's `feof` is; `f.position` and `f.count`, the offset and the length
in bytes, -1 where the stream has none; `f.seek(n)` from the start, a
`bool`; and `f.rewind()`. A relative or end-relative position is
written with `position` and `count`, since C's `SEEK_CUR` and
`SEEK_END` are stdio's names. Details are provisional P96.

There are 612 tests, and all pass with clang and with gcc 15.

### 116. A pasted program, and reading one at a time

> now add reading a single byte and a number to `IO`. but before that,
> make the following work: [a program that opens `argv[1]`, switches on
> the Result, reads `r.ok.string`, switches on that, and prints
> `strerror(r.err)`]

**Claude** found the program short of a `)` on its `strerror` line and
of the `}` that closes its `case ok:` block, so that its `case err:`
lay inside that block, which kelvinc had said; with the two typos
fixed it compiled and ran as written, `strerror` included, since the
prelude has `<string.h>`. The user: "I did not mean to fix kelvin. I
meant to fix the code pasted." Then #85: `f.byte` is the next byte, a
`u8?`; `f.i64` and `f.f64` the next integer or float as `scanf` reads
them, an `i64?` or an `f64?`; `none` at the end, or where no number is
there. Details are provisional P97.

There are 614 tests, and all pass with clang and with gcc 15.

### 117. An IO of a file descriptor

> now add opening with a file descriptor to `IO`

**Claude** added #86: `IO(fd, mode)`, with a number first, opens a
file descriptor as `fdopen` does, and owns it, so its block closes the
descriptor too; `f.fd` beside it is an IO's descriptor, an `i32`, for
C's own calls, -1 once closed. A bad descriptor is an err, `EBADF`.
Details are provisional P98.

There are 616 tests, and all pass with clang and with gcc 15.

### 118. A process and a pipe as IOs

> now add opening a pipe or a process to `IO`

**Claude** added #87: `IO.popen(command, mode)` runs a shell command
as `popen` does, its output read or its input written through the IO,
and its block, or `close()`, waits for it, after which `f.status` is
its exit code; `IO.pipe()` gives a pipe's two ends as
`{reader: IO, writer: IO}` in a Result, each owning its descriptor.
Details are provisional P99.

There are 619 tests, and all pass with clang and with gcc 15.

### 119. No numbers from `scanf`

> What do you mean by "now add reading a number in a base to `IO`"?
> [...] Instead of adding reading a number in a base to `IO`, let us
> get rid of them. `scanf()` is evil and error-prone and you can always
> read line or whole file string and apply i64(line) on it.

**Claude** removed `f.i64` and `f.f64`, #85's readers through
`fscanf`, as #88, keeping `f.byte`; a number is read from the text,
`i64(line)` of a line or `i64(try f.string)` of the whole, and `f.i64`
says so. For `i64(line)` to read as written, the converters now take
a String or a Bytes in a variable, through its text, as they take a
`cstr`. Details are provisional P100.

There are 619 tests, and all pass with clang and with gcc 15.

### 120. Where each thing lives

> state documents/T.md if the T is in core, prelude or explicitly
> loaded via `#import`.

**Claude** put a line under the title of every document in
documents/: whether what it covers is the core (kelvinc alone, the C
being C's own, nothing linked), the prelude (`kelvin_prelude.h` and
`libkelvin`, which every program gets without an import), or loaded
explicitly (`#import <complex.k>`, `#import <x.h> as C`), with the
mixed cases named, as a fixed array's being the core and `Array<T>`
the prelude's. versusC.md sums it up in a table.

There are 619 tests, and all pass with clang and with gcc 15.

### 121. A process's signal

> now add a process's signal to `IO`

**Claude** added #89: `f.signal` is the signal that ended a process,
once closed, 0 when it exited on its own, -1 before or for an IO that
is no process; `status` is then -1 for a process a signal ended.
Details are provisional P101.

There are 620 tests, and all pass with clang and with gcc 15.

### 122. A program without the shell

> now add running a process without the shell to `IO`

**Claude** added #90: `IO.exec(args, mode)` runs a program with its
arguments as a list, `["ls", "-l"]`, or an Array of cstr or of String
in a variable, found on the PATH, its output read or its input written
through a pipe; a program not found is an err, `ENOENT`, since the
child reports what exec failed with through a pipe closed on exec;
closed, it is waited for, with `status` and `signal`. Details are
provisional P102.

There are 622 tests, and all pass with clang and with gcc 15.

### 123. `strings.md`

> rename `documents/cstring.md` to `documents/strings.md`. And "A C
> string is a pointer to bytes that end at a NUL. Kelvin has no string
> type yet [...]" is no longer correct now that we have `String` and
> `Bytes`. Rewrite it

**Claude** renamed the document and rewrote its opening: text in
Kelvin is C's, the four kinds kept apart, or Kelvin's own, `String`
and `Bytes` on the heap with `uchr` a codepoint, with `toString()` and
`fmt()` still shelved since `.cstr` and the templates do their work;
its closing paragraph no longer promises slicing, which #68 gave. The
links in the other documents and the README follow the new name.

There are 622 tests, and all pass with clang and with gcc 15.

### 124. A signal to a process

> now add sending a signal to a process to `IO`

**Claude** added #91: `f.kill(signal)` sends a signal to a process
`IO.exec` started, `true` when sent, and `f.pid` is its process id;
a `popen`'s child has no pid C gives, so there `kill` is `false` and
`pid` -1, as for any other IO. Details are provisional P103.

There are 623 tests, and all pass with clang and with gcc 15.

### 125. A process's directory and environment

> now add a process's environment and working directory to `IO`

**Claude** added #92: `IO.exec(args, mode, dir)` runs the program in
a directory, `""` for the current one, and `IO.exec(args, mode, dir,
env)` with `"NAME=value"` entries, a list or an Array of cstr or of
String, added to the parent's environment; a directory that cannot be
entered is an err, as a missing program is. CI's Linux clang then
refused `putenv`, which glibc hides under `_POSIX_C_SOURCE` alone, so
the runtime asks for X/Open 700 instead. Details are provisional
P104.

There are 625 tests, and all pass with clang and with gcc 15.

### 126. An environment from nothing

> now add an environment made from nothing to `IO.exec`

**Claude** added #93: `IO.exec(args, mode, dir, env, fresh)`, with
`fresh` true, gives the program an environment of the entries alone,
`[]` an empty one; the program is then found on that environment's
PATH, or the system's default, so a fresh environment names the
program by its path or sets PATH. Details are provisional P105.

There are 627 tests, and all pass with clang and with gcc 15.

### 127. `OS` and `SYS`

> Add `OS` and `SYS` to prelude. A la Python but as a part of prelude
> you don't have to `#import`.

**Claude** added #94, in [documents/os.md](documents/os.md): `SYS`
is the program, with `argv` as an `Array<cstr>`, `exit(code)` and
`platform`; `OS` the system around it, with `cwd`, `chdir`, `env`,
`setenv`, `unsetenv`, `exists`, `isdir`, `isfile`, `remove`,
`rename`, `mkdir`, `rmdir`, `listdir`, `system` and `pid`, each C's
call underneath and giving what C gives, Kelvinized: a `bool`, 0 or
`errno`, an Optional, or a Result. kelvinc's C `main` now always takes
`argc` and `argv`, for `SYS.argv`. Details are provisional P106.

There are 629 tests, and all pass with clang and with gcc 15.

### 128. More of `OS`

> So many methods are missing!! Where is `.lstat(path)`, for instance?

**Claude** added #95, the rest of what C gives plainly: `OS.stat` and
`OS.lstat` as a Result of a struct of C's fields, `islink`,
`symlink`, `readlink`, `link`, `unlink`, `chmod`, `truncate`,
`makedirs`, `realpath`, the path helpers `basename`, `dirname` and
`join`, the ids `ppid`, `uid` and `gid`, `user` and `host`, `umask`
and `kill`, `time` and `sleep`, and `tmpdir`. Walking a tree,
globbing and temporary files made for you are still to come. Details
are provisional P107.

There are 631 tests, and all pass with clang and with gcc 15.

### 129. Walking and globbing

> now add walking a tree and globbing to `OS`

**Claude** added #96: `OS.walk(path)` is every path under a
directory as one Array of Strings, each level sorted, depth first,
links not followed; `OS.glob(pattern)` the paths a shell pattern
matches, sorted, none where none match; each a
`Result<Array<String>, i32>` as `listdir` is. Details are
provisional P108.

There are 632 tests, and all pass with clang and with gcc 15.

### 130. Temporary files

> now add temporary files made for you to `OS`

**Claude** added #97: `OS.mkstemp(prefix)` makes a temporary file and
opens it, an IO with its path in a struct the Result owns;
`OS.mkdtemp(prefix)` a temporary directory, its path; both in
`OS.tmpdir` unless the prefix names a place. Details are provisional
P109.

There are 633 tests, and all pass with clang and with gcc 15.

### 131. A file's times

> now add setting a file's times to `OS`

**Claude** added #98: `OS.utime(path, atime, mtime)` sets a file's
times in seconds since the epoch, as `stat` gives them, and
`OS.touch(path)` sets both to now, making the file when it is
missing. Details are provisional P110.

There are 634 tests, and all pass with clang and with gcc 15.

### 132. A file's owner

> now add a file's owner to `OS`

**Claude** added #99: `OS.chown(path, uid, gid)` and `OS.lchown` set
a file's owner, and a link's own, -1 leaving an id as it is;
`OS.username(uid)` and `OS.groupname(gid)` give the names of the ids
`stat` gives, each a `String?`, as `OS.user` now is too: CI's Linux
read the name for uid 0 as the runner's, since C keeps the name in
storage the next lookup overwrites, so the names are copied out.
That made `OS.user.is(some)` leak a String, as `.is` of any owning
value an expression gives did: `.is` and `.case` of one now say to
bind it first. Details are provisional P111.

There are 636 tests, and all pass with clang and with gcc 15.

### 133. A signal to a `popen`'s process

> now add setting the signal of `IO.popen`'s pid

**Claude** added #100: `IO.popen` now runs `/bin/sh -c command`
through the same fork and exec as `IO.exec`, so its process has a pid
Kelvin knows, and `f.kill(signal)` and `f.pid` work on it; C's
`popen`, which keeps its child's pid to itself, is no longer used.
Details are provisional P112.

There are 636 tests, and all pass with clang and with gcc 15.

### 134. An IO's path, and the OS's work on it

> Before adding what Python's `os` has beyond these to `OS`, Adopt
> some of those in `OS` to `IO`, especially those related to directory
> manipulations and file permissions: `f = try IO("./foo"); f.abspath`
> that returns an absolute path. `f.path` simply returns `"./foo"`;
> `d = try IO("."); for item in listdir {...}`; `f.stat` that returns
> `OS.stat(f.path)`; and the list goes on...

**Claude** added #101: an IO keeps the path it was opened with, and
does `OS`'s work on it from itself: `f.path`, `f.abspath`,
`f.basename`, `f.dirname`, `f.join(name)`; `f.stat` of the open file
itself and `f.lstat`; `f.isdir`, `f.isfile`, `f.islink`, `f.exists`;
`f.listdir`, `f.walk`, `f.glob(pattern)`; `f.chmod`, `f.chown` and
`f.truncate` on the open file; `f.remove()`, `f.rename(to)`, after
which the path follows, `f.utime` and `f.touch()`. `IO(path)` alone
opens for reading, a directory too. Details are provisional P113.

There are 638 tests, and all pass with clang and with gcc 15.

### 135. What each member takes and gives

> would you explain more about methods and function in io.md and
> os.md, especially the ones like `stat` returning an anonymous
> struct. What is in there? we need member types as well as member
> names. If table is too tight, give a section explaining what they
> are.

**Claude** gave each document a section "What each member takes and
gives", every member written as it would be declared, with its
argument and result types in Kelvin's spelling and a word on what
it does, and a section on the structs: os.md's "The `Stat` struct",
each of its thirteen members with its type and what it is, and
io.md's "The structs an IO gives", `{reader: IO, writer: IO}` and
`{io: IO, path: String}`. No code changed.

There are 638 tests, and all pass with clang and with gcc 15.

### 136. The rest of Python's `os`

> now add what Python's `os` has beyond these to `OS`

**Claude** added #102, what C gives plainly: `strerror`, `environ`,
the effective ids and `groups`, `uname`, `readable`, `writable` and
`executable`, `isabs`, `splitext`, `normpath`, `relpath`,
`expanduser`, `samefile`, `mkfifo`, `sync`, `cpus`, `loadavg`,
`urandom`, `isatty`, `terminalsize`, `diskusage`, and the constants
`sep`, `linesep`, `devnull` and `name`. The structs they give are
spelled as themselves, now all made by one maker from the spelling.
CI's Linux clang then found `getloadavg` undeclared, a BSD extension
glibc keeps for `_DEFAULT_SOURCE`, which the runtime now defines
beside `_XOPEN_SOURCE`. Details are provisional P114.

There are 639 tests, and all pass with clang and with gcc 15.

### 137. `isatty`, and `strerror` from `IO`

> now add `IO.isatty` and `IO.strerror` for its err to `IO`

**Claude** added #103: `f.isatty`, whether an IO's descriptor is a
terminal, and `IO.strerror(code)`, the message for an err as
`OS.strerror` gives it, reachable from `IO`. Details are provisional
P115.

There are 640 tests, and all pass with clang and with gcc 15.

### 138. An open file's attributes straight

> if `let res = IO(path, r)` is `ok(IO)`, `path` is guaranteed to exist
> as of invocation. if so, why `res.ok.lstat` needs to be
> `Result<Stat, i32>`? You should be able to go straight to `Stat`.
> Skipping unwrapping `Result`.

**Claude** agreed for `f.stat`, which goes through the descriptor, and
noted that `f.lstat` goes by the path, which can be gone. The user
decided for the suite:

> now make `f.stat` give a `Stat` straight. Other file-attribute
> related methods follow the suite. Note `OS.lstat(path)` is a
> completely different story because It needs to heck the
> accessibility of `path` for each invocation that may fail.

**Claude** added #104: `f.stat` and `f.lstat` give a `Stat`, `f.abspath`
a `String`, with no Result around them, and `f.isdir` and `f.isfile`
read the open file. Where the path is gone, `f.lstat` is the open
file's and `f.abspath` is `""`. `OS.stat(path)` and the rest of `OS`
stay Results. On the way, `f.stat.size` turned out to be sizeof: a
property that gives a struct now classes as that struct, so its fields
win. Details are provisional P116.

There are 642 tests, and all pass with clang and with gcc 15.

### 139. `f.abspath` through the descriptor

> now add `f.abspath` via the descriptor when the path is gone

**Claude** added #105: where realpath of the path fails, or the IO has
no path, `f.abspath` asks the system what the open descriptor is
named, macOS's `F_GETPATH` or Linux's `/proc/self/fd`, so a file
renamed behind the IO answers by its new name and a removed one by the
name it had; a pipe, a closed IO, or another system still gives `""`.
Details are provisional P117.

There are 643 tests, and all pass with clang and with gcc 15.

### 140. The rest of an IO's attributes straight

> now add `f.stat` straight to the rest of `IO`'s attributes

**Claude** added #106: `f.listdir`, `f.walk` and `f.glob(pattern)`
give an `Array<String>` with no Result, since the directory was there
to open; of the path while it is there, else of the descriptor's name,
so a directory renamed behind the IO still answers. An IO that is no
readable directory gives none. The operations, `chmod` and its kin,
stay 0 or `errno`, and `f.bytes` and `f.string` stay Results, as
contents with real errors. Details are provisional P118.

There are 644 tests, and all pass with clang and with gcc 15.

### 141. `f.bytes` and `f.string` straight

> now add `f.bytes` and `f.string` straight too

**Claude** added #107: `f.bytes` is the rest of the file as a `Bytes`
and `f.string` as a `String`, with no Result, since the file was there
to open; a stream that stops answering gives what was read before.
Text that is not UTF-8 ends `f.string` with a message, as a line of
`f.lines` already did, so a program that may meet such text reads
`f.bytes` and asks `b.isUTF8`. Details are provisional P119.

There are 645 tests, and all pass with clang and with gcc 15.

### 142. The operations straight

> now add `f.chmod` and the other operations straight too

**Claude** added #108: `f.chmod`, `f.chown`, `f.truncate`, `f.utime`,
`f.touch`, `f.remove` and `f.rename` give a `bool`, true when done,
and no `errno`, as `seek` and `kill` already did; the first five
through the descriptor, so they work on a file renamed or removed
behind the IO, the last two by the path while it is there, else by the
descriptor's name. `OS`'s of the same path still tell why. Details are
provisional P120.

There are 646 tests, and all pass with clang and with gcc 15.

### 143. `IO(path, mode)` straight

> now add `IO(path, mode)` straight too

**Claude** noted that the open is the call that checks a path, so with
no Result something else must carry the errno, and asked which shape:
an IO holding its error, ending the program, or keeping the Result.
The user chose the first. #109: `IO(path, mode)` and `IO(fd, mode)`
give the IO; `f.error` is the open's `errno`, 0 when it opened, and
such an IO is as a closed one, with the reason in the message should
it be read by `f.lines` or written to. `IO.popen`, `IO.exec` and
`IO.pipe()` stay Results until asked. Details are provisional P121.

There are 648 tests, and all pass with clang and with gcc 15.

### 144. The processes and the pipe straight

> now add `IO.popen`, `IO.exec` and `IO.pipe()` straight too

**Claude** added #110: `IO.popen` and `IO.exec` give the IO, with
`f.error` what the exec failed with, `ENOENT` for a program not found,
and `IO.pipe()` the pair `{reader: IO, writer: IO}`, both ends carrying
the error of a pipe that could not be made. Nothing of `IO` is a
Result any more. Details are provisional P122.

There are 649 tests, and all pass with clang and with gcc 15.

### 145. A JSON module

> Add JSON handler as an importable module as `#import <JSON>`.
>
> * define `union JSON` like `enum SION` in https://github.com/dankogai/swift-sion
>    * bool, f64, String, Array<JSON> or Dictionary<String, JSON>.  is nullptr fit for null of JSON?
> * `JSON.parse(str)` takes `cstr` or `String` and return `JSON`.
> * `JSON.stringifiy(json, replacer, space)` like JS.  space is either cstr or String.

**Claude** found the pieces mostly there: an enum with values holds an
Array and a Dictionary of itself, and `null` is a case carrying
nothing, not `nullptr`, a pointer. Two things the core lacked: a
function called by a type's name, and `#import <JSON>` without `.k`.
Asked, the user chose Swift's spelling for the first, `static let
T.name(...)`, and a case `error: String` for a text that is not JSON.
So three changes: #111 functions of a type, #112 bare module names,
and #113 `modules/JSON.k`, with `JSON.parse` of a cstr or a borrowed
String and `JSON.stringify(&j, replacer, space)` as JS has them,
numbers written as JS writes them. Details are provisional P123, P124
and P125.

There are 659 tests, and all pass with clang and with gcc 15.

### 146. The `?` before `in`, and `"""`

> now fix the wart: `):JSON? in` in an anonymous function. Also add the
> multi-line, non-interpolating `"""` a la python, et al. That may quote
> JSON-like text more easily.

**Claude** fixed #114: the signature lookahead stopped at the `?` of a
base type and took `in` for an operand, and a one-expression body of a
`T?` result was not wrapped as `return` wraps it; both now are, so
`{ (key:cstr, v:const JSON^):JSON? in none }` is a replacer. And added
#115: `"""text"""`, a string literal over lines with the text as it
is, no escapes and no `${...}`, so `JSON.parse("""{"a": "b\n"}""")`
reads JSON as written. Details are provisional P126 and P127.

There are 662 tests, and all pass with clang and with gcc 15.

### 147. `none` as an arm of `?:`

> now fix the wart: `none` as an arm of `?:`

**Claude** fixed #116: the wrapping a `T?` or a Result gets from a
`return`, a declaration or a one-expression body now goes into each
arm of a `?:`, an arm beside one that is a `T?` is wrapped to it, and
an else arm such as `Optional<i64>(n)` is a value, not an annotation.
Details are provisional P128.

There are 663 tests, and all pass with clang and with gcc 15.

### 148. `j["key"]` and `j[i]`

> now add `j["key"]` and `j[i]` straight on a JSON

**Claude** added #117 as a rule of enums with values: `v[k]` goes
through the case that is a Dictionary when `k` is text, and the Array
case when it is an integer, so `j["tags"][1].number` reads a path and
`j["n"] = JSON.number(4.0)` writes one, checked as the case and the
index are. On the way, assigning into an element of an Array of such
an enum turned out to want a helper that was never written; it is
now. Details are provisional P129.

There are 666 tests, and all pass with clang and with gcc 15.

### 149. Quoting text, in one place

> `"""` is not limited to JSON so the snippet in `json.md`. rewrite
> `grammar.md` and other document on how to quote strings including the
> explanation on ``.

**Claude** wrote a section "Quoting text" into grammar.md with every
spelling side by side: `"..."`, `'c'`, the template with its own
escapes, `"""..."""` as written, and the `$` forms and `Bytes(...)`
that make a String or a Bytes of any of them, with a table of what
each gives, whether it spans lines, its escapes and whether values go
in. strings.md, printing.md, json.md and the README now point there
instead of explaining a spelling each. No code changed.

There are 666 tests, and all pass with clang and with gcc 15.

### 150. `"""` on its own lines, and a longer delimiter

> now add a longer delimiter for `"""` inside `"""`. also use `"""` /
> multi-line quotation / `"""` instead of `"""multi-line quotation"""`
> to emphasize it is truly multi-line through entire documents

**Claude** added #118: the delimiter is a run of three or more quotes,
closed by a run as long, so `""""` holds a `"""`; and the form on its
own lines, with Swift's rules: the line breaks beside the delimiters
are not text, and the closing delimiter's indentation comes off each
line. The documents write every `"""` that way now; the inline form
stays. Details are provisional P130.

There are 667 tests, and all pass with clang and with gcc 15.

### 151. Documents easier on the eyes

> When you document things, you are squeezing too many sentences in a
> paragraph. look at `io.md`'s `making one`: AIs may have no problem but
> it makes the eyes of NIs sore. Don't be afraid to multi-indent like
> source codes. Make all documents eyeball-easier

**Claude** restructured every document and the README: a dense bullet
is now a lead line of one or two sentences with nested sub-bullets,
one idea each, indented like code. Nothing was added, dropped or
reworded beyond the splitting; every code block, table, heading,
reference and link is as it was, which a checker compared against the
committed files. No code changed.

There are 667 tests, and all pass with clang and with gcc 15.

### 152. A `switch` that binds the case's value

> now add a `switch` that binds the case's value

**Claude** added #119: `case n(x):` runs its body with `x` bound to the
case's value, as `if let n(x) = e` binds it, a let the enum still
owns; a binding case stands alone, a case with no value binds nothing,
and a value no place holds is read once. Details are provisional P131.

There are 671 tests, and all pass with clang and with gcc 15.

### 153. An enum with values and no tag, at the top level

> now add an anonymous `enum` with values at the top level

**Claude** found a nameless enum already went where a type goes, so
the one thing left was the top-level declaration itself, and asked
what it should mean. The user chose C's reading: #120, its cases are
words of the program, `red` a value and `rgb({1, 2, 3})` a maker of
the type spelled `enum{red, rgb: ...}`, with the words of Result and
Optional, a function's name and an enumerator's refused as case names.
Details are provisional P132.

There are 675 tests, and all pass with clang and with gcc 15.

### 154. Methods and operators on a type with no tag

> now add methods and operators on an enum with no tag

**Claude** asked how a method should name a receiver with no name, and
the user chose its spelling: #121, `let enum{nothing, just: i64}.orZero()`,
which serves a struct or a union with no tag the same way, and
operators that take it by its spelling. On the way, operators the
program defined for any enum with values turned out never to be
reached, since the check of `==` came first; they are now. Details are
provisional P133.

There are 678 tests, and all pass with clang and with gcc 15.

### 155. print shows a struct as its text

> `println(p)` of a struct, or of an enum with values, is not caught by
> kelvinc, and fails in C

**Claude** asked whether kelvinc should refuse such an argument with a
hint to write `p.cstr`, or show its `.cstr` text, and the user chose
the text: #122, `print`, `println`, `f.print` and `f.println` show a
struct, a union or an enum with values that kelvinc sees as `${p}`
does, the derived text or the type's own `T.cstr()`. Details are
provisional P134.

There are 679 tests, and all pass with clang and with gcc 15.

### 156. A template of a struct's .cstr

> `${p.cstr}` segfaults kelvinc

**Claude** found that a template showed a struct by its `.cstr`, and
took `p.cstr`, which keeps the struct's type to size its text, for the
struct itself, so wrapped it again as `p.cstr.cstr`. The user agreed to
ask the value's type instead, as print does since #122: a `.cstr` is
text, and a property that gives a struct, `f.stat` (#104), is still
one. A bug fix, with no change to the language.

There are 680 tests, and all pass with clang and with gcc 15.

### 157. Values whole, and `.pretty`

> now give println of a struct its .cstr text and Array's elements in
> `[]` and `Dictionary` key-value pairs in `{}`. And add `print` and
> `println` and option to pretty-print values in `()`, `[]`, and `{}`,
> indented and line-fed.

**Claude** found the struct part done by #122 in another session, and
asked two things: how the pretty option is spelled, and how text shows
inside a value. The user chose a property, `x.pretty`, and quoted text.
#123: kelvinc writes a printer for each type, so `print` shows a
struct, an enum with values, an Optional, a Result, an Array, a
Dictionary and a Set whole, with Strings inside quoted, also in
`.cstr`. #124: `x.pretty`, the same indented, printed where `print`
shows it and a String elsewhere. Details are provisional P135 and P136.

There are 682 tests, and all pass with clang and with gcc 15.

### 158. `${xs}` in a template

> now add `${xs}` of an Array in a template

**Claude** added #125: a template shows an Array, and a Dictionary and
a Set by the same printer, as `print` does since #123; cut to the
template's room as a long string value is, and whole in `` $`...` ``.
Details are provisional P137.

There are 683 tests, and all pass with clang and with gcc 15.

### 159. `${v.pretty}` in a template

> now add `${d}.pretty` in a template

**Claude** read it as `${d.pretty}`, the indented text inside a
template, and added #126: it takes kelvinc's printer at the indented
level, cut to a template's room as a long string value is, and whole
in `` $`...` ``. Before, it went through as a String that nothing
freed, or was refused in `` $`...` ``. Details are provisional P138.

There are 684 tests, and all pass with clang and with gcc 15.

### 160. A file test for `f.println` of `.pretty`

> add a file-based test for f.println of .pretty

**Claude** added tests/run/io_pretty.k: `f.println` and `f.print` of
`.pretty`, and of whole values, write to a file, which is read back and
removed. It worked already since #124; the test pins the path through a
file, where the earlier one went through `IO.stdout` only. No code
changed.

There are 685 tests, and all pass with clang and with gcc 15.

### 161. `.pretty(n)`

> now add `.pretty` with a custom indent width

**Claude** asked how the width is given, and the user chose
`x.pretty(n)`, a number of spaces. #127: from 0 to 10, as JS clamps
`JSON.stringify`'s space; 0 still breaks the lines; `x.pretty` stays
two; it works wherever `.pretty` does. Details are provisional P139.

There are 689 tests, and all pass with clang and with gcc 15.

### 162. `bool` and floats out of integers.md

> documents/integers.md is misleading as it also explains bool and
> floating points. Split them to bool.md and floatingpoint.md

**Claude** split it: integers.md keeps the integer types, their
literals, and the conversions and numbers from text, which serve every
number; floatingpoint.md has `f32` and `f64`, their literals, reading,
printing, text and C's complex types; bool.md has `bool`, where one
comes from, conditions and converting. What the two new documents say
about printing, text and conditions was gathered from printing.md,
properties.md and flow-controls.md, with links back; the links to
integers.md elsewhere now point to the right document. No code changed.

There are 689 tests, and all pass with clang and with gcc 15.

### 163. `+=` on an enum with values, and a number as `JSON.stringify`'s space

> now add `+=` on an enum with values via its operator. also add
> `.pretty(n)` to `JSON.stringify`'s space

**Claude** found `+=` already went through the program's operator, but
gave the wrong value for an enum that owns: `x = v` freed `x` before it
read `v`. #128 assigns through the type's assign helper, which takes
the value first, which also fixes `x = x + y` and `x = f(x)`. #129, read
as a number for the space: `JSON.stringify(&j, 4)`, that many spaces a
level, 0 to 10, as JS's and as `v.pretty(n)`. Details are provisional
P140 and P141.

There are 691 tests, and all pass with clang and with gcc 15.

### 164. `extend T { }` and attributes

> add `extend T {}` that does `extension T {}` in Swift where `var` or
> `let` are instance attributes and `static var` or `static let` are
> type attributes. Also add document about it as `attributes.md`.
> Document both `let T.f {}` and `extend { let f {} }`. If you like,
> rewrite existing codes in the repo with `extend T {}`.

> sorry. we already have properties.md. aggregate attributes.md to that

**Claude** asked which members to support and what a `var` instance
attribute means; the user chose all three kinds and a computed
attribute with a setter. #130 `extend T { }` groups a type's members;
#131 `let T.x:R { }` is a computed attribute read as `v.x`; #132
`var T.x:R { get { } set(v) { } }` adds a setter, `v.x = y`; #133
`static let` and `static var` are type attributes, `T.x`. Each has a
form alone and one in extend, both in properties.md. Testing a setter
found that `p.name = v` of an owner never freed the old value; #134
fixes that for every program. examples/shapes.k, linkedlist.k and the
JSON module now use `extend`. Details are provisional P142 to P146.

There are 703 tests, and all pass with clang and with gcc 15.

### 165. Operators in `extend`

> now add operators inside `extend T {}` as `static let +`

**Claude** added #135: `static let +(a:T, b:T):T { }` in `extend T { }`,
as Swift's `static func +`, the same operator as the top level's
`let +`, taking a `T` as one of its values; a plain `let +` there is an
error that says to write `static`. Details are provisional P147.

There are 706 tests, and all pass with clang and with gcc 15.

### 166. Subscripts in `extend`

> now add subscripts inside `extend T {}`

**Claude** asked for the spelling, and the user chose `let [](i:i64):R`
and `var [](...)`. #136 adds them: `let [](i:I):R { }` is read as
`v[i]`, and `var [](i:I):R { get { } set(v) { } }` is also written as
`v[i] = y` and `v[i] += y` on the var that holds `v`. Several indices
read `v[r, c]`, subscripts overload by the indices' count and types,
and alone they are `let T[](...)` and `var T[](...)`. An enum with
values that has one is indexed through it, not through its cases
(#117). Both forms are in properties.md. Details are provisional P148.

There are 718 tests, and all pass with clang and with gcc 15.

### 167. A getter does not change `self`

> now make a let attribute's getter reject changing self

**Claude** added #137: in a `let` attribute and in a `var` attribute's
`get { }`, `self` is a `let`, so `self.n += 1` or `self = v` is an error
that names the setter, as a subscript's getter already was (#136).
`self` is `const` in C there, as any `let` is, so `&self` is a
`const T^`. A setter and a method are unchanged. Details are
provisional P149.

There are 721 tests, and all pass with clang and with gcc 15.

### 168. A method does not change `self`, and `.x` is `self.x`

> now make a method reject changing self.  Also make `.attr` mean
> `self.attr` in the method definitions.

**Claude** added #138: a method's `self` is a `let`, as a getter's is
(#137), so changing it is an error, and it is `const` in C. This ends
#27's mutable copy; three programs that moved a copy now write
`var p = self`. #139 reads `.x` as `self.x` in every body with `self`:
methods, attributes, setters and subscripts. In an initializer,
`.x = v` is still a designator. A `.member` on a new line still goes on
with the expression (#35), except a line that sets a member, `.n = v`,
which starts a statement where there is `self`. Details are
provisional P150 and P151.

There are 729 tests, and all pass with clang and with gcc 15.

### 169. `Self`, and `:()` for no result

> edit documents reflecting the changes above. Also note inside
> `extend T`, `T` can also be referred as `Self` like swift. That goes
> to `let T.meth(){...}`. in `...` `Self` refers to `T`. Just to be more
> explicit functions without return values (C's void f()...), you can
> optionally add `:()`

**Claude** rewrote the examples of properties.md with `.x` and `Self`,
and added #140 and #141. `Self` is the receiver's type inside
`extend T { }` and in every member of `T` written alone, as Swift's:
where a type goes, `let moved(dx:i64):Self`, `var p:Self = self`, and
where the type's name goes, `Self.of(1, 2)`, `Self.unit`, `Self(v)`; a
type with no tag has no name, so its `Self` is a type only. `:()`
after the parameters says a function gives nothing, on a function, a
prototype, a method, an anonymous function and in a function type.
Details are provisional P152 and P153.

There are 734 tests, and all pass with clang and with gcc 15.

### 170. The examples and modules with `.x` and `Self`

> now rewrite the examples and modules with `.attr` and `Self`

**Claude** rewrote examples/shapes.k and examples/linkedlist.k with
`.x` for `self.x` (#139) and `Self` for the receiver's type (#140), and
modules/JSON.k's functions of the type with `Self` for `JSON`, as
`static let parse(text:cstr):Self` and `j:const Self^`. modules/complex.k
has plain functions and operators, with no `self`, so it is as it was.
The outputs are unchanged.

There are 734 tests, and all pass with clang and with gcc 15.

### 171. `:()` in the examples and modules

> now add `:()` to the examples and modules too

**Claude** wrote `:()` (#141) on every function of the examples and
modules that gives nothing: fifteen of them, in bfc.k, bfi.k,
complex.k, linkedlist.k, sort.k, strings.k and modules/JSON.k. The
generated C and the outputs are unchanged.

There are 734 tests, and all pass with clang and with gcc 15.

### 172. `:()` in the documents

> now add `:()` to the documents too. making sure it is optional.

**Claude** wrote `:()` (#141) beside the documents' functions that give
nothing, keeping one of each pair without it, `greet` and `shout` in
functions.md, `let f()` and `let f():()` in versusC.md and the README,
and `t:()` and `u:():()` for a function type, and said in functions.md
and grammar.md that the two spellings mean the same.

There are 734 tests, and all pass with clang and with gcc 15.

### 173. A line that starts with `.x`

> now make `.x` work in the top-level anonymous enum's methods

**Claude** found every form working but one, in any type's method:
`.is(just)` at the start of a line after another statement, which #35
read as going on with the line before, `10.is(just)`. Asked which rule
to take, the user chose #142: where there is `self`, a line that starts
with `.x` is `self.x`, a statement of its own; a chain over several
lines goes inside parentheses there, and #35 holds where there is no
`self`. Details are provisional P154.

There are 734 tests, and all pass with clang and with gcc 15.

### 174. The tests with `.x` and `Self`

> now rewrite the tests with `.x` and `Self`

**Claude** rewrote 23 of the run tests with `.x` for `self.x` (#139)
and `Self` for the receiver's type (#140) in their methods, attributes,
subscripts, operators and functions of the type, keeping the five
tests that are about `self` and `Self` themselves, and the error tests,
as they were. The generated C and the outputs are unchanged.

There are 734 tests, and all pass with clang and with gcc 15.

### 175. The documents' examples with `.x` and `Self`

> now rewrite the documents' examples with `.x` and `Self`

**Claude** rewrote the remaining method examples of functions.md,
structs.md, unions.md, properties.md and the README with `.x` for
`self.x` (#139) and `Self` for the receiver's type (#140), each with a
comment that says so, keeping one `self.x` beside a `.x` in structs.md
to show the two mean the same. Each example compiles and runs.

There are 734 tests, and all pass with clang and with gcc 15.

### 176. complex.k with `extend` and `Self`

> now rewrite complex.k with `extend complex64 {}` and `Self`

**Claude** moved modules/complex.k's operators into
`extend complex64 { }` and `extend complex32 { }` blocks, each written
`static let +(a:Self, b:Self):Self` (#135, #140), with `(Self){...}`
for its values. The converters, `complex64(1.0, 2.0)`, and the
functions that overload C's by name, `sin(z)`, `abs(z)`, stay free,
since each is called by its own name. The outputs are unchanged.

There are 734 tests, and all pass with clang and with gcc 15.

### 177. JSON.k's helpers in `extend JSON { }`

> now rewrite JSON.k's helpers with `extend JSON {}` and `Self`

**Claude** moved modules/JSON.k's helpers into its two
`extend JSON { }` blocks, the parsing and the writing, as functions of
the type (#111) with `Self` for `JSON` (#140): `JSON_value` is
`Self.readValue`, `JSON_space` `Self.skipSpace`, and so on, the ones
named as a case, `JSON_number`, `JSON_string`, `JSON_array`,
`JSON_object`, as `readNumber` and the like, since `Self.number(x)`
makes a value. `JSON_stringify` is the `stringify` overload that takes
a replacer and text, which the others call. The outputs are unchanged.

There are 734 tests, and all pass with clang and with gcc 15.

### 178. Free functions on a type into `extend T { }`

> now rewrite linkedlist.k's free functions with `extend list {}` and
> `Self`. If you find other codes and documents, do so to them as well
> instead of proposing it one by one

**Claude** moved examples/linkedlist.k's `push`, `pop`, `reverse` and
`clear`, which change a list through a pointer, into its `extend list { }`
block as functions of the type, `static let push(l:Self^, value:i64)`,
called `list.push(&l, v)`, since a method's `self` is a let (#138); and
examples/bfi.k's `parse` into `extend program { }` as a function of the
type giving `Result<Self, String>`, with `run` a method that reads
`.code`. The operator examples of structs.md, operators.md and
unions.md are `extend` blocks with `static let +(a:Self, b:Self):Self`,
each noting the alone form. The other examples' functions work on
built-in types or none, and stay. The outputs are unchanged.

There are 734 tests, and all pass with clang and with gcc 15.

### 179. IO and OS as modules: `M.kh` and `libkM`

> Let's separate `IO` and `OS` from prelude. One day it may be used
> where IO is not available like WASM/WASI environments. you will load
> them as `#import <IO>`, `#import <OS>`. you may split the
> implementation with header file and library like C. let header file's
> extension `.kh` and libraries `libkModule.{a,so,dylyb}`. large modules
> should be implemented that way instead of putting everything in `.k`.
> unlike C, `.kh` and `libkM.` are in the `module` folder. And
> `#import <M>` loads `M.kh` and the linker links the library with
> `-llibkM`.

**Claude** asked where SYS goes and whether JSON.k and complex.k turn
into libraries now; the user chose SYS with OS, and later for the
Kelvin-built libraries. #143 is the module as a header and a library:
`M.kh` and `libkM` in `modules/`, found by `#import <M>` before `M.k`,
the library linked by itself. #144 and #145 move IO, and OS with SYS,
out of the prelude: `kelvin_prelude.h` keeps the core, `kIO.h` and
`kOS.h` declare `libkIO` and `libkOS`, built by make, and `IO.kh` and
`OS.kh` bring them in. Without the import, `IO`, `OS` and `SYS` are
errors that say to write it; `IO.kh` imports `<OS>`, which IO's files
are built on. 55 tests gained an import, five test the errors, and
tests/project gained `shout.kh` with `libkshout.a`. Details are
provisional P155 to P157.

There are 739 tests, and all pass with clang and with gcc 15.

### 180. `kelvinc --lib`: a Kelvin file into `libkM`

> now add a mode that builds a Kelvin file into `libkM`

**Claude** asked whether the header comes with it, and the user chose
that it does. #146 is `kelvinc --lib M.k`: `M.kh`, the declarations
with the bodies dropped, and `libkM.a`, the code, in `./modules` or
the directory `-o` names. The header keeps the imports, the types
whole, a prototype of each function, method, function of the type,
operator, attribute and subscript in their `extend` blocks, `extern
let x:T` for a global, `extern let` for a C function's prototype, and
`T.cstr()` with its body, which is inline. A `.kh` may now hold
prototypes of attributes and subscripts, and a prototype there without
`extern` is the library's own, named by its types as the library names
it. tests/run.sh builds JSON.k, complex.k and tests/project's geo.k
into libraries and compiles programs against them. Details are
provisional P158.

There are 743 tests, and all pass with clang and with gcc 15.

### 181. The order of `#import <M>`

> Here is the precedence order of what is loaded on `#import M`.
> presense of `module/M.kh`. That will use `M.kh` and
> `libkM.{a,so,dylib}`. presense of `modules.M.k`. That will simply be
> included in the calleer. So `modules/JSON.k` should stay the way it
> is. It also makes a good example of how to write a module in kelvin.

**Claude** confirmed that #143 does this: for `#import <M>`, each
directory, `./modules` then Kelvin's `modules/`, is tried for `M.kh`
first, whose library is linked, and then for `M.k`, which is included
in the importing program. modules.md now states the order as a rule,
and that `JSON.k` stays a Kelvin source, the example of a module
written in Kelvin.

There are 743 tests, and all pass with clang and with gcc 15.

### 182. `kelvinc --lib` in the documents

> now add `kelvinc --lib` to the documents too

**Claude** added `kelvinc --lib` where the documents show how kelvinc
is run and what it makes: the README's usage block, c-interfaces.md's
options, versusC.md's table against C's `ar rcs` and its index, and
json.md's note that JSON.k, the example of a module written in Kelvin,
builds into `JSON.kh` and `libkJSON.a` where a project wants that.
modules.md had its section already.

There are 743 tests, and all pass with clang and with gcc 15.

### 183. A shared `libkM` from `kelvinc --lib`

> now add a shared libkM to `kelvinc --lib` too

**Claude** added #147: `kelvinc --lib M.k` links its object into
`libkM.dylib` on macOS and `libkM.so` elsewhere, beside `libkM.a`,
against the shared `libkelvin` and the shared libraries of the modules
the file imports, or their static ones where there is no shared one.
It is for C and other toolchains, as `libkelvin.dylib` is; a Kelvin
program's `#import <M>` keeps linking the static one. tests/run.sh
links a C program against `libkgeo.dylib` and runs it; on Linux it
links `libkelvin.so` with it and sets `LD_LIBRARY_PATH`, since a run
path does not reach a library's own dependencies there, which CI's
clang jobs showed. Details are provisional P159.

There are 744 tests, and all pass with clang and with gcc 15.

### 184. `math.k`: math.h, its constants, methods and `x.i`

> rename `complex.k` to `math.k` to give all functionalities of
> `math.h`. sort of like math + cmath. `#include <math.h>` therein. add
> static attributes to `f64` and `f32`, including constants like `pi`
> and `e`. give floating point types methods like `f64.sin()` and
> `f64.exp()`. same there in `complex64.sin()` and other complex
> functions. kelvin is multi-dispatch so simple `sin()` or `exp()`
> should suffice most of the cases but if you want to explicitly
> express which one is used, you can distinguish that way. add a
> computed attribute `.i` to `f{64,32}` and `complex{64,32}` that
> rotates `pi/2` on the gausissian plane. `1.0.i` returns
> `complex64(0.0, 1.0)` for example.

**Claude** made #148: `modules/math.k`, `#import <math>`, holds the
functions of math.h for `f64` and `f32`, each a method too, the
constants of each type as attributes, `f64.pi`, `f32.epsilon`, the
complex functions as methods, and `x.i`. A type attribute may now be
of a number type, read as `f64.pi`, and a module's header declares
one. A literal receiver gets its own type, so `1.0.i` is typed. Every
import of `<complex.k>` is `<math>`. CI's Linux jobs showed glibc's
`llabs` is `long long`, not `int64_t`, so `abs` of an `i64` is written
in Kelvin. Details are provisional P160.

There are 746 tests, and all pass with clang and with gcc 15.

### 185. math.md, `c64` and `c32` with aliases, and the full names

> Where is `math.md` which is supposed to be in `modules/`? rename
> `complex64` to `c64` and `complex32` `c32`. and keep `complex{64,32}`
> as an alias. And give the 'fullname' to `i{128,64,32,16,8}`
> `int{128...}`, `u{128...}` `uint{128...}`, `f{64,32}` `float{64,32}`.

**Claude** wrote documents/math.md, which was missing, the module being
described in modules.md only. Kelvin had no alias, so Claude asked for
its spelling and the user chose Swift's: #149 `typealias A = T`, from
where `A` is `T` wherever a name is read, as `Self` is the receiver's.
#150 names the complex types `c64` and `c32`, with `typealias
complex64 = c64` and `complex32 = c32` in math.k keeping the old names.
#151 gives the number types their full names, `int64`, `uint8`,
`float32`, built into the lexer. Details are provisional P161 to P163.

There are 749 tests, and all pass with clang and with gcc 15.

### 186. The documents' examples with `c64` and the full names

> now rewrite the documents' examples with `c64` and the full names

**Claude** found the examples saying `c64` and `c32` since #150, and
asked what the full names should do in them; the user chose to show
both. One example in each document that declares a number now writes
the full name once, `var n:int64` beside the `i64`s, with a note that
it is the short name's, so a reader sees both spellings; where no
declaration fits, the note is in a comment. The examples' outputs are
unchanged.

There are 749 tests, and all pass with clang and with gcc 15.

### 187. The tests with the full names

> now rewrite the tests with the full names too

**Claude** did for the run tests what #186 did for the documents: in
each that declares a number, one declaration writes the full name,
`var total:int64`, a parameter, a member or an element where no
declaration fits, so the synonyms of #151 are read across the suite
while the outputs stay the same. The error tests are as they were,
since they check messages.

There are 749 tests, and all pass with clang and with gcc 15.

### 188. The examples and modules with the full names

> now rewrite the examples and modules with the full names too

**Claude** gave each example and module one full name, as #186 and
#187 did: a declaration, `var sum:int64`, a parameter, an attribute's
type or `main`'s result in the three examples that declare no number,
each with a note that it is the short name's. JSON.k and math.k, the
modules, build into libraries as before, and the outputs are unchanged.

There are 749 tests, and all pass with clang and with gcc 15.

### 189. The examples and modules with `.x` and `Self`, again

> now rewrite the examples and modules with `.x` and `Self` too

**Claude** found them rewritten since #170, #176, #177 and #178, and
one spot left: the literal annotations of `extend f32` in math.k,
`3.14:f32`, which now read `:Self`, as the block's other types do. The
`self.` the scan showed were comments saying what `.x` is.

There are 749 tests, and all pass with clang and with gcc 15.

### 190. The error and project tests with `.x` and `Self`

> now rewrite the tests with `.attr` and `Self` too, as well as
> wherever applicable.

**Claude** found the run tests, examples, modules and documents
rewritten already (#174 to #178, #186 to #189), and the error tests and
tests/project not: 25 error tests and geo.k now read `.x` for `self.x`
and `Self` for the receiver's type, their expected messages unchanged,
since a message names the form, not the spelling. The tests that are
about `self` and `Self` themselves, and the ones that try the long
`struct point`, keep their spellings on purpose, as does structs.md's
one `self.x` beside a `.x`.

There are 749 tests, and all pass with clang and with gcc 15.

### 191. The README's examples with `.x` and `Self`

> now rewrite the README's examples with `.attr` and `Self` too

**Claude** found the README's one code block and its snippets already
free of `self.x`, its text method reading `${.x}` since #175, and
rewrote the `extend` bullet: the attribute reads `.w * .h`, the operator
`static let +(a:Self, b:Self):Self`, subscripts are listed, and a line
says that in every member `.w` is `self.w` and `Self` is `T`.

There are 749 tests, and all pass with clang and with gcc 15.

### 192. The error tests with the full names, and the documents

> now rewrite the tests with the full names too. Also DOCUMENT about
> full names in interger.md, floatingpoint.md, and any other relevant
> files.

**Claude** gave each error and project test one full name, as #187 did
for the run tests: 539 of them, their messages unchanged, but one that
echoes the source's spelling of an array type, kept short. The full
names are now in integers.md's and floatingpoint.md's tables and
openings, in grammar.md since #151, in versusC.md's table against C's
`int64_t`, in c-interfaces.md beside C's typedef names, and in the
README's list of the types.

There are 749 tests, and all pass with clang and with gcc 15.

### 193. The full names anywhere else

> now rewrite the examples and modules with the full names too. and
> anywhere else that may apply.

**Claude** found the examples and modules done since #188, every one
with a full name, and `IO.kh` and `OS.kh` declaring no type; the two
programs tests/run.sh writes for its library and installation checks
now give `int32` from `main`. The documents, README, run tests and
error tests had theirs since #186, #187 and #192.

There are 749 tests, and all pass with clang and with gcc 15.

### 194. The full names throughout

> now rewrite the documents' examples with the full names too, and
> rewrite anywhere else where you can

**Claude** asked whether the full names should now go throughout, where
#186 to #193 had shown each once, and the user said yes. Every short
name in a type or converter position in Kelvin code, the documents' and
README's examples, the tests, the examples and the modules, is now the
full one, `int64`, `uint8`, `float64`; comments, strings, templates,
the expected outputs and the C names keep the short ones, which
`.typename` and the C give. The one-off notes of #186 are gone. One
test keeps `i32`, whose hint echoes the source's spelling.

There are 749 tests, and all pass with clang and with gcc 15.

### 195. JSON.k and math.k keep the short names

> leave JSON.k as is since it is also a good example of a kelvin module
> written in kelvin. ditto for math.k

**Claude** restored modules/JSON.k and modules/math.k to the short
names, `i64` and `f64`, as they were before #188 and #194, keeping
math.k's `:Self` annotations of #189: the two modules are the examples
of a module written in Kelvin, and read as Kelvin's own names read.

There are 749 tests, and all pass with clang and with gcc 15.

### 196. SION and MessagePack modules

> Implement SION handler and msgpack handler like JSON module.
> https://dankogai.github.io/SION/ https://msgpack.org

**Claude** added #152, modules/SION.k: `enum SION`, JSON with more, an
integer and a double apart, data, a date, an ext, and a dictionary keyed
by any value, kept as its keys and values in turn; `SION.parse` reads
SION's text, with its bases, hex floats, nan and inf, Swift's escapes,
`.Data`, `.Ext`, `.Date` and `//` comments, `SION.stringify` writes it
back with doubles as `%a`, `s["key"]` and `s[i]` read copies and set,
and `SION.same` compares. And #153, modules/MsgPack.k: `MsgPack.pack`
and `MsgPack.unpack` between a SION and MessagePack, every format, a
date as a timestamp, an ext kept whole. documents/sion.md and
msgpack.md describe them. ASan on the new tests showed a leak the
compiler allowed: `s[0].string` of the copy a subscript gives, which
`.is` already refused; #154 refuses a case's value and an attribute of
an owner an expression gives too. Details are provisional P164 to
P166.

There are 755 tests, and all pass with clang and with gcc 15.

### 197. One more test with `Self`

> now rewrite the tests with `.x` and `Self` too

**Claude** found the tests rewritten since #174 and #190, the new SION
and MsgPack tests being usage code with no methods, and one line the
scans had passed over: the type attribute of tests/error/
attribute_static_value.k, `static let rect.unit:rect`, now
`static let rect.unit:Self`, its message unchanged.

There are 755 tests, and all pass with clang and with gcc 15.

### 198. Base64 in the prelude

> Add Base64 handler in the prelude: `Bytes.fromBase64()` takes `cstr`
> or `String` and return `Bytes`. Padding can be omitted and URL-safe
> versions are accepted. `b.toBase64()` that returns `String`. You can
> choose with or without paddings, ordinary or URL-safe. cf.
> https://en.wikipedia.org/wiki/Base64

**Claude** asked how the options are spelled, and the user chose the
words. #155 adds `b.toBase64()`, standard and padded, with `url` and
`nopad` in either order, and `Bytes.fromBase64(text)` of a `cstr` or a
String borrowed, `&s`, which takes either alphabet, with or without
padding, and skips blanks, both in `libkelvin`, runtime/bytes.c.
Details are provisional P167.

There are 758 tests, and all pass with clang and with gcc 15.

### 199. UnicodeData: normalization, graphemes and the database

> let's add two big modules for `String`: `<RegExp>` yes, regular
> expression! add `$/regexp/` literal to support it but you still need
> to `#import <RegExp>` to use it. support Unicode strings to the level
> modern JS does PLUS `\X` that matches a grapheme cluster.
> `<UnicodeData>` like python's `unicodedata` which adds features
> missing from the prelude String: `.graphemes` which returns a stream
> of graphemes, unlike String's default which returns codepoints;
> `.normalize()` which returns the normalized String by nfc, nfd, nfkc,
> and nfkd

**Claude** asked where the data comes from, what `.graphemes` gives,
and how far to go at once; the user chose the database downloaded from
unicode.org, an `Array<String>`, and all of it in two steps. #156 is
the first: tools/ucd/ holds Unicode 18.0.0, tools/gen_unicode.py makes
the tables, runtime/unicode_data.c normalizes, segments and maps the
case over them, and modules/UnicodeData.k, written in Kelvin, is built
by `make` with `kelvinc --lib` into `UnicodeData.kh` and
`libkUnicodeData`: `s.normalize(nfc)`, `s.graphemes`, `s.upper()`,
`s.lower()`, `s.fold()`, and a `uchr`'s `.name`, `.category`,
`.combining`, the case and the decompositions. The database's own
conformance tests pass whole. ASan found a String literal leaking
under `.fold()`, so a method of the program on an owner that an
expression gives is an error now, as a case read is. `<RegExp>` and
`$/.../` are the next step. Details are provisional P168.

There are 762 tests, and all pass with clang and with gcc 15.

### 200. RegExp: `$/.../` and JS's regular expressions

> now step 2: the `<RegExp>` module and the `$/.../` literal

**Claude** built the second half of #156's request as #157: a
backtracking engine in runtime/regexp.c, JS's syntax with the `u`
flag, over Kelvin's Strings by codepoint, with `\X` for a grapheme
cluster and `\p{...}` by category, script and property from tables
that tools/gen_unicode.py now makes too; modules/RegExp.k, written in
Kelvin, wraps it as `RegExp` and `Match`, with `test`, `exec`,
`search`, `match`, `replace` and `split` on a RegExp and on a String,
and `make` builds it with `kelvinc --lib` on `UnicodeData`. The lexer
reads `$/pattern/flags` as `RegExp.compile("pattern", "flags")`, and
the parser says that a file without `#import <RegExp>` cannot write
one. A differential run of 157 patterns, inputs and replacements
against node agreed on every one, which also caught that modern JS has
`(?i:...)` modifiers, now here. A borrow of an owner an expression
gives, `&$/x/`, is an error, as the C it made was. Details are
provisional P169.

There are 767 tests, and all pass with clang and with gcc 15.

### 201. replace with a function, and methods that overload

> can `s.replace(&re, with)` take a function for `with` part? if not
> so, make it so `s.replace(&re) { String(f64($0.text[0]) * 2.0) }`
> works as expected.

**Claude** answered that it could not: a method could not share its
name with another, so a second `replace` had nowhere to go. #158 makes
methods overload by their parameter types as functions do, chosen by
the arguments, an anonymous argument taking the type of the overload
that has a function where it stands, and named in C by their types
where they differ. On the way it found that an owner given by value to
a method, or to a call through a function value, was freed twice, and
that `String(x)` could not start a statement; both are fixed, and
`String(n)` of a number is new. `s.replace(&re) { ... }` and
`re.replace(&s) { ... }` take a function of the Match, which it owns.
Details are provisional P170.

There are 770 tests, and all pass with clang and with gcc 15.

### 202. match with a function, and Fahrenheit to Celsius

> now add `s.match(&re) { ... }` that iterates over each Match. Also
> tweak examples a little from doubling the match to changing
> Fahrenheit to Centigrade (since that looks more natural).

**Claude** added #159: `s.match(&re) { ... }` and `re.match(&s) { ... }`
call the function with each match, every one with `g` and the first
alone without, the Match owned by the function, an overload of the
Array form by #158. The examples of `replace` with a function, in
regexp.md and the tests, now turn `212F` into `100C`. Details are
provisional P171.

There are 771 tests, and all pass with clang and with gcc 15.

### 203. split with a function

> now add `s.split(&re) { ... }` that iterates over each piece

**Claude** added #160: `s.split(&re) { ... }` and `re.split(&s) { ... }`
call the function with each piece, a String it owns, the pieces the
Array form gives, as an overload by #158. Details are provisional
P172.

There are 772 tests, and all pass with clang and with gcc 15.

### 204. replace with a String

> now add `s.replace(&re)` with a String. I thought it was already
> done... wait, the second arg of `var t = s.replace(&re,
> "$<month>/$1")` was only `cstr` and not `String`?

**Claude** confirmed it was a `cstr` alone, and added #161: the
replacement may be a String borrowed, `s.replace(&re, &t)` and
`re.replace(&s, &t)`, an overload by its type that reads the String's
text. Details are provisional P173.

There are 772 tests, and all pass with clang and with gcc 15.

### 205. RegExp(pattern, flags)

> now add `RegExp.compile` with a String for the flags too. Better yet,
> just let `RegExp(str, flags)` do it

**Claude** added #162: `RegExp(pattern, flags)` makes a RegExp, with
the pattern and the flags each a `cstr` or a String borrowed, as
`RegExp.compile` now does too, functions named as the type is, as
`c64(...)` are. The parser now reads a type's `T.name(...)` and `T.x`
also where a function is named as the type, which it did not once such
a function was declared. Details are provisional P174.

There are 772 tests, and all pass with clang and with gcc 15.

### 206. The pattern checked at compile time

> now add `$/.../` compile-time checking of the pattern in kelvinc

**Claude** added #163: the engine's parser of a pattern is its own
file now, runtime/regexp_parse.c, on the Unicode tables alone, and
kelvinc links the two to check each `$/.../` literal as the lexer reads
it, reporting a pattern that is not JS's, an unknown `\p{...}` name or
a flag that is none at its place in the pattern. An error in a check
returns to kelvinc instead of ending the program. Details are
provisional P175.

There are 774 tests, and all pass with clang and with gcc 15.

### 207. escape and unescape

> add `.escape()` to `String` in prelude. with no argument, it turn
> non-ascii code points into `\u{....}` form. You can optionally pass
> `RegExp` where matching characters are escaped, like
> `.escape($/[\p{Emoji}]/)`. `.unescape()` does the opposite.

**Claude** added #164: `s.escape()` and `s.unescape()` in the prelude,
each codepoint beyond ASCII as `\u{...}` and a backslash as `\\`, read
back with JS's other escapes too; and in the RegExp module
`s.escape(&re)` and `s.escape($/.../)`, the literal moved into the
call, which escape what the pattern matches. The parser takes the
built-in method for a call with no argument where the program's
methods of the name all take some. Details are provisional P176.

There are 776 tests, and all pass with clang and with gcc 15.

### 208. unescape of what matches

> now add `s.unescape(&re)` that only unescapes what matches

**Claude** added #165: `s.unescape(&re)` and `s.unescape($/.../)` read
back the escapes in what the pattern matches alone, each match as the
prelude's `unescape` reads the whole. Details are provisional P177.

There are 776 tests, and all pass with clang and with gcc 15.

### 209. escape of a Bytes

> now add `s.escape()` for `Bytes` too, as `\xHH` form

**Claude** added #166: `b.escape()` gives a Bytes's bytes as text, a
String, each byte that is not printable ASCII as `\xHH` and a backslash
as `\\`. Details are provisional P178.

There are 777 tests, and all pass with clang and with gcc 15.

### 210. Bytes.unescape

> now add `Bytes.unescape()` that reads `\xHH` back into a Bytes

**Claude** added #167: `Bytes.unescape(text)`, of a `cstr` or a String
borrowed as `Bytes.fromBase64` takes one, gives the bytes the escapes
stand for, `\xHH` a byte and `\u{...}` the UTF-8 of the codepoint, so
that `b.escape()` and `s.escape()` both read back into bytes. Details
are provisional P179.

There are 777 tests, and all pass with clang and with gcc 15.

### 211. A RegExp on a Bytes

> now add `.escape()` and `.unescape()` with a RegExp for `Bytes` too

**Claude** added #168: the matcher got a byte-wise mode, each byte a
codepoint of its value, and `b.escape(&re)`, `b.escape($/.../)` and
`Bytes.unescape(text, &re)` use it, the escape a String with every
byte that is not text as `\xHH` too. A function of a type may be
declared on `Bytes` or `String` in an `extend` now. Two faults came
out on the way and are fixed: an attribute of a struct was read on a
`cstr` by its name alone, and a module header dropped a prototype whose
text another block had. Details are provisional P180.

There are 778 tests, and all pass with clang and with gcc 15.

### 212. match and split on a Bytes

> now add `s.match(&re)` and `s.split(&re)` for `Bytes` too

**Claude** added #169: `b.test(&re)`, `b.search(&re)`, `b.match(&re)`
and `b.split(&re)`, with the function forms of the last two, as a
String has them, over the byte-wise matcher; a `BytesMatch` holds the
bytes of the whole and of each group with their byte offsets, and the
pieces of `split` are Bytes. Details are provisional P181.

There are 779 tests, and all pass with clang and with gcc 15.

### 213. replace on a Bytes

> now add `b.replace(&re, &bytes)` for `Bytes` too

**Claude** added #170: `b.replace(&re, &with)` and `b.replace(&re,
text)`, with the `$` patterns over bytes, and `b.replace(&re) { ... }`
with a function of each BytesMatch giving the Bytes to put, on a Bytes
and on the RegExp with `&b`. Details are provisional P182.

There are 780 tests, and all pass with clang and with gcc 15.

### 214. The b flag

> add the `b` flag to RegExp to explicitly make it binary mode. with
> that, each character is a byte so `$/[\x80-\xff]/b` matches exactly
> one byte, which is NOT `$/[\u0080-\u00ff]/`. RegExp defaults to
> Unicode codepoint mode where a character is a codepoint. To make it
> clear, let's add `u` flag as well which is actually a no-op.

**Claude** added #171: the `b` flag makes a pattern binary, each
character a byte, on a Bytes and on a String alike, where without it a
character is a codepoint, which `u` says and changes nothing; the
byte-wise matcher of #168 is the flag's now, and the tests on a Bytes
write it. `re.binary` and `re.unicode` read the mode. Details are
provisional P183.

There are 780 tests, and all pass with clang and with gcc 15.

### 215. Bytes of a list, and bytes.md

> I don't get why `Bytes(['\x00', '\x01', '\x02', '\x03'])` does not
> work. make it work. Also split the document about Bytes from
> `strings.md` to `bytes.md`. They look the same but they are
> semantically distinct.

**Claude** explained that a bracket list is no value on its own (#48),
and added #172: `Bytes([...])` reads the list itself, each a byte's
value, with a literal out of 0 to 255 an error. The Bytes half of
strings.md is bytes.md now, with the Bytes rows of the table, and the
links follow. Details are provisional P184.

There are 782 tests, and all pass with clang and with gcc 15.

### 216. A table of contents of the documents

> add `documents/README.md` that works like a TOC of `documents/`.

**Claude** added #173: documents/README.md lists every document with a
line each, grouped as starting, values, reading and writing, and
modules, and the README points to it. Details are provisional P185.

There are 782 tests, and all pass with clang and with gcc 15.

### 217. Exit, not abort

> I feel kelvin is close to Release 0.01. What do you think we should
> fix before that.

**Claude** surveyed the tree, every example and the documents' complete
examples building, 300 mutated sources crashing nothing, and listed
six fixes: failures that abort, the sanitizer job not covering the
test programs, the documents' examples as tests, basic text operations
on a String, a global owner made by a call, and the version.

> now make runtime failures exit(1) instead of abort()

**Claude** added #174: every failure of the runtime prints its reason
and exits with status 1, stdout flushed first, through one function,
with `KELVIN_ABORT` in the environment keeping the abort for a
debugger; the test runner reads `// exit: N` and `// err:` lines, and a
test of an index past the count uses them. Details are provisional
P186.

There are 783 tests, and all pass with clang and with gcc 15.

### 218. The test programs under ASan

> now add the ASan run over the test programs

**Claude** added #175: tests/asan.sh, `make asan`, compiles the
runtime, the modules and every run test with AddressSanitizer and a
counting allocator, runs each, and fails on an error or on blocks
still live at exit; a CI job runs it. Its first run found a String an
expression gives in a plain template, `${$"tpl"}`, never freed, which
is refused now as the `$`...`` form refused it; a test that calls
`SYS.exit` and a free of what `realpath` allocated are known to it.
Details are provisional P187.

There are 784 tests, and all pass with clang and with gcc 15; the ASan
run passes every program.

### 219. The documents' examples as tests

> now make the documents' examples tests

**Claude** added #176: tests/docs.sh, run by `make test`, compiles
every ```kelvin block of the documents and the README, a program as it
is and a fragment rearranged, its declarations at the margin above a
main that holds its statements; a listing or a sketch is marked
`<!-- fragment -->` on the line before its fence. Nine examples gained
the declaration or the import they had left out, and one that
conflicted with C's `labs` was replaced; CI then found `lstat` hidden
by glibc under `-std=c11`, so the C kelvinc writes defines the POSIX
feature macros now, as the runtime does. Details are provisional P188.

There are 784 tests, and all pass with clang and with gcc 15; the
documents' 40 examples compile, with 30 fragments marked.

### 220. find, has, starts, ends and trim

> now add the basic String operations: find, has, starts, ends, trim

**Claude** added #177: `s.find(text)`, the codepoint index or -1,
`s.has(text)`, `s.starts(text)` and `s.ends(text)`, the text a `cstr`
or a String borrowed, and `s.trim()`, the blanks of JS's `\s` taken
off either end; strings.md no longer says searching is not here.
Details are provisional P189.

There are 786 tests, and all pass with clang and with gcc 15.

### 221. A global owner made by a call

> now make kelvinc report a global owner made by a call

**Claude** added #178: an initializer on a global owner is kelvinc's
error now, which says that C initializes a global with a constant
alone and an owner is made by a call, and to declare it with its type
and give it its value in a function; a test declares a String, an
Array and a RegExp that way, and the globals are freed at exit by a
function `main` registers, which the ASan run asked for. Details are
provisional P190.

There are 788 tests, and all pass with clang and with gcc 15.

### 222. The longer fuzz, and the method lookup

> You just suggested "now set the version to 0.1.0 and add a
> CHANGELOG". Are we really ready?

**Claude** said yes for a 0.1.0, which promises nothing stable, and
asked for two checks first: a longer fuzz, and the method lookup that
had found `Match.count` for a `cstr`.

> now run the longer fuzz and tighten the method lookup

**Claude** added #179: a method or an attribute of the program is
found on a value of its own type, none on a pointer, an array or a
function, with a test of a struct's `count`, `has`, `find` and `isNull`
beside the built-in ones; 5000 mutated sources crashed and hung
nothing. Details are provisional P191.

There are 789 tests, and all pass with clang and with gcc 15.

### 223. A function inside a function

> make inner function definitions behave like a toplevel ones: (an
> error on `let fib(n:i64):i64 { ... }` inside main)

**Claude** added #180: a function defined inside a function is a
function of the program as a top-level one is, hoisted in C as an
anonymous function is, named in its block alone, calling itself, other
functions and the globals, and fenced from the locals around it, as C
has no closures; the error test that refused the definition is gone.
Details are provisional P192.

There are 790 tests, and all pass with clang and with gcc 15.

### 224. `$(...)`, the function itself

> Let me add self-recursion syntax: `let fib(n:int64):int64 { n < 2 ?
> n : $(n - 2) + $(n - 1) }`. `$()` is JS equivalent of
> `arguments.callee()`. Valid both on global and inner. You can
> rewrite the example as `let fib = { (n:int64):int64 in n < 2 ? n :
> $(n - 2) + $(n - 1) }` as well.

**Claude** added #181: `$(...)` calls the function it is written in,
at the top level, inside a function, anonymous, or of a type, with
the function's own arguments; in a method it says to write
`self.name(...)`. A let holding an anonymous function is assigned with
`:=`, as a reference is. Details are provisional P193.

There are 793 tests, and all pass with clang and with gcc 15.

### 225. map on an Array

> can we implement generic `.map()` for `Array`?

**Claude** answered yes and added #182: `xs.map(f)` and `xs.map { ... }`
give a new Array of `f` of each element, of whatever type `f` gives,
an owner element given to `f` as a copy; the result of a map's
one-expression function is inferred from arithmetic where its operands
agree, `$0 * 2`, which Kelvin had not done; an `Array<T>(...)` may now
start a statement. Details are provisional P194.

There are 796 tests, and all pass with clang and with gcc 15.

### 226. Chained maps, and `+` on a String

> This is a little inconvenient. Can you make it chainable? (on `var xss
> = xs.map{ $\`${$0}\` }.map{ $0 + "+" }`)

> `.map{ $0 + $"+" }`. `String` must have a `+` operator that concats

**Claude** added #183: a map of an Array an expression gives maps it
and frees it, so that maps chain, and `s + t` is a new String of the
two, a String, text or a `uchr` on either side, copying a String in a
variable and taking one an expression gives. Details are provisional
P195.

There are 798 tests, and all pass with clang and with gcc 15.

### 227. filter and reduce on an Array

> Now implement `.filter()` and `.reduce()` for `Array` as well.

**Claude** added #184 in Swift's spelling, the start of `reduce` first
so that the function trails: `xs.filter { $0 % 2 == 0 }` and
`xs.reduce(0) { $0 + $1 }`, each with a named function too, owner
elements given as copies, an owner start moved in, and chains with
`map` over Arrays an expression gives. Details are provisional P196.

There are 802 tests, and all pass with clang and with gcc 15.

### 228. sort and sorted

> Now add `.sort()` and `.sorted()` to `Array`. .sort is mutating and
> .sorted creates a new sorted array. `$[3,2,1,0].sorted{ $0 < $1 }`
> yields `$[0,1,2,3]`. When the comparator is omitted, `<` is used.
> ascending order, lexicographic if string. Compile error if element
> does not have `<`.

**Claude** added #185: `xs.sort()` in place on a var, `xs.sorted()` a
new Array, each with an optional comparator, else `<` of the elements:
numbers, a `uchr`'s codepoint, the bytes of a String, a Bytes or a
`cstr`, a struct's own `<`, and a compile error otherwise; a stable
merge sort written inline; `<` and the other orderings on Strings and
Bytes. Details are provisional P197.

There are 806 tests, and all pass with clang and with gcc 15.

### 229. reverse and reversed

> now add `.reversed()` and `.reverse()` to `Array` too

**Claude** added #186: `xs.reverse()` in place on a var, `xs.reversed()`
a new Array, reversing an Array an expression gives in place so that it
chains, with their rows in the table of arrays.md. Details are
provisional P198.

There are 808 tests, and all pass with clang and with gcc 15.

### 230. An owner an expression gives, held where it is used

> Those "bind it to variables first" is annoying. fix it like we have
> fixed it for `array.map()` (on `var words = $"Hello,
> Kelvin!".split($/\s+/);`)

**Claude** added #187: an owner that an expression gives is held in a
hidden local where it is used, and freed once the chain, the
comparison or the loop around it is done, so that `$"Hello,
Kelvin!".split($/\s+/)`, `make().name`, `println(make())`, `$"a" ==
s`, `parse("1") ?? 0` and `for x in rows() { }` all work; one given
where a borrow is taken is lent. A pointer into it and a change to it
are still errors, since they would dangle or be lost. Fifteen error
tests became one run test. Details are provisional P199.

There are 797 tests, and all pass with clang and with gcc 15.

### 231. `+` on a Bytes

> now add `+` to `Bytes` too

**Claude** added #188: `b + c` is a new Bytes of the two, a Bytes or text
on the left and a Bytes, text or a byte on the right, copying a Bytes in
a variable and taking one an expression gives; a String and a Bytes are
not joined. The table of bytes.md has its row, and the orderings of
#185 it had left out. Details are provisional P200.

There are 800 tests, and all pass with clang and with gcc 15.

### 232. Kelvin colored as Swift

> What language do you think kelvin is close? I want kelvin codes to
> syntax-colored.

**Claude** answered Swift, over C, with `^` and `:=` from Pascal, and
offered three ways: Swift for `.k` files on GitHub, Swift fences for
the examples, and a Kelvin grammar later.

> do options 1 and 2

**Claude** added #189: `.gitattributes` colors `.k` and `.kh` as Swift,
the 76 examples of the documents, the README and Style.md are fenced
```` ```swift ````, which tests/docs.sh reads, and Style.md says so for
new ones; GitHub's Markdown renderer colors such a block as Swift.
Details are provisional P201.

There are 800 tests, and all pass with clang and with gcc 15.

### 233. A TextMate grammar for VS Code

> now add a Kelvin TextMate grammar for VS Code

**Claude** added #190: editors/vscode, a VS Code extension with a
TextMate grammar of Kelvin for `.k`, `.kh` and ```` ```kelvin ```` blocks,
installed by a link into `~/.vscode/extensions`, and tests/grammar.js,
which `make test` runs where node is: every Kelvin file and document
example of the repository tokenizes cleanly, and sample lines get
their scopes. Details are provisional P202.

There are 800 tests, and all pass with clang and with gcc 15; the
grammar's test passes 935 checks.

### 234. Installing the extension with make vscode

> How do I use "textMate grammar for VS Code"?

> install it for me

> I've done that and the `code` command now appears to work fine.  But
> `ankogai.kelvin-lang-0.0.1` does not appear in `code --list-extensions`.

**Claude** found that VS Code 1.142 had marked the link of #190 obsolete,
since it loads only the extensions it installed itself; it removed the
link, made a `.vsix` by hand with zip, and installed it with
`code --install-extension`.

> yes, do #191

**Claude** added #191: tools/vsix.sh makes the `.vsix` from
editors/vscode with zip alone, `make vscode` installs it with `code`, and
`make vsix` only makes it; editors/vscode/README.md says so, in place of
the link, and tests/grammar.js checks the package. Details are
provisional P203.

There are 800 tests, and all pass with clang and with gcc 15; the
grammar's test passes 945 checks.

### 235. Building on FreeBSD

> When I `make` on FreeBSD it failed.  I tried again with `gmake` and it
> worked fine until: "runtime/os.c:813:22: error: use of undeclared
> identifier '_SC_NPROCESSORS_ONLN'", and a warning of an undeclared
> `getloadavg`

**Claude** added #192: on FreeBSD, _XOPEN_SOURCE hides the BSD
extensions, and nothing hidden is shown where no feature macro is
defined, so kelvinc, the runtime, the generated C and tests/asan.sh
define none on the BSDs; f.abspath asks F_KINFO there, and the uname
test takes FreeBSD. It is not yet run on FreeBSD. Details are
provisional P204.

There are 800 tests, and all pass with clang and with gcc 15.

### 236. make on FreeBSD

> Good news!  `git pull && gmake && gmake test` has worked! Now add a
> Makefile that BSD make hands to gmake.  Also document that `gmake` and
> `python3` must be installed via `pkg` or ports.

**Claude** added #193: the build is GNUmakefile, which GNU make reads
first, and Makefile, which BSD make reads, hands each target to `gmake`;
README.md's "Build and use" names what the build needs and how FreeBSD
gets it, `pkg install gmake python3` or the ports. Details are
provisional P205.

There are 800 tests, and all pass with clang and with gcc 15.

### 237. A FreeBSD job in CI

> now add a FreeBSD job to CI.  As you predicted, so far the test fails
> at: io_abspath.k, "true 1" expected, "false 1" given, and io_stat.k,
> "true true" expected, "false true" given; "798 passed, 2 failed"

**Claude** added #194: the CI job freebsd, FreeBSD in a virtual machine,
builds with gmake and runs `make test` through BSD make as a user; the
two tests take `""` as the abspath of a removed file on FreeBSD, which
names none, and io.md says so. Details are provisional P206.

There are 800 tests, and all pass with clang and with gcc 15.

### 238. abspath remembers

> make abspath remember the last name it found

**Claude** added #195: an IO keeps the last name f.abspath found and
answers by it where neither the path nor the descriptor answers, as of
a removed file on FreeBSD; a closed IO forgets it. The tests of #194
take one answer on every system again, and io_abspath_kept.k is new.
Details are provisional P207.

There are 801 tests, and all pass with clang and with gcc 15.

### 239. The name at open

> now remember the name at open too

**Claude** added #196: an IO keeps the name it opened as, from IO(path),
IO(fd, mode) and OS.mkstemp, and the new one after f.rename, so f.abspath
of a file removed before it was asked answers on FreeBSD too;
io_abspath_open.k is new. Details are provisional P208.

There are 802 tests, and all pass with clang and with gcc 15.

### 240. Inline C

> in addition to `#import <foo.h> as C`, I want to add "inline C" like
> `inline C { int foo(char *bar) { /* ... */ } }`, or should it be as
> simple as `C { ... }`? Don't touch the code yet.

**Claude** recommended `#inline C { ... }`: `C { ... }` is already a call
of `C` with a trailing anonymous function, and the `#` puts it beside
`#import <x.h> as C`; top level only, braces counted as C counts them.

> do #197 with `#inline C { ... }`

**Claude** added #197: the block is written into the generated C where it
stands, with C's errors at the .k's lines; Kelvin uses its names as a
header's, and it calls Kelvin functions written above it; a module keeps
it in its library; VS Code colors it as C. c-interfaces.md has a
section of it. Details are provisional P209.

There are 808 tests, and all pass with clang and with gcc 15.

### 241. Inline C in functions

> now allow #inline C inside functions too

**Claude** added #198: `#inline C { ... }` among a function's statements,
seeing its locals by their C names; a C `return` returns, and the owners
it leaves are freed, since Kelvin frees them by C's `cleanup` attribute;
c-interfaces.md has "In a function", and inline_c_fn.k is new. Details
are provisional P210.

There are 809 tests, and all pass with clang and with gcc 15.

### 242. A module's inline C in its .kh

> export Kelvin functions to the .kh for #inline C names too

**Claude** added #199: `kelvinc --lib` writes the declarations of a
top-level `#inline C` into the module's .kh, in an `#inline C` of their
own: its preprocessor lines, function prototypes, types, and globals as
`extern`, leaving out what is `static` or `inline`; a program that
imports the module calls the C. tests/project's geo module has one.
Details are provisional P211.

There are 809 tests, and all pass with clang and with gcc 15.

### 243. A type and a variable at once

> now allow struct p { ... } v; in #inline C exports

**Claude** found that `struct p { ... } v;` already went to the .kh as
`extern struct p { ... } v;`, which C takes, and that the case it
missed was `struct p v = {...};`, defined twice; it fixed that as #200,
and the tagged type of a `static` variable now goes to the .kh alone.
geo.k has both. Details are provisional P212.

There are 809 tests, and all pass with clang and with gcc 15.

### 244. SKI, Iota and Jot

> add `example/ski.k` that implements SKI combinator logic.  It should
> also include iota and jot.

**Claude** added #201, examples/ski.k, since the examples are in
examples/: SKI terms reduced to a normal form, Iota's `*` and `i` and
Jot's bits compiled to SKI, with K and S of each shown by what they do
to variables; a term of any of the three from the command line. The
README's table of examples has it. Details are provisional P213.

There are 810 tests, and all pass with clang and with gcc 15.

### 245. The lambda calculus

> add `examples/lambda.k` as well which implements the lambda calculus.
> https://en.wikipedia.org/wiki/Lambda_calculus since we can already
> handle Unicode, lambda is λ, not \ like lame languages like Haskel.

**Claude** added #202, examples/lambda.k: terms written with λ, Church
numerals and the article's definitions, `FACT 3` by Y, normal-order
reduction over de Bruijn indices with names primed by ′ where they
would capture; a `\` is refused with a word about λ. It found a bug of
kelvinc, `return c ? a : s` of a local String freeing what it returns,
left for a change of its own; and ski.k's comment now passes its
arguments after `--`. Details are provisional P214.

There are 811 tests, and all pass with clang and with gcc 15.

### 246. c ? a : b of owners

> fix the return ternary bug as #203

**Claude** found the bug wider than `return`: kelvinc took `c ? s : t`
of owners for a value an expression gives, so `var u = c ? s : t`, a
call taking it, and even `println(c ? s : t)` freed s. #203 makes two
places a place, read where they are and never copied or moved, a place
beside a value an error but where it is returned, and `return c ? a : b`
moves the arm it gives; `xs += c ? x : y` appends an element. Rule O12
in ownership.md; lambda.k returns its ?: again. Details are provisional
P215.

There are 815 tests, and all pass with clang and with gcc 15.

### 247. Self-hosting, a proof of concept

> Is it possible to self-host kelvin? dig `selfhost/` and put every `.k`
> in it. no CI yet. It is still a proof-of-concept. The code must be
> purely written in Kelvin. `#import <whatever> in C` is considered
> cheating. You can use prelude and modules purely written in kelvin and
> `<IO>` so you can load source `.k` and emit `.o` or executables. like
> gcc, self-hosting capability is verified by stages. list all
> difficulties that get in a way to make kelvin self-hosting. So we can
> make it easier next dialogues.

**Claude** added #204: selfhost/kc.k with lex.k, parse.k and gen.k, a
compiler of a subset of Kelvin written in that subset, writing C as
kelvinc does and running cc through `IO.exec`. selfhost/bootstrap.sh
builds stage1 by kelvinc, stage2 by stage1, stage3 by stage2: stage2
and stage3 write the same C of kc, 2783 lines, and sample.k prints the
same built by kc and by kelvinc; gcc 15 and ASan agree. It found that
kelvinc's `a[i].f = g()` writes freed memory under gcc when g grows a.
selfhost/README.md lists the difficulties. Details are provisional P216.

There are 815 tests, and all pass with clang and with gcc 15.

### 248. libc is allowed

> When we self-host, we can still depend on libc (or libSystem if you are
> on macOS). That is one thing common with C and Kelvin was born to
> embrace it rather than refusing it like many modern languages.

**Claude** took it as the rule of #204: a self-hosted Kelvin depends on
libc as C does, and only C of our own, `#inline C` or headers and
libraries written for it, is cheating. selfhost/README.md now says so:
`getenv`, `mkdtemp` and `exit` take the environment, the temporary
directory and the exit off the list of difficulties, once kc reads
`#import <x.h> as C`; the `$/.../` check, the runtime and a backend of
its own stay on it.

There are 815 tests, and all pass with clang and with gcc 15.

### 249. The value first

> fix the a[i].f = g() bug as #205

**Claude** added #205: an assignment to an element of an Array or a
Bytes, and a method of one, make the value and the arguments that call
first, then find the element, so g growing the Array no longer sends the
value where its elements were; with gcc, the test printed `0 7` before
and `7 14` after. It found another bug, `xs += &c` of a struct that owns,
left for a change of its own. Details are provisional P217.

There are 816 tests, and all pass with clang and with gcc 15.

### 250. Appending a borrow

> fix the cells += &c bug as #206

**Claude** found it wider than structs that own: a borrow of one element
appended to an Array, `names += &s`, `cells.append(&c)`,
`cells.insert(0, &c)`, `nested += &xs`, was C that did not compile for
every type of element. #206 appends a copy of it, by its type's copy,
which the Array then owns; `&ys` of an Array of the same type is still
its elements. arrays.md says so. Details are provisional P218.

There are 817 tests, and all pass with clang and with gcc 15.

### 251. kc reads C's headers

> teach kc #import <x.h> as C as #207

**Claude** added #207: kc includes a header imported as C and takes a
name it does not know for C's, as kelvinc does, with `nullptr`, `:=`
and C's typedefs; and kc itself uses libc: `KELVIN_HOME`, `CC` and
`TMPDIR` by `getenv`, a temporary C file by `getpid`, removed by
`remove`. The stages keep their fixpoint, and sample.k calls strlen,
abs and getenv. Details are provisional P219.

There are 817 tests, and all pass with clang and with gcc 15.

### 252. The C contract

> write down the C contract as #208

**Claude** added #208, documents/c-contract.md: the C a Kelvin program
becomes, read from kelvinc's output and its naming code, so that a
second compiler, as kc is, has it in writing. A probe found a bug of
kelvinc, `d[$"a"] = 1`, whose C cannot assign the entry, left for a
change of its own. Details are provisional P220.

There are 817 tests, and all pass with clang and with gcc 15.

### 253. A key held

> fix the d[$"a"] = 1 bug as #209

**Claude** added #209: an assignment to a place held in temporaries, as
`d[$"a"]`, whose key a temporary holds, goes inside them, so that the
entry is set as `d["a"] = 1` sets it; `+=` and the rest change it.
dictionaries.md says so. Details are provisional P221.

There are 818 tests, and all pass with clang and with gcc 15.

### 254. kc switches on enums

> teach kc switch on enums as #210

**Claude** added #210: kc reads C's enums of names and Kelvin's
`switch`, each case its own block, exhaustive on an enum or with
`default:`; and kc is written in them now, its kinds of tokens, nodes and
types three enums, its types and statements chosen by switches. The
stages keep their fixpoint, 3216 lines, with clang, gcc 15 and ASan.
Details are provisional P222.

There are 818 tests, and all pass with clang and with gcc 15.

### 255. kc's symbol tables

> teach kc Dictionary for symbol tables as #211

**Claude** added #211: kc reads `Dictionary<K, V>`, its entries set,
read, looked up and counted, its C KV_DICT as kelvinc's; and kc keeps
its functions, globals, structs, enums and enumerators in Dictionaries
by name. The stages keep their fixpoint, 3442 lines, with clang, gcc 15
and ASan; at kc's size it is no faster, about 7 ms either way. Details
are provisional P223.

There are 818 tests, and all pass with clang and with gcc 15.

### 256. kc's numbers as text

> teach kc String(n) as #212

**Claude** found kc writing `String(x)` as kelvinc does already, and
added #212 where it fell short: `true` and `false` are bools in its C,
so String(true) is `true`, and a String an expression gives, passed to a
function, is an error, since kc would not free it. kc writes its numbers
by String(n) now. The stages keep their fixpoint, 3431 lines, with
clang, gcc 15 and ASan. Details are provisional P224.

There are 818 tests, and all pass with clang and with gcc 15.

### 257. kc's methods

> teach kc methods of extend as #213

**Claude** added #213: kc reads `extend T { ... }` and `let T.m(...)`,
methods and functions of the type, with `self`, `.x` and `Self`, and
calls them by kelvinc's names, `T__m(x, ...)`, straight, since it knows
the receiver's type; kc's own queries of a type and of a node are
methods now, and its nodes are made by `node.leaf`. The stages keep
their fixpoint, 3611 lines, with clang, gcc 15 and ASan. Details are
provisional P225.

There are 818 tests, and all pass with clang and with gcc 15.

### 258. kc infers

> teach kc inference of literals as #214

**Claude** added #214: a variable written without a type takes its
value's, by kelvinc's rules, which a probe of each kind of value showed:
literals, bools, comparisons, casts, and what kc sees of names, calls,
members and elements, but not arithmetic. kc's own variables of a
literal say no type now, 34 of them, and `println` of more than 16
values is an error in kc as in kelvinc. The stages keep their
fixpoint, 3703 lines, with clang, gcc 15 and ASan. Details are
provisional P226.

There are 818 tests, and all pass with clang and with gcc 15.

### 259. kc's enums with values

> teach kc enums with values as #215

**Claude** added #215: kc reads enums whose cases carry values and writes
them as kelvinc does, making, reading, setting and testing a case, and
switching on one with the case's value bound; kc's `load` gives one now.
A count of allocations found kc left its globals unfreed at exit, which
it now frees as kelvinc does, and found that tests/asan.sh does not count
what realpath gives, so a leak in a program that opens files could pass:
left for a change of its own. The stages keep their fixpoint, 4288
lines, with clang, gcc 15 and ASan. Details are provisional P227.

There are 818 tests, and all pass with clang and with gcc 15.

### 260. Counting realpath

> fix the realpath counting blind spot as #216

**Claude** added #216: the counting allocator of tests/asan.sh counts the
block realpath gives, which the runtime frees, and a count below zero
fails, where it passed before. A program that opens a file and leaks a
block shows the leak now, which it hid before; without the renaming,
the new check fails 22 programs that open files. Details are
provisional P228.

There are 818 tests, and all pass with clang and with gcc 15; tests/asan.sh
passes all 216 programs.

### 261. kc's Optional and Result

> teach kc Optional and Result as #217

**Claude** added #217: kc reads `T?`, `Optional<T>` and `Result<T, E>`,
making each the enum with values kelvinc makes, with `none`, `ok(v)`,
`err(e)` and a wrapped T by the type that takes them, `??`, and
`if let`; kc's `load` gives a Result and `case_named` an Optional. It
found that kelvinc reads no bare `some(v)`, and leaves the error to C;
kc refuses it in a word of its own. kc compiling itself leaves nothing
live at exit, realpath counted. The stages keep their fixpoint, 4764
lines, with clang, gcc 15 and ASan. Details are provisional P229.

There are 818 tests, and all pass with clang and with gcc 15.

### 262. d[k] as an Optional

> `Dictionary` currently dies when `d[k]` is nonexistent.  Let's change
> it to return `Optional`. postfix `!` unwraps the result or dies.
> postfix `?` unwraps the result or `none`.

**Claude** asked three things: `?` chaining as Swift's or returning as
Rust's, which `try` does; whether `d[k] += 1` stays a place; and whether
`!` and `?` are of every Optional. The user chose chaining, places, and
every Optional.

**Claude** added #218: `d[k]` read whole is an Optional, `d[k]!` the
value or the end of the program, `x?.m` a chain, `none` of `none`;
going into `d[k]` is the place it was. An Optional where a value goes is
an error that names `!` and `??`, and `??` of an Optional of an Optional
wraps its default. Tests that printed `d[k]` read `d[k]!`; kc reads
`x!` and refuses a whole `d[k]`. Details are provisional P230.

There are 821 tests, and all pass with clang and with gcc 15.

### 263. kc's d[k] as an Optional

> teach kc d[k] as an Optional as #219

**Claude** added #219: kc reads `d[k]` whole as kelvinc does, a `V?` of a
copy of the entry's value or `none`, which goes where a `V?` goes, and
`if let` frees; going into `d[k]` stays the place. kc makes each
Dictionary's `V?` as it reads the type. An Optional where a value goes
is now kc's error, not C's. sample.k reads whole entries, and its output
is still kelvinc's. On the way, kelvinc turned out to write `??'` of a
Kelvin string into C as it is, which C11 reads as a trigraph; that is
left for a change of its own. Details are provisional P231.

There are 821 tests, and all pass with clang and with gcc 15.

### 264. No trigraphs

> fix the trigraph bug as #220.  WE DO NOT SUPPORT TRIGRAPHS.  It is
> terribly obsolete in the age of Unicode.

**Claude** added #220: kelvinc writes a `?` after a `?` as `\?` in
every string literal, in `#inline C`'s strings, characters and
comments, in a `.typename` and in a `#line`'s file name, so that
`"what??!"` prints as written with clang and with gcc, neither of which
`-std=c11` lets stop reading trigraphs portably. A `??` in `#inline C`'s
code, or in a C header's name, is an error. kc writes its strings the
same way. Details are provisional P232.

There are 824 tests, and all pass with clang and with gcc 15.

### 265. kc's chains

> teach kc x?.m chaining as #221

**Claude** added #221: kc reads `x?.m`, `x?.f(...)` and `x?[i]` as
kelvinc does, the rest of the chain of a name bound to what `x` holds,
`none` of `none`, an Optional not wrapped twice, an owner copied out, and
an `x` an expression gives freed; and `$[T]?`. The `T?` a chain needs
may be made while a function is written, so kc writes the enums made
then before the functions. On the way kc learned to pass and return a
bare `none` without an enum case of that name, `??` kept its own
temporary's name, and an enum holding an Array came after it. Left: kc
does not free a struct whose fields own, nor read `none` in `{a, b}`;
and kelvinc writes `take(none)` as C it cannot compile. Details are
provisional P233.

There are 824 tests, and all pass with clang and with gcc 15.

### 266. take(none)

> fix the take(none) bug as #222

**Claude** added #222: an argument where a function or a method takes an
Optional or a Result is wrapped as a return's value is, so `take(none)`
and `take(5)`, both C errors before, call `take`. Among overloads, `none`
fits an Optional alone, `ok(v)` and `err(e)` a Result, and a `T` fits a
`T?` only where nothing takes it as it is, so `g(5)` still calls
`g(i64)` beside `g(i64?)`; a `none` two Optionals take is an error that
names `Optional<i64>()`. Found: with overloads, `f("text")` goes to C
where one takes a `String`. Details are provisional P234.

There are 826 tests, and all pass with clang and with gcc 15.

### 267. C's function iff no Kelvin one

> fix the String literal overload bug as #223.  Let us make it so C
> function is used iff no kelvin function with a same name exists.
> Update functions.md accordingly.

**Claude** added #223: beside a Kelvin function of its name, C's function
is no longer the fallback for arguments no overload takes; it is called
only where it is declared, `let sqrt(x:f64):f64`, which makes it an
overload, as `#import <math>` already does. Arguments that fit no
overload are an error, as is a function value of no overload's type, and
C's `_Generic` no longer falls back to C's. A text literal now fits a
`String` parameter among overloads, so `h("x")` calls `h(v:String)`.
overload.k and overload_unseen.k declare the C functions they call
beside Kelvin's. A call before a Kelvin function of the name is still
C's, as calls see what is declared before them. Details are provisional
P235.

There are 830 tests, and all pass with clang and with gcc 15.

### 268. some(v)

> fix the bare some(v) message as #224

**Claude** added #224: `some(5)` written as a value was C's error of an
undeclared function `some`; now it is Kelvin's, which says to give `5`
itself where a `T?` goes, or `Optional<T>(5)`, since `some(v)` is a
pattern alone. `some(v)` where a Result goes names `ok` and `err`, and
`ok(5)` or `err(5)` where no Result is expected, also left to C before,
names `Result<T, U>.ok(v)`. Patterns, and a function of the program
named `some`, are as they were. Details are provisional P236.

There are 834 tests, and all pass with clang and with gcc 15.

### 269. kc frees structs that own

> teach kc to free structs that own as #225

**Claude** added #225: a struct with a member that owns is an owner to kc
now, with kelvinc's `_kv_T_free`, `_take` and `_copy`, so it is freed
where its block ends, moved out by `return`, held in an Array, freed at
exit as a global, and freed before `=` gives it a new value. kc writes
each type after the types it holds by value, as a struct with a
`$[String]` member needs. `{a, b}` reads each member by its field's
type, so `none` goes there too; a local owner there is an error that says
`.copy()`, as kelvinc's is. sample.k adopts a `pet`. Details are
provisional P237.

There are 834 tests, and all pass with clang and with gcc 15.

### 270. kc frees owners passed by value

> teach kc to free owners passed by value as #226

**Claude** added #226: an owner a function takes by value moves into it
and is freed there, in kelvinc's C, `_kv_s_in` bound to a local `s`; a
variable passed moves in by `_take`, an owner an expression gives goes
in as it is, and a member or an element is an error that says to pass a
borrow or a copy, as kelvinc's is. Methods take their arguments by their
parameters' types now, and `.copy()` copies an Array, a Dictionary or a
struct as it did a String. sample.k shouts. Details are provisional P238.

There are 834 tests, and all pass with clang and with gcc 15.

### 271. kc holds temporaries

> teach kc to hold temporaries as #227

**Claude** added #227: an owner an expression gives, where kc only reads
it, is held in a temporary and freed once the expression is done, in
kelvinc's C: an argument a function does not take by value, `&f()`, a
member, an element or a method of it, `==`, a `for` loop's source, and a
statement that drops it. A member or an element that owns is copied out,
and a pointer into a temporary is an error, as in kelvinc. So
`println(String(n))` needs no variable now. On the way, `==` of two
temporaries and `f()?.m ?? 0` in a program that wrote no `T?` were fixed;
printing an Optional is left. Details are provisional P239.

There are 834 tests, and all pass with clang and with gcc 15.

### 272. The bootstrap in CI

> add the selfhost bootstrap to CI as #228

**Claude** added #228: a `selfhost` job in CI, with gcc and clang on Ubuntu
and clang on macOS, that runs `selfhost/bootstrap.sh`, its fixpoint and
its sample, and `selfhost/sanitize.sh`, new, which builds kc with ASan and
UBSan and checks that it writes the same C, as was done by hand since
#204. The counting allocator's run of kc's programs is still by hand.
Details are provisional P240.

There are 834 tests, and all pass with clang and with gcc 15.

### 273. kc prints Optionals

> teach kc to print Optionals as #229

**Claude** added #229: kc prints an Optional, a Result, an enum with
values and a struct as kelvinc does, `some(3)`, `none`, `ok(5)`,
`num(5)`, `{x: 1, y: 2}`, text quoted, by printers of kelvinc's form. On
the way kc learned `T??`, `some` of a number literal for any number and
of `{a, b}` for a struct, and `T.c(v)` of an enum in a program that
names no `T` as a type. Printing an Array is left. Details are
provisional P241.

There are 834 tests, and all pass with clang and with gcc 15.

### 274. kc prints Arrays; selfhost is experimental

> teach kc to print Arrays as #230.  Also mark `selfhost` from "proof of
> concept" to "experimental" now that it is on CI.

**Claude** added #230: kc prints an Array as kelvinc does, `[1, 2]`,
`[]`, and Arrays of text, of structs, of Arrays, and inside an Optional,
by printers of kelvinc's form. selfhost/ is experimental now, in
README.md, selfhost/README.md and kc.k's head: CI checks it on every
push, though its subset and its C may still change. Details are
provisional P242.

There are 834 tests, and all pass with clang and with gcc 15.

### 275. The subset list

> update the selfhost README's subset list as #231

**Claude** added #231: selfhost/README.md's list of what kc leaves out,
written at #204, named much that kc reads now. It lists what the subset
took in since, by change, and what it still leaves out, read off kc's
own lexer and parser: overloading, `c ? a : b`, `try`, anonymous
functions, templates, floats, the bitwise operators and the rest. The
sizes, the count of tests and the time of a compile are taken again:
kc is 3,900 lines, and compiles itself in about 12 ms. Details are
provisional P243.

There are 834 tests, and all pass with clang and with gcc 15.

### 276. kc's c ? a : b

> teach kc c ? a : b as #232

**Claude** added #232: kc reads `c ? a : b` as kelvinc does, the loosest
operator, grouping to the right, each arm by the type that takes it, so
`n % 2 == 0 ? n / 2 : none` is an `int64?`; of owners, O12 with
kelvinc's messages, and `return c ? a : b` moves either out. kc's own
source chooses so in five places, and the sample in four. On the way,
kc was found to take `let s:cstr = ...`, which kelvinc refuses. Details
are provisional P244.

There are 834 tests, and all pass with clang and with gcc 15.

### 277. kc's = and :=

> fix kc's cstr = check as #233

**Claude** added #233: kc checks `=` and `:=` as kelvinc does, a reference,
a `cstr` or a `T^`, by `:=`, and a value by `=`, in declarations, globals
and assignments, with kelvinc's messages word for word. kc also reads
`p := q` as an assignment now, which it did not. As in kelvinc, an Array
and a Dictionary are left unchecked. Details are provisional P245.

There are 834 tests, and all pass with clang and with gcc 15.

### 278. kc's overloading

> teach kc overloading as #234

**Claude** added #234: kc overloads functions as kelvinc does. A call gets
the overload its arguments fit best, scored as kelvinc's `fit` scores
them, with `none`, `ok(v)` and a `T` of a `T?` as #222 has them; a tie
and no fit are errors, as #223 has them; and each defined overload is
named in C as kelvinc names it, `twice__i64`. On the way kc learned to
make a `String` of a text literal given where one goes, and to refuse a
call of a name that a variable hides, which kelvinc's build of the
sample met. The overloads of methods are left. Details are provisional
P246.

There are 834 tests, and all pass with clang and with gcc 15.

### 279. Dictionary ==

> add the following features to `Dictionary`:
>
> * `==`.  Both key types and value times must match.  If not, fatal
>   error.
> * `d0.merge(d1){ v0, v1 in ...}`. the function is called when keys
>   collide.  also `.merging()`which creates a new dictionary.
> * `d0 ?? d1` and `d0 !! d1` like
>   https://github.com/dankogai/swiftalk/blob/main/documents/Dictionary.md

**Claude** read swiftalk's Dictionary.md and asked four things. The user
chose: three changes in turn; a value type with no `==` an error at
compile time; untyped `{ v0, v1 in ... }` for `merge`, the new value
winning without a function; and `??=` and `!!=` beside `??` and `!!`,
`!!` a binary operator.

**Claude** added #235: `d0 == d1` and `!=` compare two Dictionaries of the
same key and value types, entry by entry in any order, each value by its
own `==`; other types, and values without `==`, are errors. A Dictionary
of values that compare has `==` itself, so an enum holding one, even one
of its own type, compares too. Details are provisional P247.

There are 837 tests, and all pass with clang and with gcc 15.

### 280. Dictionary merge and merging

> go on with #236

**Claude** added #236: `d.merge(&e)` adds `e`'s entries to `d` in place,
and `d.merging(&e)` gives a new Dictionary; where a key is in both, the
function, `{ old, new in ... }`, trailing or after a comma, gives the
value kept, and without one `e`'s value wins. `e` by value, as
`d.merge(e)`, moves in and is freed. An anonymous function's parameters
may now be named without their types wherever kelvinc sees them, so
`xs.reduce(0) { acc, x in acc + x }` reads too. Details are provisional
P248.

There are 842 tests, and all pass with clang and with gcc 15.

### 281. Dictionary ?? and !!

> go on with #237

**Claude** added #237: `d0 ?? d1` fills in, keeping `d0`'s value where a
key is in both, and `d0 !! d1` overrides, taking `d1`'s, as swiftalk's,
so `(d0 !! d1) == (d1 ?? d0)`; `d0 ??= d1` and `d0 !!= d1` do the same
in place. `!!` binds as `??` does, and `!!x` is still two `!`s.
operators.md's table gains its missing row for `??`, and the VS Code
grammar the new operators. This finishes the user's three Dictionary
features. Details are provisional P249.

There are 845 tests, and all pass with clang and with gcc 15.

### 282. Dictionary map, filter and reduce

> add `.map`, `.filter`, and `.reduce` to `Dictionary`.  Like `Array`,
> only values are passed to the function.  only values are transformed
> for `.map`.  `.filter` drops key-value pairs that are disqualified by
> the filter.  Those behaviors make `Dictionary` a sparse array.  Maybe
> we will add versions of those that pass key-value pair but for now just
> add value-only versions.

**Claude** added #238: `d.map { v in ... }` gives a Dictionary of the same
keys and the function's values, of whatever type it gives; `d.filter`
keeps the entries whose value passes; and `d.reduce(init)` folds the
values in the order added, as an Array's do. Versions whose function
takes the key too are left for later. Details are provisional P250.

There are 847 tests, and all pass with clang and with gcc 15.

### 283. filter returns a bool

> make filter require a bool as #239

**Claude** added #239: what a filter's anonymous function returns, of an
Array or a Dictionary, is a `bool`; `xs.filter { $0 + 1 }` and
`d.filter { v in v }` are errors that say to compare, as in `x != 0`,
where C would have made the number a `bool`. A named function's result
type was checked already. Details are provisional P251.

There are 849 tests, and all pass with clang and with gcc 15.

### 284. bool functions return a bool

> make bool functions return a bool as #240

**Claude** added #240: every value a function of a `bool` result returns
is a `bool`, of a named function, a method or an anonymous one, as #239
made it of a filter's: `return n % 2` is an error that says to compare,
and `return 1` one that says `true` or `false`, where C converted the
number. A local's type is seen, since each return is checked where it is
read. A value only C sees, as `isdigit(c)`, is still C's. Details are
provisional P252.

There are 852 tests, and all pass with clang and with gcc 15.

### 285. Key-value map, filter and reduce

> add key-value versions of map, filter and reduce as #241  Let's begin
> with the name of methods.  Suggestions?

**Claude** suggested `mapWithKey`, `filterWithKey` and `reduceWithKey`,
after Haskell's Data.Map, beside `...Entries`, overloading by arity, and a
view of pairs.

> What is the type of the values that `{ k, v in ... }` returns?  just a
> new transformed value? or key-value pair?

**Claude** answered the new value alone, the keys staying: Kelvin has no
pair, and changing keys would need a rule for keys that meet, a method of
its own.

> BTW what algorithm is used in `Array` sorting?

**Claude** answered from codegen.c: a stable merge sort, bottom up, through
a buffer as large, the elements moved as they are, O(n log n); with a
function of its own over owners, each comparison copies both.

> go ahead with mapWithKey, filterWithKey and reduceWithKey

**Claude** added #241: the three take a function of each key and its
value, a String's key as a `cstr`, lent; `mapWithKey` keeps the keys and
gives the function's values. Details are provisional P253.

There are 855 tests, and all pass with clang and with gcc 15.

### 286. sort lends its comparator the elements

> make sort pass borrows to the comparison as #242

**Claude** added #242: an anonymous comparator of `sort` and `sorted` is
lent the elements, lets the Array keeps, as `for x in xs` binds them, so
a comparison of Strings copies nothing; sorting 200,000 by length took a
quarter of the time. A named comparator still owns its parameters and
gets copies. On the way a use after free of #185 was found and fixed: a
struct's own `<` was given owning elements as they are, and freed them.
Details are provisional P254.

There are 857 tests, and all pass with clang and with gcc 15.

### 287. d[k] ??= v and d[k] !!= v

> Before making map, filter and reduce lend elements as #243, let's add
> `d[k] ??= v` which  does `d[k] = v` only when `d[k]` is absent, and
> `d[k] !!= v`which does `d[k] = v` only when `d[k]` is present

**Claude** added #243, the lending of map, filter and reduce to be #244:
`d[k] ??= v` sets the entry only where the key is absent and `d[k] !!= v`
only where it is present; the key is read once, and `v` is made only
where it is set. Found on the way: `d[k] = v` does not check the value's
type, which C reports. Details are provisional P255.

There are 859 tests, and all pass with clang and with gcc 15.

### 288. map, filter and reduce lend their elements

> make map, filter and reduce lend elements as #244

**Claude** added #244: map, filter and reduce, of Arrays and Dictionaries,
lend an owner element to an anonymous function, as sort does since #242,
so `names.map { $0.count }` copies no String. Returning the element as
it is, `names.map { $0 }`, is an error that says `$0.copy()`; a parameter
written `var` gets a copy of its own to change, which kept
tests/run/array_map.k's `(var s:String)` as it was; a named function
still gets a copy. Details are provisional P256.

There are 861 tests, and all pass with clang and with gcc 15.

### 289. Temporaries live until the statement is done

> before making d[k] = v check the value's type as #245, I have a question
> on memory management.  I once complained about "save it to a variable
> first" on a RegExp.  Besides regexp, those values unassigned to a
> variable are quite frequently used.  I would call it "immediate values".
> [...] Is our memory management handle those cases properly?

**Claude** built the user's cases under ASan and the counting allocator,
`println($"hello, kelvin!")`, `$[0,1,2,3].map { $0 * $0 }`, Dictionaries
and RegExps made in place, and found each freed once used, as #187 holds
them: nothing live at exit. What was still refused was a pointer into
one, `strlen($"abc".cstr)`, its String freed at the end of its own chain;
and `a == $[0,1,4,9]` does not compile, Kelvin having no Array `==`.

> keep temporaries alive until the end of the statement as #245.

**Claude** added #245: a pointer into a temporary keeps it alive until the
call or expression around it is done, up to the statement, so
`strlen($"abc".cstr)` and `println(String(42).cstr)` work; a pointer kept
past the statement is still an error. `d[k] = v`'s check of the value's
type becomes #246. Details are provisional P257.

There are 863 tests, and all pass with clang and with gcc 15.

### 290. d[k] = v checks the value's type

> make d[k] = v check the value's type as #246.  also implement `a0 == a1`
> where a0, a1 are Array instances

**Claude** took the two as #246 and #247. #246: `d[k] = v`, `??=` and
`!!=` check the value against the Dictionary's value type, text for a
number and a number for a String now Kelvin's errors, not C's; a number
still takes any number. Details are provisional P258.

There are 866 tests, and all pass with clang and with gcc 15.

### 291. a0 == a1 compares Arrays

> also implement `a0 == a1` where a0, a1 are Array instances

**Claude** added #247: `a0 == a1` and `!=` of two Arrays of one element
type, true where they hold as many elements, each equal to the one in
its place by its own `==`, as Dictionary `==` (#235) compares values.
Elements without `==`, a struct's, are an error. An Array now compares
wherever a type's `==` asks, so JSON and SION have `==` too.
`array_compare.k` now checks that `<` is refused. Details are
provisional P259.

There are 870 tests, and all pass with clang and with gcc 15.

### 292. Searching an Array

> add Array searching (contains, firstIndex) as #248

**Claude** asked three things: what `firstIndex` gives where nothing is
found, whether a function form comes too, and whether `lastIndex` does.
The user chose an `i64?`, both forms and `lastIndex`. `xs.contains(x)`
is a `bool`; `xs.firstIndex(x)` and `xs.lastIndex(x)` are `some(i)` or
`none`; each also takes a function, `xs.contains { $0 > 2 }`. A bug
from #240 turned up on the way: `return s == $"b"` in a bool function
was refused, and now it is a bool. Details are provisional P260.

There are 874 tests, and all pass with clang and with gcc 15.

### 293. Searching a Dictionary

> add Dictionary searching as #249

**Claude** asked what to name the methods that give a key, and whether
key-and-value versions come too. The user chose `firstKey` and
`lastKey`, and the WithKey versions. `d.contains(v)` looks among the
values, as `d.has(k)` looks among the keys. `d.firstKey(v)` and
`d.lastKey(v)` give `some` of the key or `none`, in the order added.
Each also takes a function of a value, and `containsWithKey`,
`firstKeyWithKey` and `lastKeyWithKey` take a function of a key and its
value. Details are provisional P261.

There are 878 tests, and all pass with clang and with gcc 15.

### 294. ?? of an Optional that owns

> make ?? work on Optionals that own as #250

**Claude** made `x ?? y` work where the value owns, as a String's. `x`
is read once; a variable keeps its value and gives a copy, and one an
expression gives, as `d.lastKey(v)`, has it taken out. `y` is made
only where it is needed, copied where it is a variable. A `y` of
another type is now Kelvin's error, not C's. Details are provisional
P262.

There are 879 tests, and all pass with clang and with gcc 15.

### 295. ?? groups right to left

> make ?? right-associative as #251

**Claude** made `??` and `!!` group right to left, as Swift's `??`:
`p ?? o ?? $"z"` is the first value of the chain, or `"z"`. Every
`x ?? y` now checks `y` against the value's type, so `a ?? b` of two
`i64?`, which C refused, is Kelvin's error that names the types.
Details are provisional P263.

There are 881 tests, and all pass with clang and with gcc 15.

### 296. a ?? b of two Optionals

> make a ?? b of two Optionals give an Optional as #252

**Claude** made `a ?? b` of two Optionals of one type, and `a ?? none`,
give that Optional, as Swift's: `a` where it has a value, else `b`. A
`b` of the value's type still gives the value, so `a ?? b ?? 0` is an
`i64`. Owners are copied where they are variables, else taken. A `b`
of another type is an error that names both types it could be.
Details are provisional P264.

There are 882 tests, and all pass with clang and with gcc 15.

### 297. r ?? r2 of two Results

> make r ?? r2 of two Results give a Result as #253

**Claude** made `r ?? r2` of two Results of one type give that Result,
`r` where it is ok, else `r2`, as #252 does for Optionals. A Result
that owns, by its value or by its err, is copied where it is a
variable, else taken, and a taken one that is err is freed. Details
are provisional P265.

There are 884 tests, and all pass with clang and with gcc 15.

### 298. r ?? ok(v) and r ?? err(e)

> make r ?? err(e) and r ?? ok(v) work as #254

**Claude** made `ok(v)` and `err(e)` after `??` of a Result make a
Result of its type, as where a Result is expected, so `r ?? ok(0)` is
`r` where it is ok, else `ok(0)`, as #253's `r ?? r2`. Details are
provisional P266.

There are 885 tests, and all pass with clang and with gcc 15.

### 299. Declarations and assignments check the value's type

> make declarations and assignments check the value's type as #255

**Claude** made `var n:i64 = v`, `n = v` and `p.x = v` check `v` as
`d[k] = v` does (#246): text for a number, or a number for a String,
is Kelvin's error, `'n' is an i64, and this is text`. A number still
takes any number. C's own types, as `size_t`, and functions are left
to C. Details are provisional P267.

There are 889 tests, and all pass with clang and with gcc 15.

### 300. Array elements check the value's type

> make Array elements check the value's type as #256

**Claude** made an element of an Array check its type as #255's values
do: in a typed `$[...]`, by `xs[i] = v`, and by `append`, `+=` and
`insert`, so `ws.append(3)` of an `Array<String>` is Kelvin's error,
`an element of Array<String> is a String, and this is a number`. One
element given to `append`, `+=` or `insert` is now converted as a
declaration's value is: `ws.append("lit")` and `os.append(4)` of an
`Array<i64?>` work, where C refused them. Details are provisional P268.

There are 893 tests, and all pass with clang and with gcc 15.

### 301. Arguments check the value's type

> make arguments check the value's type as #257

**Claude** made each argument of a Kelvin function or method check
its parameter's type, once converted and lent, as #255's values do:
`half("ten")` is Kelvin's error, `'x' of 'half' is an f64, and this is
text`. Where a borrow is taken and the value itself is given, it says
to write `&`. Details are provisional P269.

There are 896 tests, and all pass with clang and with gcc 15.

### 302. A float's text pastes back

> CHANGE IT! FIX IT!  The whole point of print is to print the value so
> that when it is pasted back to a kelvin source code, it "just works"
> as expected.

**Claude** had noted, with #256, that `$[1.0, 2.5]` printed `[1, 2.5]`
while `1.0` alone printed `1.0`. The text of a value, `.cstr`, which
an Array's, a struct's, an Optional's and a Dictionary's text is made
of, used `%.17g`: `1` for `1.0`, and `0.10000000000000001` for `0.1`.
As #258 it now uses print's own formatter, the shortest text that
reads back as the same value, with a point: `[1.0, 2.5]`, `{x: 1.0}`,
`some(1.0)`, `0.1.cstr` is `0.1`. Details are provisional P270.

There are 896 tests, and all pass with clang and with gcc 15.

### 303. Quoted text, and every digit of a float

> quote cstr members when printing as #259.  Also, printing `$[0.1]` as
> `[0.1]` is WRONG.  It should remain `[0.10000000000000001]` because
> that is what `0.1` REALLY is, `+0x1.999999999999ap-4`.

**Claude** asked whether a float alone, `println(0.1)`, should show
every digit too, and the user chose so: one text for a float, every
digit its type holds, with a point, `0.10000000000000001`, `[1.0]`,
`0.100000001` of an f32. Text inside a value of a type only C sees, as
`xmlChar^` or `name_t`, is now quoted as a cstr's already was, and a
null one is `nullptr`. Details are provisional P271.

There are 896 tests, and all pass with clang and with gcc 15.

### 304. A null pointer prints nullptr

> print null pointers as nullptr as #260.   Also `0x0` is a `0:i64` which
> IS NOT `0x0p0` which is `0.0:f64`.  `nan` and `inf` are kelvin
> literals.  exactly speaking, `$/nan/i` and `$/inf(:?inity)?/i` are
> kevin literals of type `f64`.  You can convert types as `nan:f32` but
> `(0.0/0.0) as f32` might be more intuitive.

**Claude** made a null pointer print `nullptr`, by `print`, `.cstr`,
`${p}` and inside a value, a null cstr's too, where it was `0x0` or
`(null)`. `.addr` and `.hex` keep their numbers. Claude found that
kelvinc does not read `nan` and `inf` yet, `let a = nan` asking for a
type, so the text "nan" and "inf" is right but does not read back.
Details are provisional P272.

There are 896 tests, and all pass with clang and with gcc 15.

### 305. nan and inf are literals

> please!

**Claude** had asked, after #260, whether to make `nan` and `inf` the
literals of `f64` the user had described, which kelvinc did not read.
As #261, `nan`, `inf` and `infinity`, in any case, are literals of
`f64`: `let x = -inf`, `$[nan, inf]`, `nan:f32`; so what print shows of
a NaN or an infinity reads back. A name the program declares stays
its own, and `nan(...)` stays C's function. Details are provisional
P273.

There are 897 tests, and all pass with clang and with gcc 15.

### 306. kc reads floats, nan and inf

> teach kc nan and inf as #262

**Claude** found that kc had no floats at all, and asked how far to go;
the user chose `float64` with `nan` and `inf`. kc now reads `1.5`,
`2.5e-8`, `nan`, `inf` and `infinity`, declares and infers `float64`,
computes and compares with it, converts with `as`, and prints it as
kelvinc does; sample.k prints floats, so the bootstrap checks them.
Details are provisional P274. #261's grammar pattern, which Node on
Linux could not compile, now spells each letter's two cases.

There are 897 tests, and all pass with clang and with gcc 15.

### 307. kc reads float32

> teach kc float32 as #263

**Claude** gave kc `float32`, C's `float`, beside #262's `float64`: of
a literal, `let x:float32 = 0.1`, or `as float32`, computed, compared,
held in an Array, a struct or an Optional, and printed as kelvinc
prints it, `0.100000001`. sample.k prints them, so the bootstrap checks
them. Details are provisional P275.

There are 897 tests, and all pass with clang and with gcc 15.

### 308. kc reads x:T

> teach kc x:T annotations as #264

**Claude** taught kc kelvinc's annotation `x:T`, a conversion as
`x as T` is: `0.1:float32`, `'z':uint8`, `c ? 1:int64 : 0`. The `:` is
an annotation where one of kc's type words follows with no `(` or `<`
after it; else it is a ternary's or a case's, as before. sample.k
prints annotations, so the bootstrap checks them. Details are
provisional P276.

There are 897 tests, and all pass with clang and with gcc 15.

### 309. kc reads p:point and n:size_t

> teach kc struct and typedef annotations as #265

**Claude** taught kc `x:T` of a struct's name or a C typedef's,
`p:point`, `n:size_t`. As kelvinc reads it, a name after `:` in the
middle of `c ? a : b` or in a case's values is the `?:`'s or the case's,
and in parentheses or a call's arguments there an annotation again.
sample.k prints one, so the bootstrap checks it. Details are
provisional P277.

There are 897 tests, and all pass with clang and with gcc 15.

### 310. kc reads $[a, b]

> teach kc Array literals $[a, b] as #266

**Claude** taught kc `$[a, b]`, which had `$[]` alone: an Array of its
elements' one type, as kelvinc's, or of the type written, each element
converted, text into a String and `{a, b}` into a struct. Elements of
more than one type are an error, and so is an owner a variable holds.
They nest, and are freed as any owner an expression gives. sample.k
prints them, so the bootstrap checks them. Details are provisional
P278.

There are 897 tests, and all pass with clang and with gcc 15.

### 311. kc reads ${k: v}

> teach kc Dictionary literals ${k: v} as #267

**Claude** taught kc `${k: v}`, which had `${:}` alone: a Dictionary of
the first entry's types, a text key a String's, or of the type
written; keys or values of more than one type are kelvinc's errors,
word for word. Nesting them showed that kc named an Array's or a
Dictionary's element without containers, `_kv_dict_String_unknown`,
and an Optional of a float or of a Dictionary as `_kv_opt_T`, one for
both; each is now named as kelvinc mangles it. kc does not yet print a
Dictionary whole, nor walk one with `for k, v in d`. Details are
provisional P279.

There are 897 tests, and all pass with clang and with gcc 15.

### 312. kc prints Dictionaries

> teach kc to print Dictionaries as #268

**Claude** taught kc to print a Dictionary as kelvinc does,
`{"ann": 31}`, `{}` where empty, its entries in the order added and a
String key quoted, nested in an Array, a Dictionary or an Optional.
On the way kc took kelvinc's rule that an empty `${:}` or `$[]` value
of `${k: v}` takes the first's type. sample.k prints Dictionaries
whole, so the bootstrap checks them. Details are provisional P280.

There are 897 tests, and all pass with clang and with gcc 15.

### 313. kc walks Dictionaries

> teach kc for k, v in d as #269

**Claude** taught kc `for k, v in d`, each key and its value, and
`for k in d`, each key, in the order added, as lets the Dictionary
owns; a Dictionary an expression gives is held for the loop. Two names
over an Array are kelvinc's error. sample.k walks Dictionaries, so the
bootstrap checks it. Details are provisional P281.

There are 897 tests, and all pass with clang and with gcc 15.

### 314. kc removes entries

> teach kc d.remove(k) as #270

**Claude** taught kc `d.remove(k)`, as kelvinc has it: the entry gone,
what it held freed, `true` where it was there. A String key an
expression gives, as in `d.has($"a")`, made C refuse the address of a
temporary, for `has` and `get` too; it is now held for the call. kc
does not yet refuse changing a let, as kelvinc does of `remove`.
Details are provisional P282.

There are 897 tests, and all pass with clang and with gcc 15.

### 315. kc refuses changing a let

> teach kc to refuse changing a let as #271

**Claude** taught kc kelvinc's rule that a let does not change:
assigning it, `+=`, its member or element, `pop` or `remove` of it, is
an error in kelvinc's words, which name a let, a let parameter, each
element in turn, or a range's count; fifteen cases give the same
words. kelvinc tells one to write `var n` in a parameter list, so kc
now takes `var` parameters too. Details are provisional P283.

There are 897 tests, and all pass with clang and with gcc 15.

### 316. kc's borrow of a let is const

> teach kc &x of a let as a const borrow as #272

**Claude** taught kc that `&x` of a let is a `const T^`, as kelvinc
types it: a change through it is an error, and it goes where a
`const T^` goes. kc found a hole in kelvinc: a let that owns is no C
const, so `&s` of a let String goes where a `String^` goes and is
changed there, `abc!`, and kelvinc has no `const $[T]^`. kc does as
kelvinc does of an owner's borrow, so that a program builds with both,
and refuses a scalar's, where kelvinc's C warns. Details are
provisional P284.

There are 897 tests, and all pass with clang and with gcc 15.

### 317. A let that owns borrows as const

> fix the let owner hole in kelvinc as #273

**Claude** made `&s` of a let that owns a `const T^`, as a let of a
number's is: it goes where a `const T^` goes, and a `T^` that may change
it is Kelvin's error, so `shout(&s)` no longer changes a let String.
A function that only reads writes `xs:const $[i64]^`, now allowed, or
`const Dictionary<K, V>^`, `const String^`, `const Set<T>^`; a change
through any read-only borrow is Kelvin's error, where C's warning was
all there was. No test, module or example changed a let so. kc does the
same, in the same words. Details are provisional P285.

There are 903 tests, and all pass with clang and with gcc 15.

### 318. kc reads Sets

> teach kc const Set<T>^ borrows as #274

**Claude** found that kc had no Set at all, and asked how far to go;
the user chose the basics with the borrow. kc now has `Set<T>` of
integers or Strings, as kelvinc: `${a, b}`, `${}`, `{a, b}` where the
type is written, `insert`, `+=`, `has`, `remove`, `count`, `copy`,
`for x in s`, printing; a let's does not change, and `const Set<T>^`
borrows one that reads, in kelvinc's words. sample.k has Sets, so the
bootstrap checks them. Details are provisional P286.

There are 903 tests, and all pass with clang and with gcc 15.

### 319. kc's Set algebra

> teach kc Set union, intersection and difference as #275

**Claude** taught kc `s.union(&t)`, `s.intersection(&t)` and
`s.difference(&t)`, new Sets of a borrow of another of the same
elements, as kelvinc; another argument is kelvinc's error, word for
word. A Set an expression gives is held as any receiver is. sample.k
uses them, so the bootstrap checks them. Details are provisional P287.

There are 903 tests, and all pass with clang and with gcc 15.

### 320. kc's | & ~

> teach kc Set operators | & ~ as #276

**Claude** taught kc `s | t`, `s & t` and `s ~ t` of two Sets in
variables, and `|=`, `&=`, `~=` in place, as kelvinc, in its words; of
numbers they are bitwise, `~` the XOR, at C's precedence. Probing
kelvinc found that it crashes on `s |= &t`, reading the name of a
pointer type; kc gives the error kelvinc means. sample.k uses them, so
the bootstrap checks them. Details are provisional P288.

There are 903 tests, and all pass with clang and with gcc 15.

### 321. s |= &t no longer crashes kelvinc

> fix the s |= &t crash in kelvinc as #277

**Claude** made `s |= &t`, `s &= &t` and `s ~= &t` the error kelvinc
meant, `'|=' takes another Set<i64>, in a variable`, where kelvinc
crashed reading the name of a pointer type. The other operators of a
borrow already said so. Details are provisional P289.

There are 904 tests, and all pass with clang and with gcc 15.

### 322. kc has a Set's elements

> teach kc Set elements as #278

**Claude** taught kc `s.elements`, an Array of copies of a Set's
elements in the order added, as kelvinc makes it. It works on a Set in
a variable, on a temporary, and through a borrow. kc builds
`return s^.elements`, which kelvinc wrongly refuses. Details are
provisional P290.

There are 904 tests, and all pass with clang and with gcc 15.

### 323. The goals of self-hosting

> before fixing return s^.elements in kelvinc as #279, let's be clear of
> our definition and goal of self-hosting: [...] Our short-term goal is
> to make `kc` as capable as `kelvinc` [...] Our mid-term goal is to free
> ourselves from C source emission. [...] And the (very) long-term goal
> is like go and even C which builds entire backend by kelvin

> write the goals into selfhost/README.md as #279

**Claude** pointed out what stands in the way of the mid term: kc.k
imports C's headers, kc passes names it does not know to C, and its C
uses kelvin_prelude.h's macros, with no step between the tree and the
C. Then it wrote the goals into selfhost/README.md. Details are
provisional P291.

There are 904 tests, and all pass with clang and with gcc 15.

### 324. A property that makes an owner is returned

> fix return s^.elements in kelvinc as #280

**Claude** found that the same check also refused returning an IO's
`string`, `bytes`, `abspath`, `basename`, `dirname`, `listdir` and
`walk`, and `.pretty` of an Array, a Dictionary or a Set, and asked how
wide the fix should go. The user chose all of them. kelvinc now takes a
property whose value is an owner as new, not as text in a buffer of the
function. Details are provisional P292.

There are 905 tests, and all pass with clang and with gcc 15.

### 325. kelvinc -c, and linking objects

> Before fixing "a" + "b" of literals in kelvinc as #281, I have a few
> questions: does `kelvinc` support `-c` option to emit `.o`? and act as
> a (proxy of) linker like `kelvinc final_product -o *.o`? if not, add
> support to it, as `selfhost/kc` already does.

**Claude** answered that neither compiler did: kelvinc took one source
and objects only with `--lib`, and kc's `-c file.c` kept its C. It asked
how to spell the options and what to cover first. The user chose `-c`
for an object in both, kc's `--emit-c` for its C, kelvinc's linking
first, and this as #281. kelvinc now makes objects and links them, with
a source or alone; kc makes objects that kelvinc links. Details are
provisional P293.

There are 907 tests, and all pass with clang and with gcc 15.

### 326. Only a String has +

> fix "a" + "b" of literals in kelvinc as #282

**Claude** found that `"a" + 1` ran, stepping past the text, and that
`"a" - "b"` and `x - y` of cstrs gave a difference of unrelated
addresses, and asked what `"a" + "b"` should be. The user answered
that `$"a" + $"b"` is `String("ab")`, that `+` of two `char *` is an
error, as only `String` has `+`, and that the steps are #52's error.
kelvinc now says so for each. Details are provisional P294.

There are 912 tests, and all pass with clang and with gcc 15.

### 327. kc refuses "a" + "b"

> teach kc to refuse "a" + "b" as #283

**Claude** gave kc kelvinc's check of `+` and `-` of a cstr, which kc
lacked, #52's too, with kelvinc's words for each case. It found that kc
has no `+` of Strings either. Details are provisional P295.

There are 912 tests, and all pass with clang and with gcc 15.

### 328. kc has + of Strings

> teach kc + of Strings as #284

**Claude** taught kc `s + t` of Strings, as kelvinc has it: a new String,
of a String, a cstr or a uchr on either side, with kelvinc's C and its
words for the wrong sides. A variable infers its type. Details are
provisional P296.

There are 912 tests, and all pass with clang and with gcc 15.

### 329. kc has a Dictionary's keys and values

> teach kc Dictionary keys and values as #285

**Claude** taught kc `d.keys` and `d.values`, Arrays of copies as
kelvinc makes them, sharing the code of a Set's `elements`. It found
that kc returns no body's value, `{ 7 }`, and writes a function that
returns nothing. Details are provisional P297.

There are 912 tests, and all pass with clang and with gcc 15.

### 330. kc returns a body's value

> teach kc to return a body's value as #286

**Claude** taught kc kelvinc's #26: a function with a result whose body
is one expression returns it, with kelvinc's errors, in its words, for
an assignment there, a call with no value, and a value dropped at the
end of a longer body or of main. It found that kc lets `$[1] + 2` reach
C. Details are provisional P298.

There are 912 tests, and all pass with clang and with gcc 15.

### 331. kc refuses + of an Array

> teach kc to refuse + of an Array as #287

**Claude** gave kc kelvinc's check of the operators of an Array, a
Dictionary and a Set, which refuses `$[1] + 2` and its kind in
kelvinc's words. It found that kc has no `==` of Arrays or Dictionaries,
and that its `??` message is not kelvinc's. Details are provisional
P299.

There are 912 tests, and all pass with clang and with gcc 15.

### 332. kc has == of Arrays and Dictionaries

> teach kc == of Arrays and Dictionaries as #288

**Claude** taught kc `==` and `!=` of Arrays and Dictionaries with
kelvinc's C, a T_eq function of each type compared, and kelvinc's
errors, in its words. It found that a comparison in a condition reached
C past #287's check, and fixed that too. Details are provisional P300.

There are 912 tests, and all pass with clang and with gcc 15.

### 333. The runtime begins in Kelvin

> Can you write more part of kelvinc in kelvin? so far 100% of `src/`
> and `runtime/` is in `.c` but some of the prelude can be diverted to
> `.k`.

**Claude** surveyed the runtime: the String and Bytes algorithms, the
OS module and the RegExp engine could be Kelvin, while the prelude's
container macros are C's generics, the compiler's to replace. It found
two things in the way: kelvinc refuses `kv_` names, and a library's
functions are named by their types, where the C kelvinc writes calls
the runtime by fixed names.

> add the runtime-build mode and runtime/string.k as #289

**Claude** added `kelvinc --runtime`, an object of the runtime with its
`kv_` names, and moved a String's find, has, starts, ends and trim from
runtime/string.c into runtime/string.k, which make builds into
libkelvin. They print the same as the C did. Details are provisional
P301.

There are 914 tests, and all pass with clang and with gcc 15.

### 334. More of the runtime in Kelvin

> move String escape/unescape and base64 to Kelvin as #290

**Claude** moved a String's escape and unescape into runtime/string.k
and Base64 into a new runtime/bytes.k, which print the same as the C
did. On the way it found that `Bytes(&s)` of a String gives garbage,
that a literal `"\u{7f}"` reaches C, and that escape stops at a NUL, as
the C did. Details are provisional P302.

There are 915 tests, and all pass with clang and with gcc 15.

### 335. Bytes(&s) of a String

> fix Bytes(&s) of a String in kelvinc as #291

**Claude** found that KV_BYTES_OF had no case of a String, so
`Bytes(&s)` read the String's own fields as text, and gave it one, a
function written in Kelvin in runtime/bytes.k. `Bytes(s)` now names
`Bytes(&s)` in its message. Details are provisional P303.

There are 917 tests, and all pass with clang and with gcc 15.

### 336. A literal's \u{7f}

> fix the "\u{7f}" literal reaching C as #292

**Claude** found that every `\u` escape reached C as C's own, which
refuses a control character, so `print`'s `\u007f` did not paste back
either. kelvinc now writes each as the codepoint's UTF-8 bytes, and says
so of a surrogate, one past 10FFFF and a malformed escape. Details are
provisional P304.

There are 920 tests, and all pass with clang and with gcc 15.

### 337. kc reads \u escapes

> teach kc \u escapes in literals as #293.

**Claude** taught kc kelvinc's \u escapes, written as UTF-8 bytes, with
kelvinc's errors. It found that `(n + 1).uchr` reaches C in kelvinc.
Details are provisional P305.

There are 920 tests, and all pass with clang and with gcc 15.

### 338. What stays out on purpose

> Also let me answer some of the todos listed in versusC.md. we have
> `typealias` so we don't need `typedef` Mark it as an error in
> kelvin's context. `long double` is terribly meaningless in C. [...]
> `f128` stays in the wishlist. string prefixes (`L"..."`) shall not be
> supported. kelvin sources are always in valid utf-8 without BOM. [...]
> Our supports for generics are kept deliberately shallow. [...]
> `#inline C { ... }` must not contain C preprocessors and Kelvin
> preprocessing directives shall not be nestable.

**Claude** found what kelvinc did of each: a typedef was a generic
error, `L"..."` and a BOM were too, a source of invalid UTF-8 compiled,
and `#inline C` held `#include` and `#define`, which tests use. It
proposed one number each.

> make typedef an error naming typealias as #294

**Claude** made `typedef` an error that names `typealias`, at the top
level and in a body, and wrote the answers into versusC.md, "Left out
on purpose". Details are provisional P306.

There are 922 tests, and all pass with clang and with gcc 15.

### 339. A source is UTF-8

> refuse string prefixes, BOMs and invalid UTF-8 as #295

**Claude** made a BOM, a byte that is no UTF-8, and C's string and
character prefixes errors that say so, at the line and column where
each stands. Its own test of #290 had printed bytes that are no UTF-8
into its expected output, which it now prints escaped. Details are
provisional P307.

There are 926 tests, and all pass with clang and with gcc 15.

### 340. No preprocessor in #inline C

> refuse preprocessor lines in #inline C as #296

**Claude** made a `#` that begins a line of an #inline C block an error,
which names Kelvin's directives as not nesting and the rest as C's
preprocessor, left out. Two tests used `#include` and `#define` there,
and now import the header outside and write their constants as C's
own. Details are provisional P308.

There are 930 tests, and all pass with clang and with gcc 15.

### 341. A number's properties

> fix (n + 1).uchr reaching C as #297

**Claude** found that `(n + 1).size` and `n.utf32` reached C by the same
rule, and asked how wide the fix should go. The user chose all three.
kelvinc now takes a receiver it sees is a number for no struct:
`(n + 1).uchr` converts it, `(n + 1).size` is its sizeof, and `.utf32` of
a number is an error that names `.uchr`. Details are provisional P309.

There are 933 tests, and all pass with clang and with gcc 15.

### 342. kc reads UTF-8 alone

> teach kc to refuse BOMs, invalid UTF-8 and prefixes as #298

**Claude** had kc read a file's bytes first, with C's stdio, as IO's
`.string` ended kc in the runtime's words where a file was no UTF-8, and
refuse a BOM, such a byte and C's prefixes as kelvinc does, in its
words. Details are provisional P310.

There are 933 tests, and all pass with clang and with gcc 15.

### 343. A String holds a NUL

> Resolve the `"\x00mid".unescape().escape()` issue. Though
> `"\x00mid"` is an invalid `cstr`, it must be valid as a `String`

**Claude** found that a String literal stopped at a NUL, as C's strlen
does, and so did escape() and unescape(). A literal made a String is
now every byte of it, by C's sizeof, escape() writes a NUL as `\u{0}`,
and unescape() reads past one; a cstr still stops at it. Details are
provisional P311.

There are 934 tests, and all pass with clang and with gcc 15.

### 344. kc escapes and unescapes

> teach kc escape and unescape as #300

**Claude** taught kc a String's `escape()` and `unescape()`, calls of the
runtime's, written in Kelvin, as kelvinc makes them. Details are
provisional P312.

There are 934 tests, and all pass with clang and with gcc 15.

### 345. libkOS from Kelvin

> "move OS module to Kelvin as #301" do you mean to rewrite it in
> Kelvin?

**Claude** answered that it does: runtime/os.c's 872 lines rewritten in
Kelvin, function by function, checked against the C. It found two
platform conditionals, of which the generated C covers one, and
proposed a first group.

> build libkOS from Kelvin with a first group as #301. One request.
> move `SYS` to the prelude so you can use it without `#import <OS>`.

**Claude** wrote runtime/os.k, twenty of OS's functions over libc, which
make builds into libkOS beside runtime/os.c, and a program of each
prints the same as the C did. Moving SYS to the prelude is to be #302.
Details are provisional P313.

There are 935 tests, and all pass with clang and with gcc 15.

### 346. SYS is the prelude's

> move SYS to the prelude as #302

**Claude** moved SYS from libkOS into libkelvin, its declarations into
kelvin_prelude.h, and had kelvinc ask no import for it, with main
giving it the program's arguments where the program names it. Details
are provisional P314.

There are 935 tests, and all pass with clang and with gcc 15.

### 347. OS's stat in Kelvin

> move OS stat and existence checks to Kelvin as #303

**Claude** moved OS's stat, lstat and the four existence checks into
runtime/os.k, holding C's `struct stat` as `var st:struct stat`, and a
program of each prints the same as the C did. Details are provisional
P315.

There are 936 tests, and all pass with clang and with gcc 15.

### 348. SYS's own document

> Split the document on SYS to sys.md then commit and push to main

**Claude** moved SYS's section, its members, its row of the table and
the word on its text from os.md into a new documents/sys.md, with an
example of its own, which the documents' check builds, and pointed
os.md, the documents' index, properties.md, versusC.md and modules.md
at it. OS's document is OS's alone.

There are 936 tests, and all pass with clang and with gcc 15.

### 349. OS's directories in Kelvin

> move OS directories, walk and glob to Kelvin as #304

**Claude** moved OS's listdir, walk and glob into runtime/os.k, building
Kelvin Arrays and handing their Strings over in the buffer kOS.h's
interface has, so that neither the C kelvinc writes nor io.c changed. A
tree of awkward names prints the same as the C did. Details are
provisional P316.

There are 937 tests, and all pass with clang and with gcc 15.

### 350. OS's users and groups in Kelvin

> move OS users and groups to Kelvin as #305

**Claude** moved OS's user, username, groupname, groups, chown and lchown
into runtime/os.k, and a program of each prints the same as the C did.
Details are provisional P317.

There are 938 tests, and all pass with clang and with gcc 15.

### 351. OS's paths in Kelvin

> move OS paths to Kelvin as #306. then add `.flatMap()` to `Array`,
> `Dictionary`, and `Set` so they are officially monads. `Set` is yet to
> have `.map()`, `.filter()`, and `.reduce()` so let it have them, too.

**Claude** moved OS's ten path functions into runtime/os.k, and they
print the same as the C did. On the way libkOS failed to link: a call
before a Kelvin definition of a name kOS.h declares had made the
definition an overload, under another name. Details are provisional
P318.

There are 939 tests, and all pass with clang and with gcc 15.

### 352. A Set's map, filter and reduce

> give Set map, filter and reduce as #307

**Claude** asked how a Dictionary's flatMap should merge, and the user
chose a later entry winning, as `d[k] = v`, and #307 and #308 for the
two halves. Then it gave a Set map, filter and reduce, as an Array has
them, map's result a Set of integers or Strings. Details are
provisional P319.

There are 942 tests, and all pass with clang and with gcc 15.

### 353. flatMap: Arrays, Dictionaries and Sets as monads

> add flatMap to Array, Dictionary and Set as #308

**Claude** gave the three flatMap: an Array's results concatenated, a
Dictionary's merged with a later entry winning, and flatMapWithKey, a
Set's unioned. A test checks the monad laws of each. Details are
provisional P320.

There are 945 tests, and all pass with clang and with gcc 15.

### 354. OS's processes and time in Kelvin

> move OS processes and time to Kelvin as #309

**Claude** moved OS's system, time, sleep and the setting of a file's
times into runtime/os.k, and they print the same as the C did. It kept
environ in C: Kelvin cannot declare C's `char **environ` as libc may.
Details are provisional P321.

There are 946 tests, and all pass with clang and with gcc 15.

### 355. OS's temporary files in Kelvin

> move OS temporary files to Kelvin as #310

**Claude** moved OS's tmpdir, mkstemp and mkdtemp into runtime/os.k,
and they print the same as the C did, whatever TMPDIR holds. On the
way it found that kelvinc lets a call without a result reach C as an
argument, and left that for a later number. Details are provisional
P322.

There are 947 tests, and all pass with clang and with gcc 15.

### 356. OS's system information in Kelvin

> move OS system information to Kelvin as #311, then add `async` and
> `await` to the prelude.

**Claude** moved OS's host, uname, cpus, loadavg, terminalsize and
diskusage into runtime/os.k, and they print the same as the C did,
piped and on a terminal. `async` and `await` wait for their own
number. Details are provisional P323.

There are 948 tests, and all pass with clang and with gcc 15.

### 357. async and await

> add async and await to the prelude as #312

**Claude** asked three questions first: what runs a task, how it is
spelled, and what it may take from around it. The user chose an OS
thread each, `async` giving a `Task<T>` that `await` waits for, and
copies and moves only. **Claude** first made `async { ... }` a block
whose names around it were passed in.

> Your implementation needs a closure because `async` is a block.
> limiting `async` to functions makes it unnecessary. Now where do you
> think is the best do declare function `async`?

**Claude** suggested marking the call, `async f(x)`, not the function:
the function stays ordinary, and its arguments pass as any call's.
`await async fib(30)` works, waiting at once.

> rework #312 to async f(x)

**Claude** reworked it so, with the Task's runtime in Kelvin, in
runtime/task.k. Details are provisional P324.

There are 964 tests, and all pass with clang and with gcc 15.

### 358. kc's async and await

> teach kc async and await as #313

**Claude** taught kc `async f(x)`, `await t` and `Task<R>`, as kelvinc
reads them, and kc's build of a probe and of sample.k prints what
kelvinc's prints. kelvinc now names `Task<i64>` `Task_i64` in C. On the
way it found that kc's `d[k] = v` of a String key an expression gives
does not compile, and left that for a later number. Details are
provisional P325.

There are 964 tests, and all pass with clang and with gcc 15.

### 359. kc's expression keys

> fix kc's d[k] = v of an expression key as #314

**Claude** made kc hold a String key an expression gives in `d[k] = v`,
the checked `d[k]` and `d[k]` read whole, as it held one for `d.has(k)`,
and kc's builds print as kelvinc's. On the way it found that kelvinc
refuses `s += f()` of a Set of Strings, which kc takes, and left that
for a later number. Details are provisional P326.

There are 964 tests, and all pass with clang and with gcc 15.

### 360. kelvinc's held Set elements

> fix kelvinc's s += f() of a Set<String> as #315

**Claude** made kelvinc hold a String an expression gives in `s += f()`,
and in `${f()}` and `${f(): v}` where their type is written, as it held
one in `s.insert(f())`. Details are provisional P327.

There are 965 tests, and all pass with clang and with gcc 15.

### 361. kelvinc's void call as an argument

> fix kelvinc's void call as an argument as #316

**Claude** made kelvinc refuse an argument it sees has no value, a call
of a function or method with no result, a built-in method with none and
`await` of a Task with none, which C's compiler had refused in its own
words. Details are provisional P328.

There are 969 tests, and all pass with clang and with gcc 15.

### 362. kc's void argument

> teach kc to refuse a void argument as #317

**Claude** taught kc kelvinc's error of #316: an argument kc sees has no
value, a call with no result, a built-in method with none or `await` of
a Task with none, is refused in kelvinc's words. Details are
provisional P329.

There are 969 tests, and all pass with clang and with gcc 15.

### 363. Iterators

> I want an iterator so we can go like `for elem in iter {...}`. What
> style should we pick? JavaScript style or Swift style or anything
> else?

**Claude** suggested Swift's: a value whose `next()` gives a `T?`,
`none` ending the loop, since Kelvin has Optionals and finds a list by
its shape already. JavaScript's `{value, done}` is an Optional built by
hand, Python's ends with an exception, and generators need coroutines.
It asked how `next()` changes its iterator, a method's `self` being a
let, and whether Swift's `Sequence` comes too.

> add Swift-style iterators as #318

The user chose `var T.next()`, Kelvin's var where Swift says
`mutating`, and the iterator alone. **Claude** added var methods,
whose `self` is the caller's var, and `for x in it`, which calls
`next()` until `none` and leaves a var where it stopped. Details are
provisional P330.

There are 978 tests, and all pass with clang and with gcc 15.

### 364. A document of iterators, and their map, filter, reduce, flatMap

> iterator deserves a document of its own. write `iterators.md`. And
> since it is a sequence it should be equipped with `.map`,`.filter`,
> `.reduce`, and `.flatmap`.

**Claude** wrote documents/iterators.md, and gave an iterator `map`,
`filter`, `reduce` and `flatMap`, as Kelvin spells it elsewhere: eager,
as Swift's `Sequence` methods are, each walking the iterator to its end
and giving what an Array's gives. The values are gathered into an Array
first, so every `next()` runs before the first function. Details are
provisional P331.

There are 981 tests, and all pass with clang and with gcc 15.

### 365. kc's iterators and var methods

> teach kc iterators and var methods as #320

**Claude** taught kc var methods, whose `self` is the caller's var, and
`for x in it` over an iterator, as kelvinc writes them, with kelvinc's
errors in its words; a let method that changes `self`, which kc had let
through, is refused now too. The iterator's `map` and the rest wait for
kc's anonymous functions. Details are provisional P332.

There are 981 tests, and all pass with clang and with gcc 15.

### 366. Sequences

> add Sequence and makeIterator as #321

**Claude** added Swift's `Sequence`: a value whose let `makeIterator()`
gives a fresh iterator, which `for` and `map`, `filter`, `reduce` and
`flatMap` walk, so the Sequence stays as it was, a let too, and is
walked afresh each time. A value with both `makeIterator` and `next` is
a Sequence, as in Swift's `for`. Details are provisional P333.

There are 984 tests, and all pass with clang and with gcc 15.

### 367. kc's Sequences

> teach kc Sequence and makeIterator as #322

**Claude** taught kc a `for` over a Sequence, as kelvinc writes it: the
call `s.makeIterator()`, a fresh iterator held for the loop, so the
Sequence stays as it was, with kelvinc's errors in its words. A
Sequence's `map` and the rest wait for kc's anonymous functions.
Details are provisional P334.

There are 984 tests, and all pass with clang and with gcc 15.

### 368. Lazy map and filter

> give Sequence lazy map and filter as #323

**Claude** added Swift's `s.lazy.map(f)` and `s.lazy.filter(f)`: a lazy
Sequence, whose iterator calls `f` only as each value is asked for, so
nothing is gathered, a `break` stops it, and an endless Sequence is
walked in part. Its own `map` and `filter` stay lazy and chain; its
`reduce` and `flatMap` are eager. Printing one is an error, since its
text would not paste back. Details are provisional P335.

There are 990 tests, and all pass with clang and with gcc 15.

### 369. kc's lazy map and filter, and its anonymous functions

> teach kc lazy map and filter as #324

**Claude** asked how, as kc had no anonymous functions, and the user
chose to teach kc both in one number. kc reads `{ $0 * 2 }` and
`{ (n:int64):int64 in ... }` as the function of `.lazy.map` and
`.lazy.filter`, writing each as a function of its own, and makes a lazy
Sequence's structs and functions as kelvinc does, with kelvinc's errors
in its words. Details are provisional P336.

There are 990 tests, and all pass with clang and with gcc 15.

### 370. Iterator<T>, a state and a function

> I'm considering redesigning iterator. Instead of extending `struct`,
> `enum`, or `union` with `.next()`, add the `Iterator<T>` type with the
> constructor like Swift's `sequence(state, next)`.

**Claude** found it fits Kelvin, whose anonymous functions enclose
nothing, since the state comes to the function as `$0`; it suggested
adding it beside the protocol of #318 rather than replacing it, one-shot,
with lazy map and filter as they are, and noted that the example's
`$0 = (a, b)` needs tuples, which Kelvin has none of.

> add Iterator<T> as #325

**Claude** added `Iterator(state) { ... }` and `Iterator(state, f)`: the
state on the heap, `$0` the state itself, `T` what the first `return v`
gives, an owner that `for`, `next()`, `map` and the rest walk. Details
are provisional P337.

There are 998 tests, and all pass with clang and with gcc 15.

### 371. kc's Iterator<T>

> teach kc Iterator<T> as #326

**Claude** taught kc `Iterator(state) { ... }` and `Iterator(state, f)`
as kelvinc writes them: the state on the heap, `$0` the state itself,
`T` what the first `return v` gives, walked by `for` and `next()`, with
kelvinc's errors in its words. kc's lexer now keeps the lines of a `{`
inside parentheses, so a function written there reads as one. On the
way, CI's ASan found #325 leaking an owned state assigned anew, which a
commit of its own fixed. Details are provisional P338.

There are 998 tests, and all pass with clang and with gcc 15.

### 372. An Iterator's lazy map and filter

> give Iterator lazy map and filter as #327

**Claude** gave `Iterator<T>` `it.lazy.map(f)` and `it.lazy.filter(f)`:
an `Iterator<U>` whose state is `it`, moved in, calling `f` only as each
value is asked for. Its type is written, so a function returns a lazy
chain, even of an Iterator that never ends; being a plain Iterator, its
own `map` and `filter` are eager, so a chain writes `.lazy` again.
Details are provisional P339.

There are 1002 tests, and all pass with clang and with gcc 15.

### 373. kc's Iterator lazy map and filter

> teach kc Iterator lazy map and filter as #328

**Claude** taught kc an Iterator's `it.lazy.map(f)` and
`it.lazy.filter(f)` as kelvinc writes them: an Iterator of the Iterator,
moved in, calling `f` as each value is asked for, with kelvinc's errors
in its words; a function trailing a method call's parentheses is now its
last argument. Details are provisional P340.

There are 1002 tests, and all pass with clang and with gcc 15.

### 374. kc's eager map, filter, reduce and flatMap

> teach kc eager map, filter, reduce and flatMap as #329

**Claude** asked which receivers, and the user chose Arrays and
iterators. kc now reads `map`, `filter`, `reduce` and `flatMap` of an
Array, an iterator, a Sequence and an `Iterator<T>` as kelvinc writes
them, gathering an iterator's values into an Array first, its anonymous
functions taking `$0` and `$1`, with kelvinc's errors in its words.
Dictionaries' and Sets' wait. Details are provisional P341.

There are 1002 tests, and all pass with clang and with gcc 15.

### 375. kc's Dictionary and Set map, filter, reduce and flatMap

> teach kc Dictionary and Set map, filter, reduce and flatMap as #330

**Claude** taught kc a Dictionary's and a Set's `map`, `filter`,
`reduce` and `flatMap` as kelvinc writes them, and anonymous functions
whose parameters are named, `{ v in v * 2 }`, with kelvinc's errors in
its words; the WithKey methods wait. Details are provisional P342.

There are 1002 tests, and all pass with clang and with gcc 15.

### 376. kc's mapWithKey, filterWithKey and reduceWithKey

> teach kc mapWithKey, filterWithKey and reduceWithKey as #331

**Claude** taught kc a Dictionary's `mapWithKey`, `filterWithKey` and
`reduceWithKey` as kelvinc writes them, the function taking each key,
a String's as its text, before its value, with kelvinc's errors in its
words; flatMapWithKey waits. Details are provisional P343.

There are 1002 tests, and all pass with clang and with gcc 15.

### 377. kc's flatMapWithKey

> teach kc flatMapWithKey as #332

**Claude** taught kc a Dictionary's `flatMapWithKey` as kelvinc writes
it: the key before the value, the Dictionaries the function gives
merged, a later entry winning, with kelvinc's error in its words.
Details are provisional P344.

There are 1002 tests, and all pass with clang and with gcc 15.

### 378. iterators.md and kc

> update iterators.md for kc's progress as #333

**Claude** replaced the document's Not yet, which held kc's gaps alone,
with a section kc: what kc reads of iterators, Sequences, `Iterator<T>`
and their methods, and where it differs from kelvinc. Details are
provisional P345.

There are 1002 tests, and all pass with clang and with gcc 15.

### 379. kc's anonymous function message

> fix kc's stale anonymous function message as #334

**Claude** made kc's error of an anonymous function where none is taken
name every place kc takes one, the eager methods and their WithKey kin
among them, where it named `.lazy.map`, `.lazy.filter` and an Iterator
alone. Details are provisional P346.

There are 1002 tests, and all pass with clang and with gcc 15.

### 380. dictionaries.md, sets.md and kc

> update dictionaries.md and sets.md for kc's progress as #335

**Claude** gave each a section kc: what kc reads of a Dictionary and of
a Set, what it does not read yet, found by probing kc with each row of
their tables, and where it differs from kelvinc. Details are provisional
P347.

There are 1002 tests, and all pass with clang and with gcc 15.

### 381. kc's Set clear, reserve, pretty and typename

> teach kc Set clear, reserve, pretty and typename as #336

**Claude** taught kc a Set's `.pretty`, its text indented, in place
where print shows it, else a new String; `.typename`; and `.reserve(n)`
and `.clear()`, in place, as kelvinc writes them, so kc reads every row
of sets.md's table. Details are provisional P348.

There are 1002 tests, and all pass with clang and with gcc 15.

### 382. kc's Dictionary find, clear, reserve, pretty and typename

> teach kc Dictionary find, clear, reserve, pretty and typename as #337

**Claude** taught kc a Dictionary's `.find(k)`, a `V^` or `nullptr`,
`const` of a let; `.reserve(n)` and `.clear()`, in place; and
`.pretty` and `.typename`, as kelvinc writes them. On the way it found
that kelvinc binds a let's `find` to a declared `V^` without a word,
which kc refuses. Details are provisional P349.

There are 1002 tests, and all pass with clang and with gcc 15.

### 383. kc's Dictionary merge and merging

> teach kc Dictionary merge and merging as #338

**Claude** taught kc a Dictionary's `merge`, in place, and `merging`, a
new Dictionary, as kelvinc writes them: e's entries added, each value
copied, the function's value where keys meet, else e's, with kelvinc's
errors in its words. Details are provisional P350.

There are 1002 tests, and all pass with clang and with gcc 15.

### 384. kc's Dictionary contains, firstKey and lastKey

> teach kc Dictionary contains, firstKey and lastKey as #339

**Claude** taught kc a Dictionary's `contains`, `firstKey` and
`lastKey`, and their WithKey forms, as kelvinc writes them: whether a
value is there, by `==` or by a function, and the key of the first or
the last, a `K?`, with kelvinc's errors in its words. Found on the way:
kc's `??` takes no Optional that owns, so `d.lastKey(v) ?? $"none"` of
a String key is not kc's yet. Details are provisional P351.

There are 1002 tests, and all pass with clang and with gcc 15.

### 385. kc's ?? of an Optional that owns

> teach kc ?? of an Optional that owns as #340

**Claude** taught kc `x ?? d` of an Optional that owns, as kelvinc
writes it: x's value a copy where x is a place, else taken, and d a
copy where it is a place, else taken, made only where x is none. d of
another type is kelvinc's error in its words, of every `??`. Found on
the way: kc reads `??` left to right, kelvinc right to left (#251), and
kc does not read `let n:int64? = none`. Details are provisional P352.

There are 1002 tests, and all pass with clang and with gcc 15.

### 386. kc's none in let and assignment

> teach kc none in let and assignment as #341

**Claude** taught kc `none`, and `ok(v)` and `err(e)` with it, in a
declaration and an assignment, as it read them in a return: `let
n:int64? = none`, `n = none`, `d[k] = none`. A case the type has not is
kelvinc's error in its words. Found on the way, and fixed: assigning
an Optional that owns, as `xs = $[$"x"]`, wrote C that named a
temporary it had not declared. Details are provisional P353.

There are 1002 tests, and all pass with clang and with gcc 15.

### 387. kc's Array contains, firstIndex and lastIndex

> teach kc Array contains, firstIndex and lastIndex as #342

**Claude** taught kc an Array's `contains`, `firstIndex` and
`lastIndex`, as kelvinc's #248, by the path a Dictionary's took in
#339: whether an element is there, and the index of the first or the
last, an `i64?`, of a value by `==` or of a function. kelvinc's errors
are in its words, and a Dictionary's name on an Array is one. Not yet
kc's: Optional elements by `==`. Found on the way: kc reads
`{ (x ?? 0) > 2 }` as parameters. Details are provisional P354.

There are 1002 tests, and all pass with clang and with gcc 15.

### 388. kc's == of an Optional

> teach kc == of an Optional as #343

**Claude** taught kc `==` and `!=` of an Optional, as kelvinc's #79:
two `none`, or two equal values, the other side a `T?`, a `T` wrapped,
or `none`, each read once and freed where made. An Optional's elements
in an Array, a Dictionary and a search compare too. kelvinc's errors
are in its words; a Result is not yet kc's. Found on the way, and
fixed: `$[$"a", none]` of a `String?`. Found, not fixed: kc does not
read `c ? $"n" : none`. Details are provisional P355.

There are 1002 tests, and all pass with clang and with gcc 15.

### 389. kc's == of a Result

> teach kc == of a Result as #344

**Claude** taught kc `==` and `!=` of a Result, as kelvinc's #79, by
the path an Optional's took in #343: the same case, and equal values,
the other side a Result, a `T` wrapped as `ok(T)`, `ok(v)` or `err(e)`.
A Result's elements in an Array, a Dictionary and a search compare
too. kelvinc's errors are in its words; another enum with values is
not yet kc's. Found on the way, and fixed: a `T` where a Result goes,
in a declaration or a return, reached C unwrapped. Found, not fixed:
kc does not read `$[ok(1)]` or `ok(none)` in a declaration. Details
are provisional P356.

There are 1002 tests, and all pass with clang and with gcc 15.

### 390. kc's == of an enum with values

> teach kc == of an enum with values as #345

**Claude** taught kc `==` and `!=` of any enum with values, as
kelvinc's #79, by the path of an Optional's (#343) and a Result's
(#344): the same case, and equal values, both sides of the enum. Its
elements in an Array, a Dictionary and a search compare too. kelvinc's
errors are in its words, naming `struct J` as it does; an operator of
the enum's own (#121) is not kc's yet. Found on the way, and fixed:
`l == json.none` took `json.none` for a place. Found, not fixed: kc
writes C that does not compile of `let <(a:J, b:J):bool`. Details are
provisional P357.

There are 1002 tests, and all pass with clang and with gcc 15.

### 391. kc's enum holding an Array of itself

> teach kc an enum holding an Array of itself as #346

**Claude** taught kc an enum with values, or a struct, that holds an
Array of itself, as kelvinc writes one: the Array's type before the
struct, its functions right after it, with the prototypes of the
struct's free and copy, which they call. A tree is built, copied,
freed, printed, compared and walked as under kelvinc. Found, not
fixed: a Dictionary of itself, which kelvinc has, is not kc's yet.
Details are provisional P358.

There are 1002 tests, and all pass with clang and with gcc 15.

### 392. kc's Dictionary of itself

> teach kc a Dictionary of itself as #347

**Claude** taught kc an enum with values, or a struct, that holds a
Dictionary of itself, as #346 taught it an Array of itself: the
Dictionary's type before the struct, its functions right after it. An
enum of JSON's shape, holding both, is built, copied, freed, printed,
compared and walked as under kelvinc. Found, not fixed: kc lets
`doc.fields(${:})` reach C, where kelvinc says it has no types.
Details are provisional P359.

There are 1002 tests, and all pass with clang and with gcc 15.

### 393. kc's refusal of doc.fields(${:})

> teach kc doc.fields(${:}) refusal as #348

**Claude** taught kc to take an empty `$[]`, `${:}` or `${}` only where
its type is written, as kelvinc does: a declaration's value, an
element, a Dictionary's value or a struct's member, of the type's
kind. Elsewhere, as `doc.fields(${:})`, `f($[])`, `d = ${:}` or
`return $[]`, kc gives kelvinc's error in its words, where it had
written C that did not compile, or read `${:}` as `none` of an
Optional. Found, not fixed: kc does not read `Dictionary<K, V>()`,
which the error says to write. Details are provisional P360.

There are 1002 tests, and all pass with clang and with gcc 15.

### 394. kc's Dictionary<K, V>() and Array<T>()

> teach kc Dictionary<K, V>() and Array<T>() as #349

**Claude** taught kc `Array<T>()` and `Dictionary<K, V>()`, as
kelvinc's #57 and #65: an empty one of the type written, anywhere a
value goes, so `var xs = Array<int64>()` infers its type and
`doc.fields(Dictionary<String, doc>())` works. Without `()` it is
kelvinc's error in its words; a count, the elements or a copy in them
are not yet kc's. Found, not fixed: a typed let of an Array of another
type reaches C, and kc assigns no Array. Details are provisional P361.

There are 1002 tests, and all pass with clang and with gcc 15.

### 395. kc's Array<T>(n), Array<T>([...]) and Array<T>(&a)

> teach kc Array<T>(n), Array<T>([...]) and Array<T>(&a) as #350

**Claude** taught kc `Array<T>([a, b])`, `Array<T>(&a)` and
`Array<T>(n)`, as kelvinc's #57 and #58: the elements written, a copy
of the Array lent, and `n` zero elements. kelvinc's errors are in its
words, and where kelvinc leaves one to C, as a count of text, kc says
its own. Found on the way, and fixed: an element of the wrong type in
`$[...]` of a type written reached C, and is kelvinc's error now.
Details are provisional P362.

There are 1002 tests, and all pass with clang and with gcc 15.

### 396. kc's Dictionary<K, V>({...}) and Dictionary<K, V>(&d)

> teach kc Dictionary<K, V>({...}) and Dictionary<K, V>(&d) as #351

**Claude** taught kc `Dictionary<K, V>({k: v})` and
`Dictionary<K, V>(&d)`, as kelvinc's #65: the entries written, read as
`${k: v}` of K and V, and a copy of the Dictionary lent. kelvinc's
errors are in its words. Found on the way, and fixed: a key of the
wrong kind in `${...}` of a type written reached C, and is kelvinc's
error now; a value of the wrong type is kc's. Details are provisional
P363.

There are 1002 tests, and all pass with clang and with gcc 15.

### 397. kc's Array([...]) with T inferred

> teach kc Array([...]) with T inferred as #352

**Claude** taught kc `Array([a, b])`, as kelvinc's #58: T the
elements' one type, as of `$[a, b]`, so `Array([5, 3, 8])` is an
`Array<i64>`. kelvinc's errors are in its words, of no element, of
elements of no one type, and of what else it takes in `Array(...)`.
Not yet kc's: `Array(&a)` with T inferred. Found, not fixed: kc has no
`.count` of a `cstr`. Details are provisional P364.

There are 1002 tests, and all pass with clang and with gcc 15.

### 398. kc's Array(&a) with T inferred

> teach kc Array(&a) with T inferred as #353

**Claude** taught kc `Array(&a)`, as kelvinc's #58: a copy of the
Array that `&a` lends, of its type, as `Array<T>(&a)` of #350. Of what
is no Array, it is kelvinc's error in its words. Found, in kelvinc and
not fixed here: `var e = Array(&g)` of a let is `const` in kelvinc's
C, so appending to it warns. Details are provisional P365.

There are 1002 tests, and all pass with clang and with gcc 15.

### 399. kc's fixed arrays

> teach kc Array<T>(a) of a fixed array as #354

**Claude** found that kc had no fixed arrays for `Array<T>(a)` to take,
and asked; the user chose fixed arrays first, as #354, and
`Array<T>(a)` of one as #355. Claude taught kc fixed arrays, a local's
alone, as kelvinc's #48 and #49: `[T](N)`, `[T]` counted by its
elements, `[a, b]`, nested, `[T](n)` of zeros, `a[i]`, `.count`,
`.size`, and `for x in a` as kelvinc's #30. kelvinc's errors are in its
words, and kc's own where kelvinc leaves one to C. Not yet: members,
parameters, results, globals, pointers to them, a count C computes, and
compound literals. Found in kelvinc, not fixed here: `println(a)` of a
fixed array prints its address. Details are provisional P366.

There are 1002 tests, and all pass with clang and with gcc 15.

### 400. kc's Array<T>(a) of a fixed array

> teach kc Array<T>(a) of a fixed array as #355

**Claude** taught kc `Array<T>(a)` and `Array(a)` of a fixed array, as
kelvinc's #57 and #58: an Array of copies of its elements, by `_from`.
An Array of fixed arrays is kelvinc's error in its words, where
kelvinc's `Array([a, a])` printed two addresses; a fixed array of
another element type is kc's error, where kelvinc's C warns. Details
are provisional P367.

There are 1002 tests, and all pass with clang and with gcc 15.

### 401. kc's fixed arrays as struct members

> teach kc fixed arrays as struct members as #356

**Claude** taught kc a fixed array as a struct's member, as kelvinc's
#49: declared in the struct as C's array, given `[a, b]` or `[T](n)` in
`{...}`, read and changed as a local's, and printed as kelvinc prints
it, every element. Its count is written, and its elements own nothing,
where kelvinc's may: not yet kc's. Found in kelvinc, not fixed here:
zeros as a member's value fail in its C. Details are provisional P368.

There are 1002 tests, and all pass with clang and with gcc 15.

### 402. kc's fixed arrays as parameters

> teach kc fixed arrays as parameters as #357

**Claude** taught kc a fixed array as a parameter, as kelvinc's #49: a
pointer in C, its count passed beside it, `[const T]` reading its
elements and `[T]` changing the caller's. Its argument is a fixed array
of its elements, and a let's goes to `[const T]` alone. kelvinc's errors
are in its words, and kc's own where kelvinc's C warns or walks past an
array's end. Details are provisional P369.

There are 1002 tests, and all pass with clang and with gcc 15.

### 403. kc's refusal of a fixed array result

> teach kc fixed arrays as results as #358

**Claude** found that kelvinc returns no fixed array, as C returns none,
and asked; the user chose a clear refusal. kc's error is now final, and
says the way out: `a function cannot return an array, as C cannot:
return a struct that holds one, or take one as a parameter and fill
it`. Details are provisional P370.

There are 1002 tests, and all pass with clang and with gcc 15.

### 404. kc's fixed arrays as globals

> teach kc fixed arrays as globals as #359

**Claude** taught kc a fixed array as a global, as kelvinc's #49:
declared as C's array, a let's elements const, and read and changed by
any function as a local's is. A let's element assigned is kelvinc's
error in its words. Details are provisional P371.

There are 1002 tests, and all pass with clang and with gcc 15.

### 405. kc's fixed arrays as enum case values

> teach kc fixed arrays as enum case values as #360

**Claude** found that kelvinc's C failed on a fixed array as an enum's
case value, and asked; the user chose "kc first, kelvinc later". Claude
taught kc the case: a typedef of its array type, its elements copied in
when it is made or set, bound to a copy by `switch` and `if let`, read
through the case, printed, and compared element by element. Found on
the way, and fixed: kc could not read a case's value of a call's enum,
as `mk(4).n`. Details are provisional P372.

There are 1002 tests, and all pass with clang and with gcc 15.

### 406. kelvinc's fixed arrays as enum case values

> teach kelvinc fixed arrays as enum case values as #361

**Claude** taught kelvinc a fixed array as an enum's case value, as kc
has it since #360: `[a, b]` given or set, its elements copied in, bound
to a copy by `switch` and `if let`, read of a call's value too, and
compared element by element; a case of no count is kc's error in kc's
words. Two tests, documents/enums.md and the kc sample have it.
Details are provisional P373.

There are 1004 tests, and all pass with clang and with gcc 15.

### 407. kc's fixed arrays behind pointers

> teach kc fixed arrays behind pointers as #362

**Claude** taught kc a pointer to a fixed array of its count,
`[int64](4)^`, as kelvinc's P61: a local's by `:=`, a parameter, a
member or a result, written in C as `__typeof__(int64_t[4]) *`, and
indexed through, `q^[i]`. kelvinc's errors are in its words, and kc's
own where kelvinc's C warns, as of a count of another, or reads an
address, as `q[0]`. Not yet: `[T]^` of no count. Details are
provisional P374.

There are 1004 tests, and all pass with clang and with gcc 15.

### 408. kc's [T]^ of no count

> teach kc [T]^ of no count as #363

**Claude** taught kc a pointer to a fixed array of no count, `[int64]^`,
as kelvinc reads it: C's pointer to an array of no bound, which any
count's array of its elements goes to, and which goes to a counted one.
Its elements are indexed through it, its count passed beside it; its
count and a walk over it are kc's errors, where kelvinc's C fails.
Details are provisional P375.

There are 1004 tests, and all pass with clang and with gcc 15.

### 409. kc's fixed arrays of owners

> teach kc fixed arrays of owners as #364

**Claude** taught kc a fixed array of owners as a struct's member and an
enum's case value, as kelvinc holds them: the struct or the enum owns,
and each element is freed and copied with it; a local's and a global's
stay kelvinc's error in its words. Found in kelvinc, not fixed here: a
member of two counts of owners leaks its inner elements, where kc's
frees them all. Not yet: a parameter of owners. Details are
provisional P376.

There are 1004 tests, and all pass with clang and with gcc 15.

### 410. kc's fixed array parameters of owners

> teach kc fixed array parameters of owners as #365

**Claude** taught kc a parameter's fixed array of owners, as kelvinc
reads it: its elements lent and still the caller's, read, changed and
assigned through `[T]`. Found on the way, and fixed: kc copied a part of
an owner by `let` and `=`, and returned it, so that it was freed twice;
kc now refuses them in kelvinc's words. Details are provisional P377.

There are 1004 tests, and all pass with clang and with gcc 15.

### 411. kc's fixed arrays of a count C computes

> teach kc fixed arrays with a count C computes as #366

**Claude** taught kc a fixed array of a count computed at run time, as
kelvinc's P61, a local var's: C's array of a variable length, zeroed by
`memset`, read and walked as a counted one. A let of one is kelvinc's
error in its words; elements given, a global's and a member's are kc's
errors, where kelvinc leaves them to C. `[T](n)` now reads any type's
name, a struct's too. Details are provisional P378.

There are 1004 tests, and all pass with clang and with gcc 15.

### 412. kc's [[T](n)](2)

> teach kc [[T](n)](2) as #367

**Claude** taught kc a count C computes within another fixed array,
`[[uint8](n)](2)` and `var g:[[int64](n)](3)`, a local var's: C's array
of a variable length within, zeroed as one. Found in kelvinc, not fixed
here: its C fails on the former, and it leaves the latter unset. Details
are provisional P379.

There are 1004 tests, and all pass with clang and with gcc 15.

### 413. kc's refusal of a fixed array in an Optional

> teach kc fixed arrays in an Optional as #368

**Claude** found that kelvinc refuses a fixed array in an Optional by
design, and asked; the user chose kelvinc's refusal. kc now says it in
kelvinc's words, of an Optional and a Result alike, wherever such a
type is written: `an Optional holds a value, and an array is none: hold
an Array, $[i64]`. Details are provisional P380.

There are 1004 tests, and all pass with clang and with gcc 15.

### 414. kc's fixed arrays in an Array

> teach kc fixed arrays in an Array as #369

**Claude** taught kc what kelvinc reads there: `[T]` in `$[...]` is an
Array in turn, `$[[int64]]` an Array of Arrays, and a list among the
elements of `$[...]` or `Array([...])` is an Array, `$[[1, 2], [3]]`. A
fixed array of a count in an Array, or in a Dictionary or a Set, is
kelvinc's error in its words. Details are provisional P381.

There are 1004 tests, and all pass with clang and with gcc 15.

### 415. kc's fixed array parameters of fixed arrays

> teach kc fixed array parameters of fixed arrays as #370

**Claude** taught kc a parameter of fixed arrays, `m:[[int64](3)]`, as
kelvinc reads it: a pointer to its rows in C, indexed `m[i][j]`, the
rows' count written and its own passed beside it, of owners too. Rows of
no count and of another count are kc's errors, and `[const [T](N)]` is
kelvinc's in its words. Details are provisional P382.

There are 1004 tests, and all pass with clang and with gcc 15.

### 416. kelvinc's inner elements of [[String](2)](2)

> teach kelvinc to free the inner elements of [[String](2)](2) as #371

**Claude** fixed kelvinc's member, or case, of an array of arrays of
owners: its codegen saw no owner there, so it neither freed nor copied
the inner elements; each innermost element is now freed and copied,
whatever the counts, as kc's since #364. A new test, which ASan fails
without the fix, has it. Details are provisional P383.

There are 1005 tests, and all pass with clang and with gcc 15.

### 417. x.prefix(n) and x.prefix { ... }

> add `.prefix(n)` and `.prefix { ... }` to all that iterates. the first form is `take` of Haskell and the latter is `takeWhile`. This is needed for infinite iterators like `Iterator(-1){ $0 += 1; $0 }`.

**Claude** asked what each kind should give and how to stage it; the
user chose Swift-like results, in one change of kelvinc and kc. An
Iterator, an iterator or a Sequence gives a lazy `Iterator<T>` that asks
its base no more after the count, or after the first false, so an
Iterator that never ends gives the first few and they chain; an Array,
a String, a Dictionary or a Set gives a new one of its kind. kc writes
the same and says kelvinc's errors. The example's body is written with
`return $0`, as a body of several statements returns its value. Details
are provisional P384.

There are 1009 tests, and all pass with clang and with gcc 15.

### 418. Range<T>

> make ranges a distinct type as `Range<IntType>` where `IntType` defaults to `i64`.
> * It is a sequence so it has `.map`, `.filter`, `.reduce` and `.flatMap`. of course, don't forget `.prefix`.
> * Some languages including Swift support `Range<AnyNumber>` where `AnyNumber` includes `FloatingPoint` types well.  buy for the time being let `Range` support just integers.
> * `0...` is an infinite sequence of integers while `...end` means `0...end` and `..<end` means `0..end`.  Yet `-n...<n` should work as expected.
> * Don't forge to give it a document

**Claude** asked four things: whether `-n...<n` meant `-n..<n`, which
the user confirmed; where `0...` stops and what the eager methods do
of it, and the user chose `T`'s largest and a refusal, at compile time
where it is written so and at run time otherwise; what `.prefix` gives,
and the user chose a Range of `.prefix(n)` and an `Iterator<T>` of
`.prefix { ... }`; and one change of kelvinc and kc. A range is now a
value, `Range<T>`, of its bounds and a kind, printed as written; it
walks as a Sequence, and `for` takes every form, a Range value too.
documents/ranges.md is its document. kc writes the same and says
kelvinc's errors. Details are provisional P385.

There are 1018 tests, and all pass with clang and with gcc 15.

### 419. A Range's count and contains

> add `.count` and `.contains` to Range as #374

**Claude** gave a Range `r.count`, how many values it has, a `u64` as
an Array's count is, and `r.contains(x)`, whether an integer `x` is one
of them, compared by its value whatever its type. A Range without an end
has no count: written so it is an error, and at run time the program
ends, as its `.map` does; one of 2^64 values ends it too. `contains`
first printed `1` for `true`, as C typed it an `int`, and is now a
`bool`. kc writes the same, its count an `i64`, and says kelvinc's
errors. Details are provisional P386.

There are 1022 tests, and all pass with clang and with gcc 15.

### 420. A Range's lowerBound and upperBound

> add `.lowerBound` and `.upperBound` to Range as #375

**Claude** gave a Range `r.lowerBound` and `r.upperBound`, its bounds as
written, of its integer type, as Swift's: a half-open one's upper bound
is past its last value, a closed one's its last, and `..<4`'s lower
bound 0. A Range without an end has no upper bound, as Swift's
`PartialRangeFrom` has none: written so it is an error, and at run time
the program ends, as its `.count` does. kc writes the same and says
kelvinc's errors. Details are provisional P387.

There are 1024 tests, and all pass with clang and with gcc 15.

### 421. A Range's == and !=

> add `==` and `!=` to Range as #376

**Claude** asked what makes two Ranges equal; the user chose the kind and
the bounds, as Swift's and as a Range prints, so `0..<5 != 0...4`, and
ranges of two integer types compared by value. Two Ranges without an
end are equal where their lower bounds are. An Array of Ranges now has
`==`, `contains` and `firstIndex`, and a `Range<T>?` compares as an
Optional. kc writes the same and says kelvinc's errors. Details are
provisional P388.

> You've suggested "add `<` and the rest to Range as #377" but that is ridiculous.  Consider `(-100..<10) < (0...10)`.  lhs has more elements yet rhs has larger upper bound.  Which is larger?  I think `Range`is not comparable though it is equatable.

**Claude** agreed: a Range has no order, as Swift's is Equatable and not
Comparable, so `<` and the rest stay errors by design, and ranges.md no
longer lists them as not yet.

There are 1026 tests, and all pass with clang and with gcc 15.

### 422. xs[r], a slice by a Range value

> let `xs[r]` slice by a Range value as #377

**Claude** let `xs[r]` slice an Array, a String or a Bytes by a Range
value as by one written: up to `hi`, past it where closed, to the end
without one, and out of range the program ends as before. kc had no
slices; as a range written in brackets is a Range there, kc now slices
an Array or a String by either. The test that refused `xs[r]` now
refuses slicing a Dictionary. Details are provisional P389.

There are 1027 tests, and all pass with clang and with gcc 15.

### 423. A Range's reversed()

> add `.reversed()` to Range as #378

**Claude** asked what it should give, as a descending Range would have no
text to paste back, and what of a Range without an end; the user chose a
lazy `Iterator<T>`, from the last value down to the first, and a refusal
of one without an end, as its `.count` refuses. It steps down only while
short of `lo`, so it never wraps. kc writes the same and says kelvinc's
errors. Details are provisional P390.

There are 1029 tests, and all pass with clang and with gcc 15.

### 424. A Range's stride(n)

> add `.stride(by:)` to Range as #379

**Claude** asked what a negative step should do, what type the step is,
and whether the `by:` label is required, Kelvin having no argument labels
anywhere else. The user chose a negative step walking from the last value
down, as `.reversed()` does; a step of the Range's `T`, an unsigned Range
walking down with `.reversed()` instead; and plain `.stride(n)`, as Kelvin
still has no call-site labels, so `stride(by: 2)` is an error that says
so. It is a lazy `Iterator<T>` that goes on while a whole step is left, so
it never wraps; a step of 0 is refused. kc writes the same and says
kelvinc's errors. Details are provisional P391.

There are 1034 tests, and all pass with clang and with gcc 15.

### 425. Powers: `**` and `pow`

> add the binary `**` operators to all numeric types.  integers, floating points and even complex numbers.
>
> * for integer types, add `b.pow(e)` that does `b ** e` AND `b.pow(e,m)` which returns `(b ** e) mod m)`.  Same as python's `pow(b,e,m)`.

**Claude** asked how `**` should bind, what an integer to a negative
power is, what overflow does, and whether `**=` comes along. The user
chose Python's precedence, a negative integer exponent ending the
program, reciprocals being out of an integer's domain, with `0 ** 0 == 1`;
wrapping as `*` does; and `**=`. Of integers `**` multiplies in a u64,
its type the base's promoted, as C's `<<` gives; two literals are worked
out by kelvinc, an i64 as a literal is, so `2 ** 40` is no `int`
overflow. Of floating-point numbers it is C's pow, of C's `_Complex`
cpow, and `<math>`'s `c64` and `c32` define it. `b.pow(e, m)` is Python's
`pow(b, e, m)`, a negative `e` included, by runtime/pow.k, written in
Kelvin over a u128. kc writes the same and says kelvinc's errors.
Details are provisional P392.

There are 1042 tests, and all pass with clang and with gcc 15.

### 426. A number's .abs

> add `.abs` to all signed numeric types as #381
>
> DO NOT ADD `.abs` to unsigned ints from the first place.  Proceed with that in mind.

**Claude** asked whether it is a property or a method, what the least of
a signed integer gives, and what an unsigned integer's `.abs` does. The
user chose the property `x.abs`, as written, `<math>`'s `x.abs()` method
kept; the least wrapping, staying as it is, as `**` wraps; and, firmly,
no `.abs` for unsigned integers at all, not even an error of its own, so
`u.abs` is any member a number has not. It is of the value's type, a
signed integer negated in its unsigned counterpart, a floating-point one
C's fabs; kelvinc now sees the type C gives a prefix and arithmetic, so
`(a - b).abs` works. kc writes the same. Details are provisional P393.

There are 1044 tests, and all pass with clang and with gcc 15.

### 427. A number's .sign, and .isNaN

> add `.sign` to all signed numeric types as #382.  `.signum`looks too pedantic and lesser used.  Should we also consider itroducing `<=>`, the UFO operator 😛   Also be careful not to add it to `Complex` since complex numbers are NOT compatable.

**Claude** asked of its type, of a floating-point zero and NaN, and of
`<=>`. The user chose the value's own type, -1, 0 or 1; for a
floating-point number 1.0 for +0.0, -1.0 for -0.0 and NaN for NaN, as
Rust's signum; and `<=>` later, as #383. The user asked too that
`T.isNaN` be there, for both floating-point types, and it was not: `<math>`
had only `x.isnan`, so `x.isNaN` came with it. Neither unsigned integers
nor complex numbers have `.sign`, nor integers `.isNaN`. kc writes the
same. Details are provisional P394.

There are 1046 tests, and all pass with clang and with gcc 15.

### 428. A floating-point number's fields

> change `.sign()` for floating points to return `bool?` where true for positive, false for negative, and `none` for `NaN`. Also make it a setter.
>
> * add `.exponent(e)` to return `i64` that gets and sets the significand of `self`.  fatal error if `e` goes out of bounds.
> * add `.significand(s)` to return `i64` that gets and sets the exponent part of self.  fatal error `s` it is out ouf bounds

**Claude** asked whether the two descriptions were crossed, whether they
are properties with setters or methods, what the i64s hold, and what the
sign's setter takes. The user agreed they were crossed, and chose
properties with setters, IEEE 754's raw fields, the exponent biased, and
a sign set with a bool, zeros by their bit. A set is in the var that holds
the number, within its field, or the program ends. On the way `b ?? false`
of a `bool?` was found printing 1, in kelvinc and in kc, and it prints
`true` now. kc writes the same, but for `o == none` of a `bool?`, which kc
does not read yet. `<=>` is #384. Details are provisional P395.

There are 1051 tests, and all pass with clang and with gcc 15.

### 429. A floating-point number's .isInfinite and .isFinite

> Do we have `.isInfinity` for floating points?  If missing, give it to them

**Claude** found it missing, but for `<math>`'s `x.isinf`, and set aside
the Unicode names, begun as #384, whose files were new and not yet
used. It asked of the spelling and of the number. The user chose Swift's
pair, `x.isInfinite` and `x.isFinite`, beside `x.isNaN`, and this as
#384; the Unicode names are #385 and `<=>` #386. kc writes the same.
Details are provisional P396.

There are 1053 tests, and all pass with clang and with gcc 15.

### 430. Names past ASCII

> `.k` is written in a valid Unicode and it should accept a valide identifier as `♾️`.  `let ♾️ = 1.0/0.0` must be considered a valid sentene unless `♾️` is defined a priori.
>
> resume the Unicode identifiers as #385

**Claude** noted that `♾` is a symbol, which UAX #31 alone would refuse,
and asked which characters a name holds, when two names are the same,
and the number. The user chose UAX #31's identifiers plus emoji, names
compared as written, and this as #385, after `.isInfinite` took #384.
`let ♾️ = 1.0/0.0` failed besides for want of a type, as #47 infers none
from arithmetic; the user chose that arithmetic of literals alone infer
one, reckoned in 64 bits. C compilers refuse emoji in names, so the C has
each name past ASCII in ASCII, and kelvinc says itself what C would of
one unknown or declared twice. kc writes the same, from its own tables in
Kelvin. Details are provisional P397.

There are 1059 tests, and all pass with clang and with gcc 15.

### 431. fallthrough

> let's tackle "Not available yet" section of versusC.md, one by one.  Let's begin with an easy one.  Add `fallthrough` to `switch - case`.  This may be the least used feature of Swift but it is still there.

**Claude** added Swift's `fallthrough` as #386: it goes on into the next
case's body, its label unchecked, from anywhere in its case, and belongs
to the innermost switch. As in Swift it is an error outside a switch, in
the last case, and into a case that binds a value, and `fallthrough` is
a keyword now. The C is a `goto` to a label on the next case's block, so
the owners of the case it leaves are freed, and no C compiler warns. kc
does the same, with kelvinc's errors. versusC.md keeps only Duff's device
out; `<=>` comes later. Details are provisional P398.

There are 1064 tests, and all pass with clang and with gcc 15.

### 432. Bits instead of bit-fields

> now the bit-fields.
>
> * we do not support C-style bitfields, period.
> * Instead, we introduce `struct Bits { value:i64 } `and use `value`as a storage of bits.  And extend it to manipulate each bit
> * To make it easier we tweak `Bool`a bit.  Introduce `!!i` operator where `i` is an iteger type and returns `false` IFF `i == 0`and `true` IFF `i == 1`.  Any other value is runtime error.  It is NOT `!(!b)`. `!!` no space in between `!` is a prefix operator which returns a "single bit integer" into `Bool`.
> * And `Int(b)` or `b:Int` which returns `0` on `false` and `1` on `true`.
> * It is made ore restrictive because `var bv = Bits(); bv[0] = !!0`as seemless, but not implicit as possible.
> * `bv[n] |=, &=, ~=` works as expected.
> * and the whole struct ops like `bv0 |= bv1` and such works like `i64_0 |= i64_1`.
> * maybe it should have a `.flip(n)` where `n` is the bit local to flip
> * to name flags, you can simply use enums.

**Claude** asked four things. Kelvin's `i64(b)` and `b.i64` already are
`Int(b)`; a Bits is made `Bits()` or `Bits(n)` and printed `Bits(0b101)`,
which pastes back; the prefix `~`, `==`, `!=`, `<<` and `>>` join `|`, `&`
and `~`; and `!!b` of a bool is an error that hints `! !b`. The user also
made `value` a `u64`. A bit is set with a bool alone, so `!!n` is the way
in from an integer; a place and a shift are 0 to 63, checked, and past
them the program ends, as an index past its count does. An enum's value
is a place, so flags have names. kelvinc and kc both make it, through
the prelude's inline functions; kc has no u64, so its `bv.value` is C's.
`!!yes` in an older test became `! !yes`. Details are provisional P399.

There are 1077 tests, and all pass with clang and with gcc 15.

### 433. Unnamed parameters

> next on the Not available yet list: unnamed parameters.  Before we go, would you explain a little bit what you mean by "unnamed parameters"?

**Claude** explained them as C's `f(int)`: a parameter given only its
type, in a prototype, or in a callback that must fit a signature but
ignores an argument. Kelvin then took `_` as an ordinary name, read in
the body, and two of them were C's error. The user chose `_`, as Swift's
and Rust's.

> go ahead with `_`.

**Claude** made a parameter written `_` unnamed, as #388: it takes its
argument and is never read, and `_` may stand for several. The C names
the k-th `_kv_argk`, as an anonymous function's `$k`, which still reads
it there. Reading `_`, as of `for _ in` too, was C's error and is
kelvinc's now; reading a `_kv_` name is refused, as declaring one was. kc
does the same, and no longer declares `for _ in`'s name. Details are
provisional P400.

There are 1081 tests, and all pass with clang and with gcc 15.

### 434. Types defined inside a struct

> next on the Not available yet list: nested struct definitions.  Is there a reason not to support them?

**Claude** found no deep reason, only C's oddities: a struct defined
inside a struct is a type of the whole file in C, so two structs cannot
each have their own `inner`; one defined inside a function belongs to its
block, which the functions kelvinc writes for each type cannot see.
Swift's scoping would name it `inner` inside and `outer.inner` outside,
with `outer__inner` in C; a local one would be hoisted under a hidden
name.

> go with Swift's scoping; local ones as the next number

**Claude** made it #389: a struct, a union or an enum defined inside a
struct or a union is bare there and in the methods of each, and a path
outside, as a type, an enum's cases and a function of the type, with its
methods declared on the path. In C it is `struct shape__size`, written
first. Its text and `.typename` spell the path, so a union's text and a
wrong case's message no longer show the C name, and `Array<a.b>` reads
back. A C enum's enumerators stay C's. kc does the same, with kelvinc's
errors. Details are provisional P401.

There are 1089 tests, and all pass with clang and with gcc 15.

### 435. kc's for over a cstr

> kc ... crashes at compile time on a loop over a C string literal: `for c in "hi" { print(c) }`

**Claude** found gen_each with no case of a cstr: it fell to an Array's,
whose element type of a cstr is -1, and `types[-1]` ended kc, of a cstr
variable too. kc now walks one as kelvinc does, each byte up to the NUL,
as #390: of a cstr `c` is a `u8`, `print(c)` printing `104`; of a
literal, which kelvinc sees no type of, it is C's `char`, by
`__typeof__`, printing `h`. Two loop variables of a literal are refused
in kelvinc's words. Details are provisional P402.

There are 1089 tests, and all pass with clang and with gcc 15.

### 436. Types defined in a function

> struct, union and enum definitions inside a function.  is there a reason not to support it?

**Claude** found no reason but one of C's: the functions kelvinc writes
for each type, its text, ==, free and its Arrays, are of the top level,
where a type C scopes to a block is unknown. So the C has it at the top
level under a name of kelvinc's own, `_kv_main_pair`, before the
function, while Kelvin knows it in the block alone, as #180 does a
function. Claude proposed that it hide a type of the top level of its
name, that a C enum's enumerators be the block's too, and that a method
of such a type wait.

> go for it

**Claude** made it #391: a struct, a union or an enum among a block's
statements is the block's from there to its end, its inner blocks and
anonymous functions too, with its text and `.typename` its own name and
types defined inside it as #389 has them. A C enum's enumerators are the
block's, `_kv_main_red` in C. A name twice in a block, one used after its
block ends, an array member counted by a local, and a method of such a
type are kelvinc's errors. kc does the same, with kelvinc's errors.
Details are provisional P403. Its commit says #390, which the kc fix of a
cstr's loop took first; the user chose that the fix keep it, and this
became #391.

There are 1094 tests, and all pass with clang and with gcc 15.

### 437. inline

> next on the Not available yet list: inline, restrict, _Static_assert.  They should be supported, too.  Your opinion?

**Claude** agreed, with one number each. `inline let f(...)` would be C's
`static inline`, since C11's bare `inline` wants a definition elsewhere
and fails to link at -O0, and a module's `M.kh` would keep an inline
function's body, so that a program inlines it. `restrict` would follow a
pointer's `^`, as `u8^ const` does, and `static_assert(c, "message")`,
C23's name with the message optional, would be C's `_Static_assert`,
which the C compiler judges.

> go for it

**Claude** found that the kc fix of a cstr's loop, made in a session of
its own, had taken #390 as well; the user chose that it keep the number,
so types defined in a function became #391, and these #392 to #394.

**Claude** made `inline` #392: before `let`, or before or after `static`,
on a function, a method, an operator, an attribute and a function of the
type, in `extend` too, it is `static inline` in C, and `kelvinc --lib`
copies its body into `M.kh`. On a variable, a type, an `extern` prototype
or `main`, or twice, it is an error. kc does the same, with kelvinc's
errors. Details are provisional P404.

There are 1100 tests, and all pass with clang and with gcc 15.

### 438. restrict

> commit and push when the battery passes, then restrict

**Claude** committed #392 and made `restrict` #393: a pointer's own
qualifier, after its `^` as its own `const` is, `u8^ restrict`, C's
`T *restrict`, on a parameter, a variable and a `cstr`. It is the
programmer's promise, as in C. `.typename` spells it, and a function type
compares without it, as C's does. Before the type, on a non-pointer or on
a function type, it is an error that says where it goes. kc does the
same, with kelvinc's errors. Details are provisional P405.

There are 1104 tests, and all pass with clang and with gcc 15.

### 439. static_assert

> commit and push when the battery passes, then static_assert

**Claude** committed #393 and made `static_assert` #394:
`static_assert(cond)` or `static_assert(cond, "message")`, C23's name, at
the top level and in a block, is C's `_Static_assert`, which the C
compiler judges at the Kelvin line; without a message, the condition as
written is one. A variable in the condition, `_Static_assert`, a message
of no string literal and a name `static_assert` are kelvinc's errors. A
module's `M.kh` leaves it out. kc does the same, with kelvinc's errors.
Details are provisional P406.

There are 1110 tests, and all pass with clang and with gcc 15.

### 440. alignof

> next on the Not available yet list: _Alignas and alignof

**Claude** asked how each is spelled. The user chose `alignof(T)`, C23's
name as `sizeof(T)` is C's, with `x.align` for a value, as `x.size` is,
and `alignas(N)` before the declaration, where `static` and `inline` go.

**Claude** made `alignof` #395: `alignof(T)` is C's `_Alignof`, and
`x.align` its type's, `_Alignof(__typeof__(x))`, both a `size_t`, a
struct's field `align` winning. `alignof` of a value, `_Alignof`,
`__alignof__` and a name `alignof` are errors that say what Kelvin
writes. kc does the same, with kelvinc's errors. Details are provisional
P407.

There are 1116 tests, and all pass with clang and with gcc 15.

### 441. alignas

**Claude** made `alignas` #396, as the user chose: `alignas(N)` or
`alignas(T)`, C23's name, before the declaration of a variable, a global,
a static or a struct's member, is C's `_Alignas`, each name of the
declaration taking it. A literal `N` is checked a power of two, and
`x.align` stays its type's. Before a function, a type or a statement,
twice, and C11's `_Alignas` are errors. kc does the same, with kelvinc's
errors. Details are provisional P408.

There are 1123 tests, and all pass with clang and with gcc 15.

### 442. _Generic, left out

> next on the Not available yet list: _Generic.  Forget _Generic.  Though our generics is shallower than C++, Swift and many other (owing to its nature to compile to C11), our functions are already multi-dispatch and more generic than shabby C's.

**Claude** moved `_Generic` to Left out on purpose as #397: a function of
one name takes several types by its overloads (#41), as methods,
operators and the built-in properties do, and kelvinc writes `_Generic`
itself where only C sees a type. Written, `_Generic` is now an error that
says so, in kelvinc and kc, in place of "expected an expression".
Details are provisional P409.

There are 1124 tests, and all pass with clang and with gcc 15.

### 443. typeof, C-compatible

> next on the Not available yet list: typeof.  keep it. C-compatible

**Claude** made `typeof` #398, as C23 has it: `typeof(x)` is `x`'s type
with its own qualifiers, a `let`'s `const` too, which `x.type` leaves,
of any expression, C's `__typeof__` where kelvinc does not see the type;
`typeof(T)` is `T`. It goes where a type goes, in `sizeof`, `as` and
compound literals. `typeof x`, `__typeof__` and `typeof_unqual` are
errors that name the Kelvin spellings. kc reads `typeof(T)` and
`typeof(x)` of a variable whose type is written. Details are provisional
P410.

There are 1129 tests, and all pass with clang and with gcc 15.

### 444. Assembly, left out

> next on the Not available yet list: __asm__ __volatile__ .  They are not exactly parts of C standard (GCC extension that happens to be supported by clang).  We already have `#inline C` so we should leave them up there.

**Claude** asked whether `__asm__(...)`, which Kelvin passed through as a
statement, should stay; the user chose that all assembly be refused.

**Claude** made it #399: `__asm__ __volatile__ (...)`, `__asm__`, `__asm`
and `asm(...)` are left out on purpose, as GNU C's, and go in `#inline C
{ __asm__ __volatile__("..."); }`; written in Kelvin, each is an error
that says so, and `__volatile__` one that names `volatile`. `asm` stays a
name of the program's. A test's `__asm__("nop")` moved into `#inline C`.
kc says the same. Details are provisional P411.

There are 1132 tests, and all pass with clang and with gcc 15.

### 445. sizeof(FILE^), left out

> next on the Not available yet list: sizeof(FILE^).  Would you explain you raised this?  AFAIK sizeof(T^) is always 8 while sizeof(T) depends on how T is laid on memory

**Claude** agreed on the size, and explained that the item was the
parse: kelvinc reads no C header, so it cannot tell a header's type,
`FILE`, from its value, `stdout`, and takes `FILE^` for a dereference, as
`stdout^` is, which C refuses as `sizeof(*FILE)`. `typealias` cannot
name `FILE` either. As every object pointer has one size, `sizeof(any^)`
and `f.size` serve, and taking an unknown `NAME^` for a type would change
`sizeof(stdout^)` silently.

> go with left out on purpose

**Claude** moved it to Left out on purpose as #400, with `sizeof(any^)`
and `x.size` named there, and a test of them. Details are provisional
P412.

There are 1133 tests, and all pass with clang and with gcc 15.

### 446. Duff's device, left out

> next on the Not available yet list: Duff's device.  It must be possible now that Kelvin has `fallthrough`.

**Claude** answered that `fallthrough` writes what Duff's device does, a
cascade of cases for the remainder and then whole blocks in a loop, which
it showed working, but not its shape: a case inside the loop is a jump
into a loop's middle, which C's cleanup of an owner refuses and which
would undo the switch's checks, and `cc -O2` unrolls a loop itself.

> go with left out on purpose.  I have already expressed it is an obsolete sleight of hand anyway.

**Claude** moved Duff's device to Left out on purpose as #401, with the
cascade and the loop in flow-controls.md and a test of them. Details are
provisional P413.

There are 1134 tests, and all pass with clang and with gcc 15.

### 447. if (1) name(x)

> next on the Not available yet list: statements of the form name(x).  Suggestion?

**Claude** showed the silent case: in an inner block, `size_t(n)` was
C's declaration of a new, uninitialized `n` shadowing the outer one, and
the block printed garbage. Since kelvinc reads no header, it cannot tell
a typedef from a function or a macro there, so it proposed writing such a
statement `if (1) name(x);` in C, where a declaration is no statement: a
call and a macro are as before, and a typedef there is C's error.

> go with the if (1) guard

**Claude** made it #402: a statement `name(x)` or `name(x) = v` of a name
kelvinc does not see, its one argument shaped as a declarator, is guarded
so; Kelvin's own functions and variables and `print` are as written, and
a statement macro stays one. kc does the same. Details are provisional
P414.

There are 1136 tests, and all pass with clang and with gcc 15.

### 448. Function types wherever a type goes

> next on the Not available yet list: an array of functions.  What do you recommend?

**Claude** found the item partly stale: `[(i64):i64](4)` worked already.
What remained: `Array` and `Dictionary` of a function type wrote C that
did not compile, a pointer to a function type kelvinc printed,
`((i64):i64)^`, but refused to read, and `typealias` of a function type.

> go with a single #403, all three

**Claude** made it #403: the containers write their element of a
function type as `__typeof__(...)`; `((i64):i64)^` is a pointer to a
function type, as kelvinc prints it; and `typealias op = (i64):i64`
names one, `op^` its pointer. The type lookahead reads function types, so
the value `[(i64):i64](2)` does too. C's order, `((i64):i64)[4]`, is an
error that names `[(i64):i64](4)`. Two older tests took the new messages.
versusC.md's Not available yet is empty now. Details are provisional P415.

There are 1138 tests, and all pass with clang and with gcc 15.

### 449. _Complex, unsupported

> unsupport `_Complex`. error if the compiler encounters this cursed word.  IMHO it was one of the worst feature of C99.  We've shown we could do much better than that in `<math>`.

**Claude** made it #404: `_Complex` is an error wherever Kelvin is
written, naming `<math>`'s `c64` and `c32`, and so are GNU's `__complex__`
and `__complex`. kelvinc's `f32 _Complex` and `f64 _Complex`, with `cpow`
for their `**`, are gone; `<math>` never used them. A value whose type
only C sees, a header's typedef of one, still prints as C hands it over.
Two tests moved off the word, and kc says the same. Details are
provisional P416.

There are 1140 tests, and all pass with clang and with gcc 15.

### 450. Bytes to String, a Result

> Though we have `b.isUTF8`,`Byte` to `String` conversion should return `Result` or at least `Optional` so you can handle malformed UTF-8 instead of instant death.

**Claude** asked two things. The user chose `Result<String, i64>`, its
`err` the offset of the first byte where the UTF-8 breaks, over `String?`
or a message; and `String(&b)` kept as the checked form, which ends the
program, for bytes known to be text.

**Claude** made it #405: `b.string()` is that Result, found in one scan,
and handled as any Result is: `if let`, `if let err(at)`, `??`, `try`,
`switch`. The three modules that asked `b.isUTF8` first write
`String(&b)`. `f.string` and `f.lines` still end on text that is not
UTF-8. Details are provisional P417.

There are 1142 tests, and all pass with clang and with gcc 15.

### 451. f.string and f.lines, Results too

> make f.string and f.lines Results too

**Claude** asked what each err carries. The user chose an `i64` offset
for both: for a line, where in it the UTF-8 breaks; for `f.string`,
where in what was read, the bytes then gone.

**Claude** made it #406: `f.string` and each line of `f.lines` are a
`Result<String, i64>`, and a bad line leaves the loop going to the next.
kc reads its sources by `f.string`, so kc types it and writes its C too,
and kc.k binds it before `if let`. The tests that printed lines read
`line.ok`; two long ones bind `if let line = r`. Details are provisional
P418.

There are 1144 tests, and all pass with clang and with gcc 15.

### 452. kc's ??, of a Result too

> make kc's ?? take a Result too

**Claude** made it #407: kc's `x ?? d` of a Result gives what it holds
where it is ok, else d, writing the C kelvinc writes, an `err` taken
freed. kc's error of another left side is kelvinc's wording now, and
`r ?? r2` of two Results, kelvinc's alone, is kc's error rather than C's.
kc.k reads its sources by `f.string ?? $""` again; sample.k prints
`??` of Results through both compilers. Details are provisional P419.

There are 1144 tests, and all pass with clang and with gcc 15.

### 453. kc's r ?? r2

> make kc take r ?? r2 too

**Claude** made it #408: kc's `r ?? r2` of two Results of a type gives
r where it is ok, else r2, writing the C kelvinc writes, a place copied,
a Result taken freed where it is an err. kc's message of a wrong
fallback now puts the Result's own article before it, as kelvinc's.
sample.k prints `r ?? r2` through both compilers. Details are
provisional P420.

There are 1144 tests, and all pass with clang and with gcc 15.

### 454. kc's a ?? b of two Optionals

> make kc take a ?? b of two Optionals too

**Claude** made it #409: kc's `a ?? b` of two Optionals of a type, and
`a ?? none`, give a where it has a value, else b, an Optional, writing
the C kelvinc writes, held and freed as #408's `r ?? r2`. Of a `T??`, a
`T?` or `none` on the right is what it holds, as kelvinc's. kc's Range
and Bits checks no longer ask the type of `none`. sample.k prints `a ??
b` through both compilers. Details are provisional P421.

There are 1144 tests, and all pass with clang and with gcc 15.

### 455. kc's r ?? ok(v) and r ?? err(e)

> make kc take r ?? ok(v) and r ?? err(e) too

**Claude** made it #410: kc's `r ?? ok(v)` and `r ?? err(e)` make a
Result of r's type of the word, r where it is ok, else the word's,
writing the C kelvinc writes. A word that makes no value of what is on
the left, `r ?? some(2)`, `o ?? ok(2)`, is kelvinc's error in its words
where kc said "this function is not known". sample.k prints them through
both compilers. Details are provisional P422.

There are 1144 tests, and all pass with clang and with gcc 15.

### 456. A case's value of another type, Kelvin's error

> fix both kelvinc bugs

**Claude** found the first, `r ?? ok($"s")` of a Result<i64, String>
given to C unchecked, wider than `??`: any value of another type in a
case of an Optional, a Result or an enum with values was. **Claude**
made it #411: each is an error in Kelvin's words, `case 'ok' of
Result<i64, String> holds an i64, and this is String`, any number still
going where a number does. kc still gives C's errors of these. Details
are provisional P423.

There are 1151 tests, and all pass with clang and with gcc 15.

### 457. String(x) and Bytes(x) of an owner an expression gives

> fix both kelvinc bugs

**Claude** found the second, `String(f())` of a String given to C as
text, wider too: `String($[1, 2])`, `String(h())` of a Bytes and
`Bytes(f())` of a String were C's errors. **Claude** asked what a
String of a String should be; the user chose an error for every owner,
as of a variable. **Claude** made it #412: each is an error in Kelvin's
words that names what to write, `String(&b)`, `Bytes(&s)`, or that it
is one already. kc still gives C's errors of these. Details are
provisional P424.

There are 1156 tests, and all pass with clang and with gcc 15.

### 458. kc's case value of another type, kelvinc's error

> make kc give kelvinc's errors for both

**Claude** made the first #413: kc's value of a case of another type is
kelvinc's error in its words, `case 'ok' of Result<i64, String> holds
an i64, and this is String`, of `ok(v)`, `err(e)`, a `T` wrapped,
`T.c(v)` and a side of `==`. On the way **Claude** found kc refusing
`r == ok(5)`, `f(ok(3))` and `ok(none)` of a `Result<T?, E>`, which
asked the type of a case word, and `let s:String? = "lit"`; kc builds
them now, and sample.k prints them through both compilers. Details are
provisional P425.

There are 1156 tests, and all pass with clang and with gcc 15.

### 459. kc's String(x) of an owner, kelvinc's error

> make kc give kelvinc's errors for both

**Claude** made the second #414: kc's `String(x)` of an owner is
kelvinc's error in its words, `String(x) of a String is one already:
leave out String(...)`, and of a place `would copy an owner`, which kc
had not refused either. `String()`, which stopped kc, is an empty
String, as kelvinc's. kc has no Bytes to check. Details are provisional
P426.

There are 1156 tests, and all pass with clang and with gcc 15.
