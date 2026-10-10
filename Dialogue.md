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

