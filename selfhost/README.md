# Self-hosting Kelvin: experimental

**Can Kelvin compile itself?** For a subset, yes. `kc` is a compiler
written in Kelvin alone. It reads the subset it is written in, writes C
as kelvinc does, and hands that C to `cc`. Built in stages, as gcc
bootstraps itself, it reaches a fixpoint (#204).

## Synopsis

```sh
selfhost/bootstrap.sh                   # kc built in three stages, to a fixpoint
selfhost/errors.sh                      # kc over the programs kelvinc refuses
build/selfhost/stage3 program.k -o app  # kc builds a program
```

## Description

- **Experimental** (#230), no longer a proof of concept: CI builds it
  and checks its fixpoint on every push (#228), but its subset, its
  messages and its C may still change with each step.

- **Kelvin, and the platform's C:** a self-hosted Kelvin may depend on
  libc, or libSystem on macOS, as C does: Kelvin embraces C rather than
  refusing it.
  - What would be cheating is C of its own: `#inline C`, or C headers
    and libraries written for it.
  - kc uses less still: the prelude (`String`, `Array`, `println`) and
    `<IO>` to read the source, write the C and run `cc`.
  - Of the runtime's C it calls one function by name, `rx_check` of
    `kRegExp.h`, the parser of the prelude's RegExp, which says what is
    wrong with a `$/.../` literal as kelvinc's says it (#163, #611).
- **In CI** (#228): the `selfhost` jobs run `bootstrap.sh` and
  `sanitize.sh` with gcc and clang on Ubuntu, and clang on macOS.

### Goals

Agreed in #279.

- **What kc need not do:** read C's source, `#import <foo.h> as C` and
  `#inline C { ... }`.
  - While it writes C, kc writes a header's `#include` (#207) and
    passes `#inline C` through as it stands (#727), reading neither.
  - libc is still Kelvin's to call, as C calls it.
- **Now:** kc writes C from `*.k` and hands it to `cc` or `gcc`, and
  builds itself so (#204).
- **Short term:** kc as capable as kelvinc, which is written mostly in
  C.
  - kelvinc is the measure: a program kc builds prints what kelvinc's
    build prints.
- **Mid term:** no C in between: kc writes assembly or LLVM IR itself,
  not `kc -> C -> assembly or LLVM IR`.
  - In the way: kc writes C straight from its tree, and that C uses
    `kelvin_prelude.h`, whose C macros make each `Array<T>`,
    `Dictionary<K, V>` and `Set<T>`.
- **Long term:** the whole back end written in Kelvin, as Go's is, and
  as C's compilers are written in C.
  - The runtime too: `runtime/*.k`, built by `kelvinc --runtime` into
    `libkelvin` (#289): a String's searching, trimming, escaping and
    unescaping, and Base64 (#290); and runtime/os.k into `libkOS`, a
    group of OS's at a time (#301).

### Files

| File | What it is |
|---|---|
| [kc.k](kc.k) | the driver: options, reading files and their imports, writing the C, running `cc` |
| [lex.k](lex.k) | the tokens |
| [parse.k](parse.k) | the tree and the types |
| [gen.k](gen.k) | the C |
| [sample.k](sample.k) | a program of the subset, built by both compilers, which must print the same |
| [bootstrap.sh](bootstrap.sh) | the stages and their checks |
| [sanitize.sh](sanitize.sh) | kc built with ASan and UBSan, which must write the same C (#228) |
| [errors.sh](errors.sh) | kc over `tests/error`, the programs kelvinc refuses (#609) |
| [errors.txt](errors.txt) | the tests kc does not yet refuse in kelvinc's words, which `errors.sh` checks kc against |

### The stages

```sh
selfhost/bootstrap.sh
selfhost/sanitize.sh
selfhost/errors.sh
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
  - So must the program kelvinc links of stage3's object of it,
    `kc -c` (#281).
- **The C:** each stage writes its C with `--emit-c`, as kelvinc does
  (#281).
- **The compiler:** `CC` picks the C compiler of every stage, and of
  kelvinc's build of the sample; CI runs gcc and clang.
- **Sanitizers** (#228): `sanitize.sh` builds kc from stage2's C with
  ASan and UBSan, and its C of `kc.k` and of `sample.k` must be the
  stages' own, with no memory error and no undefined behavior.
- **The errors** (#609): `errors.sh` runs stage3 over every program
  of `tests/error`, which kelvinc refuses with the text of the test's
  `// error:` line, and says which of six kc's answer is.
  - `same`: kc refuses it, and what is printed has that text, at the
    line and column kelvinc says it at, where both refuse it themselves
    (#690).
  - `place`: as `same`, at another line or column than kelvinc's
    (#690).
  - `words`: kc refuses it in words of its own.
  - `c`: kc writes its C, and the C compiler refuses that.
  - `built`: kc builds what kelvinc refuses.
  - `crash`: kc itself ends, with no error of the program.
  - `errors.txt` lists each test that is not `same`, with which of
    the five it is; as of #690 one, `place anon_list_c_arg.k`, kc's
    error at the list's first comma and kelvinc's at its second, where
    its parse of an anonymous function ends. Before, as of #612, as of #612, 226 of the 931, each of them `words`,
    and none is left to C, `built` or a `crash`.
    - The 100 that kc left to C (#612) are kelvinc's errors in its
      words.
      - The lexer's: a literal with C's suffix, `10UL`, and a
        malformed number; a C compiler's keyword, `__typeof__`;
        `#include`, and a C header's line that is not `as C`.
      - A type's word where a value goes, `i32 + 1`, `int(x)`,
        `cstr(p)`, `u8^(p)`, `sizeof(int)`; `any` alone, `Self` with
        no type, a method of `any`, of a plain enum, of no type of
        the program's; `toString()`; `extern inline`; `println`
        defined anew.
      - Functions of one name in C: two methods, a function and an
        overload named by its types, a second `main`, an overload
        that differs in its result alone.
      - An anonymous function: a variable of the function around it,
        `$1` past its parameters, `$00`, `$[i]`, `$0` outside one,
        with kelvinc's word of a `{` after a call in a condition's
        head or on the next line; a list given to a function.
        `$[k]`, its parameter k, is read now.
      - A value of its target's type, in Kelvin's words: `'x' of
        'half' is an f64, and this is text`, of an argument, a
        declaration, an assignment, a member and an element; a
        struct of another struct; C's function hidden by a Kelvin
        one of its name.
      - Containers: a key of its Dictionary's, a Set indexed, a
        Set's elements of two types, rows of two counts, a `cstr`
        written through.
      - `for`: an `any^`, a list's variable that is no pointer, an
        array in what a call gives.
      - IO: `IO` with no `#import <IO>`, `IO.exec` of one text,
        `IO(f, "r")` of an IO, `print` of more than 16 values.
      - The rest: an enum's case that is none of its, `ok(5)` and
        `some(5)` alone, an owner given to C's function, a borrow
        of what an expression gives kept, a static's template,
        `_Pragma` as an operand, `p^ := 1`, a `let` method `next`
        that `.filter` walks, a local that hides a global given
        its value at its first use, and C's declarations where a
        statement starts, `size_t * b[3];`.
    - Four of them kelvinc leaves to C too, and their test's text is
      the file and its line: kc's C has `#line` now, so C names them.
    - `x.hex` of what only C sees goes through `_Generic`, as
      kelvinc writes it: C says `kv_no_such_property` of a struct.
    - Nineteen more that kc said in its own words are kelvinc's with
      them, `c_decl_ptrptr.k` and `suffix_f.k` among them.
    - The 70 that kc built (#611) are kelvinc's errors in its words.
      - Names: a word kelvinc keeps names no variable, `var typeof`;
        `_kv_` and `kv_` names are kelvinc's and its runtime's; C's
        type words, `int`, `char`, `void`, are no types.
      - A bool where one goes: a condition, an operand of `&&`, `||`
        and `!`, and what a function of a bool result returns. What
        only C sees goes through the `_Generic` that only a bool
        passes, as kelvinc writes it.
      - Numbers: a base of 2 to 36, `bool("text")`, a range of
        integers, an `any^` that steps.
      - `#import`: a directory, `as C` after a Kelvin file, text after
        the name; a `$/.../` literal that is no regular expression, by
        the runtime's `rx_check`.
      - Declarations: a `let` with no value, `count:i32` with no `let`
        or `var`, `static var T.f()`, a function or a computed
        attribute of a built-in type, a case with a number, a `cstr`
        key.
      - Owners: a struct that owns dropped, a borrow that outlives
        its owner or is returned, `.get` of a value that owns, a
        change to what an expression gives, a borrow of a Bytes
        appended to a String, an element lent to a `map` or `sort`
        function and moved or returned there.
      - Functions: `{ $0 + 1 }` in parentheses or given to overloads
        that differ, a body whose value is discarded, a `.map` result
        of two number types, a tie of a method's overloads, a
        function of a type called on a value, `async` of an array
        parameter.
      - The rest: an IO's `close` and `rename` on a `let` and `print`
        of a function, `return {1}` of a number, what follows a bare
        `return`, `{1.0}` for a case, a case that binds beside
        another, `p^ = &x` of a reference, `for` over a parameter's
        array whose length a var gives.
    - Thirteen more that kc left to C or said in its own words are
      kelvinc's with them, `no_char.k` and `void_return.k` among them.
    - The three that were (#610), each an index out of range in
      gen.k, are kelvinc's errors in its words: `for x in n` of what
      has no elements, a number, a bool, a struct, which `gen_each`
      took for an Array; `IO()` and `IO(a, b, c)`, whose first
      argument `gen_call` read where there is none; and
      `case none(x):`, a case of no value, whose type `gen_switch`
      wrote. Of a C header's type kc's `for` says "not yet", in
      words of its own, where kelvinc walks it as a pointer.
  - The check fails where a test is not as listed: one that got
    worse, and one that got better, whose line is to go. So the list
    only shrinks, and a new test of `tests/error` is the same in kc,
    or is listed.
  - `selfhost/errors.sh --write` writes the list anew, as kc is.
- Everything goes into `build/selfhost/`; nothing is removed.

### Using kc

```sh
build/selfhost/stage3 [-c | --emit-c] [--no-line] program.k [-o path] [-m modules] [-cc compiler]
```

- The options are kelvinc's (#281).
  - `-c` makes an object, `program.o` or the `-o` path, which
    `kelvinc -o program program.o` links.
  - `--emit-c` writes the C, to the `-o` path or stdout, and stops.
  - `--no-line` leaves the `#line` directives out of the C (#612).
  - Else kc builds the program, `a.out` or the `-o` path.
- The C has `#line N "file.k"` before each statement and each function,
  as kelvinc's has (#612): what the C compiler says of the C, and a
  debugger, name the Kelvin source and its line.
- `#import "x.h" as C` is looked for next to the `.k` file, by `-I` of
  its directory, as kelvinc's (#612).
- The C is a temporary file, `$TMPDIR/kc-<pid>.c`, or in `/tmp`, removed
  once `cc` is done (#207).
- `-m` names the directory of `kelvin_prelude.h` and the libraries.
  - Without it: `$KELVIN_HOME/modules`, as kelvinc reads `KELVIN_HOME`,
    else `modules`, from the top of the repository.
- `-cc` names the C compiler; without it, `$CC`, else `cc`.

### The subset

kc reads what it is written in, and little more.

- **Declarations:** `let f(x:T, ...):R { }`, a prototype without a body,
  `struct` of plain members, `enum` of names, C's (#210), global `let`
  and `var`, `#import <IO>`, `#import "x.k"`, and `#import <x.h> as C`
  (#207).
- **A body's value** (#286), as kelvinc's #26: a function with a result
  whose body is one expression returns it, `let f(x:int64):int64 { x * 2 }`.
  - One assignment, or one call with no value, is kelvinc's error.
  - A body that ends in a value on any path, of a block, an `if` or a
    case, is kelvinc's error too, and in `main`, whose end returns 0,
    one with no effect.
    - A method's value is one (#594), `if c { p.twice(1) } else { ... }`,
      as a function's: of a struct's method, an enum's, or one a
      module gives a number, `y.abs()`. A built-in method's is not, as
      with kelvinc.
    - Each statement at an end is asked where gen writes it (#594),
      noted before by `note_ends`, so the body's own variables are
      declared: a method is its receiver's, `let q = p^` then
      `q.twice(1)`, and an overload its arguments'.
      - It was asked before the body, with its parameters alone: a
        call of an overloaded function by a local, `note(y)`, at the
        end of a body with a result chose its overload there, with no
        type for `y`, and kept it, which C refused.
  - A call that C's `_Generic` chooses the overload of (#593) is asked
    of all of them, by `generic_result`, as kelvinc's
    `overloaded_result`: no value where none has a result, a value
    where each has one, and not seen where they differ.
    - The first of them gave the call its type, so
      `let f():f64 { note(atof("1.5")) }` was refused where
      `note(x:i64)`, with no result, was declared before `note(x:f64)`.
- **An argument with no value** (#317) is kelvinc's error of #316, in
  its words: `println(tell(1))`, `xs.append(f.close())`.
  - It covers a call, a method or `async`, given a call of a function or
    method with no result, of `print` or `println`, or `await` of a Task
    with none.
  - A built-in method with no value counts too, as kelvinc's: an
    Array's append, insert and remove(i, n), a clear, reserve or
    compact, and an IO's write, flush, close, print, println and rewind.
- **Enums with values** (#215): `enum item { none; num: int64; text:
  String }`, written as kelvinc writes one: a struct of a tag and a
  union, with `_kv_T_make_c`, `_at_c` (checked) and `_set_c`, and
  `_free`, `_take` and `_copy` where a case owns.
  - `T.c(v)` makes one, a local owner moving in, and `T.none` one of no
    value; `v.c` reads the case's value, checked; `v.c = x` sets the
    case, freeing what it held; `v.is(c)`.
  - `switch v { case none: ... case num(n): ... }` binds the case's
    value, which the enum still owns; every case is named, or there is
    `default:`.
  - `==` and `!=` (#345), as kelvinc's #79: the same case, and equal
    values, by `_kv_T_eq`, as an Optional's (#343) and a Result's (#344).
    - Both sides are of the enum: `a == item.num(5)`, `j != k`; nothing
      is wrapped, so `j == none` and `j == 3` are kelvinc's errors.
    - Its elements in an Array, a Dictionary and a search compare too:
      `items.contains(item.none)`.
    - kelvinc's errors, in its words: `'==' compares two struct J, and
      this is not one`; `case 'p' holds P, which has no '=='`.
    - `j < j`: kelvinc's error, and an operator of its own (#121) came
      with #471.
  - An enum or a struct that holds an Array of itself (#346), as
    kelvinc writes one: `enum node { leaf: int64; kids: $[node] }`.
    - The Array's type, `KV_ARRAY_TYPE`, comes before the struct, and
      its functions, `KV_ARRAY_FUNCS`, right after it, with the
      prototypes of the struct's `_free` and `_copy`, which they call.
    - So a tree is built, copied, freed, printed, compared and walked
      by a function that calls itself.
    - A Dictionary of itself the same way (#347), `KV_DICT_TYPE` and
      `KV_DICT_FUNCS`: `enum js { arr: $[js]; obj: Dictionary<String,
      js> }`, a document of JSON's shape.
    - Two enums that hold Arrays of each other, `$[$[node]]` or
      `$[node]?` are not kelvinc's either.
- **Optional and Result** (#217): `T?`, `Optional<T>` and
  `Result<T, E>`, which kc makes as the enums with values kelvinc makes:
  `struct _kv_opt_T` of `none` and `some`, `struct _kv_res_T_E` of `ok`
  and `err`.
  - `none`, `ok(v)` and `err(e)` are read by the type that takes them,
    a variable's, a return's, an assignment's or a parameter's; a `T`
    where a `T?` goes is `some(T)`. `some(v)` is a pattern alone, as in
    kelvinc.
    - Since #221 a program needs no enum of its own with a case `none`
      for that: kc asked the type of a bare `none` in a `return` and in
      an argument, and found no name.
    - So in a struct's `{a, b}`, whose members kc reads by their
      fields' types since #225.
  - `$[T]?` is an Optional of an Array (#221), and `T??` one of a `T?`
    (#229).
  - A number literal is `some(n)` of any number's Optional, `{a, b}` is
    `some` of a struct, and a `T` of a `T??` is wrapped twice (#229).
    - So is a bool, or a number of another kind, where a number's
      Optional or Result goes (#415), as kelvinc converts it: `let
      c:int64? = true` is `some(1)`, `let d:float64? = n` of an int32
      `some(6.0)`.
    - A number where a `bool?` goes is still C's error.
  - **Printed** (#229) as kelvinc prints it: `some(3)`, `none`,
    `some("kelvin")`, `ok(5)`, `err("bad")`, an enum's `num(5)`, a
    struct's `{x: 1, y: 2}`, and an Array's `[1, 2]`, `[]` where empty
    (#230), and a Dictionary's `{"ann": 31}`, `{}` where empty, its
    entries in the order added, a String key quoted (#268).
    - Each type printed gets a `_kv_show_T` of kelvinc's form, declared
      before the functions and written after them; `print` calls it
      where the value stands.
    - What it holds is a number, a bool, text, or another Array,
      Dictionary, enum with values or struct of them; anything else, as
      a pointer, is an error.
  - `x ?? d`, `if let some(v) = x { } else { }`, and what any enum with
    values has: `.is(c)`, `.some`, `.ok`, `.err`, `switch`.
  - `none`, `ok(v)` and `err(e)` where a variable of the type is
    declared or assigned (#341): `let n:int64? = none`, `n = none`,
    `r = err($"late")`, a member's `k.s = none`, an element's and an
    entry's, `d[k] = none`.
    - A case the type has not is kelvinc's error in its words: `a
      Result has no case 'none': write err(e), or ok(v)`, `an Optional
      has no case 'ok': its cases are none and some; a Result has ok
      and err`.
    - `var x = none` needs a type, as kelvinc says.
  - A case's value of another type is kelvinc's error in its words
    (#413), as kelvinc's #411: `case 'ok' of Result<i64, String> holds
    an i64, and this is String`.
    - Of `ok(v)` and `err(e)`, a `T` wrapped where a `T?` or a Result
      goes, `T.c(v)`, a side of `==`, and `r ?? ok(v)` alike.
    - An Optional where a value goes, and a struct of another type,
      are kelvinc's earlier errors of them: `this is String?, an
      Optional, where i64 goes`, `Q is not P`.
    - A case word kc asked the type of, which has none, is passed by:
      `r == ok(5)`, `f(ok(3))`, `ok(none)` of a `Result<T?, E>`; text
      where a `String?` goes is `some` of a String.
  - `x ?? d` of an Optional that owns (#340), as kelvinc's #250:
    `d.lastKey(v) ?? $"none"`, `w[k] ?? "none"`.
    - x's value is a copy where x is a place, else taken from it.
    - d is a copy where it is a place, else taken, and is made only
      where x is none.
    - d of another type is kelvinc's error in its words, of any `??`:
      `'??' of String? falls back to a String? or a String, and this
      is a number`.
    - kc reads `??` left to right, where kelvinc reads it right to
      left (#251); `a ?? b ?? 0` gives the same value of both.
  - `x ?? d` of a Result (#407), as kelvinc's #253: what x holds
    where it is ok, else d: `half(7) ?? -1`, `f.string ?? $""`.
    - x's value is a copy where x is a place, else taken from it; an
      `err` taken is freed, as kelvinc frees it.
    - d of another type is kelvinc's error in its words, as of an
      Optional; a Result on the left of no Optional or Result is too:
      `'??' takes an Optional or a Result on its left, and this is i64`.
  - `r ?? r2` of two Results of a type (#408), as kelvinc's #253: r
    where it is ok, else r2, a Result: `bad ?? parse_digit('2')`.
    - r is a copy where it is a place, else taken, and freed where it
      is an err; r2 is a copy where it is a place, else taken, made
      only where r is an err.
    - `r ?? r2 ?? 0` is an `int64`, read left to right as kc reads
      `??`.
    - `r ?? ok(v)` and `r ?? err(e)` (#410), as kelvinc's #254: the
      words make a Result of r's type, `bad ?? ok(0)`, `w ?? err(4)`,
      a place in them taken, as kelvinc takes it.
      - Of a Result whose value is an Optional or a Result, the word
        is what it holds, as kelvinc's.
      - `some(v)` on the right of a Result, and `ok(v)` or `err(e)` on
        the right of an Optional, are kelvinc's errors in its words.
  - `a ?? b` of two Optionals of a type (#409), as kelvinc's #252: a
    where it has a value, else b, an Optional; so is `a ?? none`.
    - Held, copied, taken and freed as `r ?? r2` is.
    - Of a `T??`, b a `T?` or `none` is what a holds, as kelvinc's:
      `twice ?? none` is a `T?`.
  - `==` and `!=` of an Optional (#343), as kelvinc's #79: two `none`,
    or two equal values, by `_kv_opt_T_eq`, the same case and then
    the values' `==`.
    - The other side is a `T?`, a `T`, wrapped, or `none`: `a == 3`,
      `x != none`, `s == "hi"`; each side is read once.
    - An owner made here, `name(2) == $"n2"`, is freed after; a place
      wrapped, `s == w`, is copied, where kelvinc moves it.
    - An Optional's elements in an Array or a Dictionary compare too:
      `ns == ms`, `ns.contains(none)`, `d.firstKey(none)`.
    - kelvinc's errors, in its words: `i64? has no operator '<':
      compare with == and !=`, `'==' compares two i64?, and this is
      String?`, and of one whose value has no `==`, a struct's.
    - Of another enum with values, the same since #345.
  - `==` and `!=` of a Result (#344), the same way: the same case,
    and equal values, by `_kv_res_T_E_eq`.
    - The other side is a Result, a `T` wrapped as `ok(T)`, `ok(v)`
      or `err(e)`: `r == 42`, `e == err($"empty")`.
    - `ok(v)` and `err(e)` made here are freed after; a place in
      them, `ok(w)`, is copied, where kelvinc moves it.
    - A Result's elements compare too: `rs.contains(err($"x"))`.
    - kelvinc's errors, in its words: `case 'err' holds P, which has
      no '=='`, `a Result has no case 'some'`.
    - A `T` where a Result goes, `let p:Result<i64, i32> = 3` or
      `return s`, is `ok(T)` too.
  - kc's own `load` gives `Result<int64, String>`, and `case_named` an
    `int64?`.
  - **Chains** (#221), as kelvinc's of #218: `x?.m`, `x?.f(...)` and
    `x?[i]`, with the `?` right after `x`.
    - The rest of the chain is of a name kc binds to what `x` holds,
      `_kv_chainN`. The chain gives `some` of what the rest gives, or
      `none` where `x` is `none`.
    - An Optional the rest gives is not wrapped again, so `a?.b?.c` is
      a `T?`.
    - An owner the rest reads, as `p?.name`, is copied out. An `x` an
      expression gives, as `f()?.m` or `d[k]?.m`, is read once and
      freed.
    - A `T?` that only a chain needs is made while the functions are
      written, and written before them.
- **Overloading** (#234): functions of one name and different
  parameter types, as kelvinc's (#41).
  - A call gets the overload its arguments fit best, as kelvinc's `fit`
    scores them: the very type over a number, a `bool` among them, that
    converts; a text literal fits a `String`; `none` an Optional alone;
    a `T` a `T?` only where nothing else fits (#222).
  - A tie, and arguments no overload fits, are errors: C's function of
    the name is not called beside a Kelvin one (#223).
  - A prototype and its definition are one overload; a function
    declared and never defined is C's, and keeps its name.
  - In C each defined overload is named as kelvinc names it,
    `twice__i64`, `twice__String`, `show__vecp`, `kind__opt_i64`,
    `f__void`.
  - A call of a name that a variable hides is an error, where kelvinc's
    C would not compile.
- **Methods** (#213): `extend T { let m(...) ... static let f(...) ... }`
  and `let T.m(...)`; inside, `self`, `.x` for `self.x`, and `Self`.
  - `x.m(...)` is `T__m(x, ...)`, its receiver by value, and `T.f(...)`
    is `T__f(...)`: kelvinc's names, called straight, since kc sees the
    receiver's type where kelvinc lets C's `_Generic` choose.
  - `return {a, b}` is of the function's type.
  - **Where there is no self** (#602), `self` and `.x` are kelvinc's
    errors, in its words: in a function, a function of a type or a
    type's computed attribute, an anonymous function in a method,
    which C gives no closure, and a global's value.
    - gen.k's `self_known` asks it where it types `self` and where it
      writes it; an anonymous function's own function is found by
      `anon_outer`.
    - kc asked the receiver of a function that has none before, and
      ended with an index out of range; of a function of a type it
      left `self` to C.
    - A bare `self` in a function with no receiver kelvinc leaves to
      C, an undeclared identifier; kc says it, in words of its own.
  - **A var method** (#320), `var T.m(...)` and `var m(...)` in
    extend, as kelvinc's #318: `T__m(T *_kv_selfp, ...)`, `self` the
    caller's var through `#define self (*_kv_selfp)`, called as
    `T__m(&(x), ...)`.
    - On a let, through a const borrow, or on a value a call gives, it
      is kelvinc's error, in its words; so is a built-in type's, and a
      let method that changes `self`.
- **Iterators** (#320), as kelvinc's #318: `for x in it` walks a
  struct whose `var next():T?` gives each value, then `none`.
  - Each pass holds next's Optional, freed where it owns, and `x` its
    some; the iterator changes, a var by its address, and one an
    expression gives, `for x in count_from(3)`, is held.
  - A `next` of another shape, a let, or two loop variables are
    kelvinc's errors, in its words.
  - `map`, `filter`, `reduce` and `flatMap` of #319 wait, as an Array's
    do, where kc's anonymous functions do not go yet.
- **Sequences** (#322), as kelvinc's #321: `for x in s` of a struct
  whose `let makeIterator():I` gives an iterator walks
  `s.makeIterator()`, a fresh one held for the loop, so `s` stays as it
  was, a let too.
  - Where a struct has both `makeIterator` and `next`, `makeIterator`
    wins, as kelvinc's.
  - A var `makeIterator`, one that takes something or gives no
    iterator, and two loop variables are kelvinc's errors, in its words.
- **Anonymous functions** (#324), as kelvinc's: `{ $0 * 2 }`, its
  parameter `$0` typed by where it goes, its result its one expression's,
  and `{ (n:int64):int64 in ... }`, written; trailing, `s.lazy.map { ... }`,
  or in parentheses.
  - kc reads one as the function of `.lazy.map`, `.lazy.filter` and their
    kin, and, since #428, as a value anywhere one goes.
  - kc writes each as a function of its own, `_kv_<fn>_fnN`, after the
    others, enclosing nothing, as Kelvin's anonymous functions enclose
    nothing.
- **`Iterator<T>`** (#326), as kelvinc's #325: `Iterator(state) { ... }`,
  `Iterator(state, f)` and `Iterator<T>(...)`, of `kv_iter`.
  - Its function's `$0`, or first parameter, is the state itself, a
    pointer in C, `S *_kv_arg0_ref`, with `#define _kv_arg0
    (*_kv_arg0_ref)` around its body; kc writes `$0` as `_kv_arg0`, as
    kelvinc does.
  - `T` is what the first `return v` gives, the locals before it typed
    in turn, or written; kc writes the adapters `_kv_iterN_next` and
    `_drop` after the functions.
  - `for`, `it.next()` on a var, return and passing take it; a let, a
    copy, print and a function of another shape are kelvinc's errors.
  - A `{` inside parentheses keeps its lines, so a function written
    there, `Iterator(10, { (s:int64):int64? in ... })`, reads as one.
- **Eager map, filter, reduce and flatMap** (#329), as kelvinc's #182,
  #184 and #308: of an Array, a place or one an expression gives, held
  and freed; of an iterator, a Sequence or an `Iterator<T>`, whose
  values kc gathers into an Array first, as kelvinc does (#319).
  - The function is one of the program's, or one kc makes of `{ ... }`,
    `$0` and `$1` typed by where it goes: reduce's takes the value so
    far, then an element.
  - An element that owns is given to it as a copy, which it owns;
    reduce's value so far moves in and out; flatMap's Arrays are joined.
  - A function of another shape, a filter that gives no bool, and a
    flatMap whose function gives no Array are kelvinc's errors.
  - **A Dictionary's and a Set's** (#330), as kelvinc's #238, #307 and
    #308: a Dictionary's of its values, map keeping the keys, filter
    the entries it keeps, flatMap the Dictionaries merged, a later entry
    winning; a Set's of its elements, map a Set of integers or Strings,
    flatMap the Sets unioned.
  - Its parameters may be named, `{ v in v * 2 }`, `{ acc, v in ... }`,
    typed by where it goes (#330), as kelvinc's (#236).
  - **`mapWithKey`, `filterWithKey` and `reduceWithKey`** (#331), as
    kelvinc's #241: the function takes each key before its value, a
    String's as its text, a `cstr`, an integer as itself; mapWithKey's
    gives the new value alone; flatMapWithKey's a Dictionary, merged in
    (#332).
- **An Iterator's lazy map and filter** (#328), as kelvinc's #327:
  `it.lazy.map(f)` and `it.lazy.filter(f)` of an `Iterator<T>` give an
  `Iterator<U>` of it, moved in, whose adapter `_kv_iterN_next` asks it
  for each value and calls f as it is asked; a plain Iterator, so a
  chain writes `.lazy` again.
  - A function trailing a method call's parentheses, `x.m(a) { ... }`,
    is its last argument, so `.lazy` before another method is kelvinc's
    error, in its words.
- **`x.prefix(n)` and `x.prefix { ... }`** (#372), as kelvinc's:
  Haskell's `take` and `takeWhile`.
  - Of an `Iterator<T>`, an iterator or a Sequence: an `Iterator<T>`,
    lazily.
    - Its state, `struct _kv_iterN_st`, holds the base, the count left
      and whether it is done.
    - The base moves in; a Sequence gives a fresh iterator and stays.
    - So `Iterator(-1) { ... }.prefix(10)` ends, and chains.
  - Of an Array, a String, a Dictionary or a Set: a new one of its kind.
    - A String's function takes each codepoint, a `uchr`.
  - A value that owns is given to f as a copy, which f owns.
  - A count that is no integer, and a function that gives no `bool`,
    are kelvinc's errors, in its words.
- **`Range<T>`** (#373), as kelvinc's: a range is a value.
  - `a..<b`, `a...b`, `a...` to its type's largest, `..<b` and `...b`
    from 0, of kc's integers; `...` is a token now.
  - Its struct, `_kv_range_T`, is written where a program makes one.
  - `for i in` takes every form, and `for i in r` a Range value.
  - `map`, `filter`, `reduce` and `flatMap` gather its values; one
    without an end is kelvinc's error, or ends the program.
  - `.lazy.map`, `.lazy.filter` and `.prefix { ... }` walk an Iterator
    kc makes of it, `_kv_iterN`; `.prefix(n)` is a Range.
  - It prints as written, `0..<5`; its other operators and members are
    kelvinc's errors, in its words.
  - `r.count`, an `i64` as kc's counts are, and `r.contains(x)`, compared
    as a `__int128` (#374); a count without an end is kelvinc's error,
    or ends the program.
  - `r.lowerBound` and `r.upperBound` (#375); the upper one without an
    end is kelvinc's error, or ends the program.
  - `r == s` and `r != s` (#376), of the kind and the bounds by value, an
    Array's and an Optional's of them too.
  - `xs[r]` (#377), a slice of an Array or a String by a range written,
    `xs[1..<3]`, or a value, a new one; what an expression gives is
    held while it is copied.
  - `r.reversed()` (#378), an Iterator kc makes of it that steps down,
    iter_rec op 6; one without an end is kelvinc's error, or ends the
    program.
  - `r.stride(n)` (#379), an Iterator kc makes of it that steps by `n`,
    a `T`, iter_rec op 7, down from the end of a negative one; a step of
    0, a negative one of an unsigned `T` or of one without an end, and
    `stride(by: n)` are kelvinc's errors.
- **Powers** (#380), as kelvinc's: `b ** e`, tighter than a prefix on its
  left and right to left, of kc's integers by multiplying in a u64, which
  wraps, and of its floating-point numbers by C's pow; two literals
  worked out, the floating-point ones by C's pow, which kc calls;
  `b.pow(e)`, `b.pow(e, m)` by the runtime's kv_pow_mod, and `x **= y`.
  kelvinc's errors, in its words.
- **`x.abs`** (#381), as kelvinc's: of kc's signed integers, negated in
  the unsigned type, where the least wraps, and of its floating-point
  numbers, fabs; its unsigned ones have none.
- **`x.sign`** and **`x.isNaN`** (#382), as kelvinc's: -1, 0 or 1 of a
  signed integer's type, a floating-point number's as the next entry
  says; whether a floating-point number is NaN.
- **A floating-point number's fields** (#383), as kelvinc's: `x.sign`
  -1 or 1, an i64, by its sign bit (#597), where it was a `bool?`,
  `x.exponent` and `x.significand` the two integers it is with it,
  `sign * significand * 2^exponent`, the significand odd (#598), where
  they were IEEE 754's raw fields; each set in the var that holds `x`,
  `x.sign = -1`, `x.exponent += 1`, the sign -1 or 1 or the program
  ends; and `b ?? false` of a `bool?` a bool, which prints `true`.
  - The two are kelvin_prelude.h's `kv_f64_exponent`,
    `kv_f64_significand`, `kv_f64_set_exponent` and their kin, which
    gen.k calls as kelvinc does.
  - `f64(sign, exponent, significand)` and `f32`'s (#598) are
    `gen_converter`'s, of three integers, `kv_f64_make`.
- **`x.isInfinite`** and **`x.isFinite`** (#384), as kelvinc's, Swift's
  pair beside `x.isNaN`.
- **Names past ASCII** (#385), as kelvinc's: ident.k, which
  tools/gen_ident.py writes from tools/ucd/, has UAX #31's XID_Start and
  XID_Continue and emoji; the lexer takes them, ascii_names spells them in
  ASCII in the C, `_kv_u...`, and a name past ASCII unknown, used before
  it is declared, or declared twice in a block is kelvinc's error, in its
  words; arithmetic of literals alone infers an i64 or an f64, each
  integer reckoned an i64.
- **`fallthrough`** (#386), as kelvinc's, Swift's: a goto to a label on
  the next case's block, `_kv_fall` and that case's node; outside a
  switch, in its last case, or into a case that binds, kelvinc's error, in
  its words.
- **`Bits`** (#387), as kelvinc's: Y_BITS, the prelude's `kv_bits`;
  `Bits(n)`, `bv[n]` read and set with `=`, `|=`, `&=` and `~=`,
  `bv.flip(n)`, `|`, `&`, `~`, `==` and `!=` of two, `~bv`, `<<` and
  `>>` and their assignments, through the prelude's kv_bits_ functions;
  `!!n`, two adjacent `!`, the bool of an integer 0 or 1; the shifts of
  integers too, `>>` lexed as one and split where it closes a type's
  `<...>`. kc had no u64, so `bv.value` was what only C sees; #455 took
  it away. kelvinc's errors, in its words.
- **Unnamed parameters** (#388), as kelvinc's: a parameter written `_`
  is a token kc makes, `_kv_argk` of the k-th, or `$k` of an anonymous
  function's, which its body may read; `_` may stand for several; `for _
  in` declares no name, and reading `_` or any `_kv_` name is kelvinc's
  error, in its words.
- **Types defined inside a struct** (#389), as kelvinc's, Swift's: a
  struct or an enum in a struct's body is a token kc makes, `point__kind`,
  its C name, written before the struct; nested_of, outer_of and own_of
  keep each, and scoped_type and type_path read a bare name in the struct
  and its methods, a local's name aside, and a path, `point.kind`, in a
  type, an expression and a method's or an extend's head; kelvin_name
  spells it so in kelvinc's errors, in its words, and in a wrong case's;
  kc_made tells it from an Optional's and a Result's.
- **`for c in` a cstr** (#390), as kelvinc's #30: each byte up to the
  NUL.
  - Of a cstr, `s` or `t.cstr`, `c` is a `u8`, so `print(c)` prints
    `104`.
  - Of a literal, `"hi"`, it is C's `char`, what only C sees, as kelvinc
    sees no type of a literal: `print(c)` prints `h`.
  - kc died of an index of -1 there before: it took a cstr for an Array.
- **Types defined in a block** (#391), as kelvinc's: a struct or an enum
  among a block's statements is a token kc makes, `_kv_main_point`, of the
  function and its name, written before the function; local_types keeps
  it to the block's end, ahead of a type of the top level, and a C enum's
  enumerators are the block's, `_kv_main_red`, until an enum turns out to
  have values; a name twice in a block, one whose block has ended, and a
  method of such a type are kelvinc's errors, in its words.
- **`inline`** (#392), as kelvinc's: before `let`, or before or after
  `static` in `extend`, a function or a method in inline_fns, whose
  signature gen_signature writes `static inline`; kelvinc's errors, in its
  words.
- **`restrict`** (#393), as kelvinc's: after a `^`, a pointer type
  whose name is 2, or 3 where it points to a const T, ptr_const and
  ptr_restrict telling them; put_ctype writes `T *restrict`; elsewhere
  kelvinc's error, in its words.
- **`static_assert`** (#394), as kelvinc's: S_ASSERT in a block and
  D_ASSERT at the top level, `_Static_assert` in C, the message as
  written or the condition's own text, a variable in the condition and
  C11's spelling kelvinc's errors, in its words.
- **`alignof(T)` and `x.align`** (#395), as kelvinc's: N_ALIGN, and a
  field `align` that is no struct's own, value_align; gen_align writes C's
  `_Alignof`, of a value its `__typeof__`'s, an i64 as kc has no size_t;
  `_Alignof` and `alignof` of a value kelvinc's errors, in its words.
- **`sizeof`** (#420), as kelvinc's: N_SIZEOF, of a type or a value.
  - `sizeof(T)` where its parentheses open with a type: a built-in
    type's word, `const`, `[`, `$[`, `Self`, or a struct's or an enum's
    name, which is a variable's where a variable in scope has it.
  - `sizeof x` and `sizeof(x)` of a value, a compound literal's too,
    `sizeof (point){1, 2}`; a function's name a pointer's size, and a
    name kc does not know C's, `sizeof(size_t)`.
  - gen_sizeof writes C's sizeof, an i64 as `alignof`'s; `sizeof T` is
    kelvinc's error, in its words.
  - `sizeof(x.type)` (#421), as kelvinc's #34: x's size, of a path too,
    `p.x.type`, `a[0].type`, and of `x.type^` a pointer's; a struct's
    member named `type`, a C struct's and a value's kc does not know stay
    members.
- **`alignas`** (#396), as kelvinc's: parse_alignas before a global, a
  local or a struct's member, a number, checked where a literal, or a
  type; take_alignas keeps the variable or member in aligned, and
  put_alignas writes `_Alignas(...)` before its type; on a function, a
  struct or a statement, or twice, kelvinc's errors, in its words.
- **`_Generic`** (#397), left out on purpose, as kelvinc's: written, it
  is kelvinc's error, in its words, naming overloads.
- **`typeof`** (#398), as kelvinc's: `typeof(T)` is `T`, and `typeof(x)`
  of a variable is the type its declaration writes, written_type's; of one
  inferred, or of an expression, it is not kc's yet, and says so.
- **`x.type`** (#422), as kelvinc's #34, where a type goes: after `:`
  and `as`, in `[x.type](3)`, `x.type^` and `(x.type){...}`.
  - x is a variable whose type is written, read as kc parses, as
    `typeof(x)`'s; a path too, `p.x.type`, `q^.type`, `a[0].type`; a
    parameter's type an earlier parameter's, `acc:xs[0].type`.
  - Of a local whose type is inferred (#423), a Y_TYPEOF of x's path,
    which gen tells, told, just before it writes each statement; not yet
    in `T?`, `Result<T, E>` or a Dictionary's value, which kc makes as it
    parses, nor of a global whose type is inferred.
  - `x.type` as a value, `point.type` and `i64.type` are kelvinc's
    errors, in its words.
  - `$0.type` in an anonymous function (#424), and `v.type` of a
    parameter of `{ v in ... }`, by #423's way, gen telling it where it
    writes the function; outside one, kelvinc's error, in its words.
  - `const xs.type` of a fixed array (#425), `[const T](N)`.
- **`x.typename`** (#426), as kelvinc's #34: the Kelvin name of x's type,
  a cstr, of any value, a function's too, `(shade):cstr`; x is never run.
  - A literal's type is C's, `42.typename` `i32`, `"a".typename` `u8^`,
    as is what only C sees: C's `_Generic`, kv_typename.
  - A struct's member named `typename` stays the member; a Range's and an
    overloaded function's are kelvinc's errors, in its words.
  - Where kc's types differ: a count is an i64, where kelvinc's is a u64,
    and a number's own const is dropped.
- **A value returned without a result** (#427), as kelvinc's: `return v`
  in a function of no result is kelvinc's error, in its words.
  - A call that gives no value passes, as C's return of a void call does.
- **Function values** (#428), as kelvinc's #31 and #32: a function
  type, `(i64, cstr):bool`, `(i64)` of no result, for a parameter, a
  result, a variable, a global and a struct's member.
  - In C each is a typedef of its pointer, `_kv_fnN`, written before what
    uses it, and `struct T;` before one that names a struct not yet
    written.
  - A value of one is a reference, assigned with `:=`, `nowhere` until
    assigned: a function's name, `let g := twice`, or an anonymous
    function, `{ $0 + 1 }` where the type gives its parameters, and
    `{ (k:i64):i64 in ... }` anywhere, called in place too, `{ ... }(3)`.
  - A call through one, `g(3)`, `s.op(3)` of a member, `pick(true)(3, 4)`,
    passes each argument as its parameter's type, and says when their
    count is not the type's.
  - A type that is not the one wanted, an overloaded name, and printing
    one are kelvinc's errors, in its words.
  - Not yet: a function type that takes or gives an owner, kc's error; a
    variadic one, `(i32, ...)`.
- **Converters** (#429), as kelvinc's #36: `int64(v)` and the rest of
  kc's number types, and `bool(v)`, a number's C's cast.
  - Of text, a cstr, a String, a `u8^`, an array of `u8`, or a `?:` of
    them, the number in it, by the prelude's kv_text_int and friends, as
    strtol and strtod read it, clamped to the type: `int64("42")`, and of
    an integer type a base, `int64(s, 16)`.
  - What only C sees, C's `_Generic` chooses, KV_TEXT, as kelvinc's.
  - A base after a number or of a float, and a third value, are
    kelvinc's errors, in its words; a struct is kc's.
  - Not yet: the property form, `"42".i64`.
- **Short type names** (#430), as kelvinc's #151: `i64`, `i32`, `u8`,
  `u32`, `f64` and `f32` are `int64` and the rest, wherever a type goes,
  after `:` and `as`, in `sizeof(...)`, and as converters, `i64(s)`.
  - With #428 and #429, kc builds the README's Synopsis, a fizzbuzz
    (#431), with #433 its `main` of #432 too, `printf(...,
    fizzbuzz(i).cstr)`, and with #435 its `r.isEmpty` of #436; it prints
    what kelvinc's build prints.
- **An empty struct** (#498): a variable of a struct or a union with no
  members, an array of them, or a struct whose first member is one, is
  zeroed by `{}`, where kc's `{0}` was C's warning of elements in
  excess, or C's error where no element took it.
  - kc zeroes a variable written with no value, where kelvinc leaves it
    C's, unset.
- **`+x` of a struct** (#564), as kelvinc's (#563): its value where
  the type has a unary `-`, as a `BigInt`, a complex number and a
  rational have. kc's `+x` (#560) took no struct, so `+1n` was the C
  compiler's "invalid argument type".
  - It is a value and no place: of a variable, a member, an element or
    `p^` that owns, a copy by the type's `_copy`, a new owner as `-x`'s
    is; of a struct that owns nothing, and of what an expression
    gives, `+1n`, the value as it is.
  - gen.k: `plus_value` says whether a prefix `+` has a Kelvin struct,
    a union or an enum with values for its operand, and
    `gen_plus_value` writes it. The node stays a prefix, so it is no
    place, and one that owns is held as any owner an expression gives.
  - A type with no unary `-` is kelvinc's error, word for word: "'+'
    gives the value of a number, or of a type with a unary '-', and no
    operator - takes vec: ...".
  - So a `BigInt`'s `.hex`, `.oct` and `.bin`, `+0xffn`, paste back
    into kc too.
  - tests/run/plus_value.k is built by kc, and prints what kelvinc's
    build prints; sample.k has lines of it.
  - Not yet as kelvinc's: `&+n` of an owner is the C compiler's error,
    as `&-n` is, where kelvinc says "a borrow of a BigInt that an
    expression gives".
- **`0o52`, an octal number, and `0o17n`** (#562), as kelvinc's (#561):
  `0o` or `0O` and digits of 0 to 7, the text `n.oct` writes, the same
  number as C's `052`.
  - kc had handed `0o52` to the C compiler as it was written, which a
    recent one reads, C2y's, and an older one does not; and `0o17n`
    was C's "invalid suffix".
  - lex.k: `octal_literal` makes the token C's octal, `052`, so gen.k
    and the C written know it with no change; `big_literal` takes
    `0o` for base 8, `BigInt("17", 8)`.
  - What is not one is kelvinc's error, word for word: `0o18`, `0o`,
    `0o1.5` are "malformed number '0o18': an octal number is 0o and
    digits of 0 to 7, as in 0o17". Of `017n` the message names `0o`
    now, as kelvinc's.
  - tests/run/octal_literals.k is built by kc, and prints what
    kelvinc's build prints; sample.k has a line of them.
- **`+x`, the prefix** (#560), as kelvinc's: C's, the value itself, and
  a small integer's an `int32`, as `-x`'s is. kc had no prefix `+`:
  `+1` was "an expression is expected".
  - `+1` and `+1.5` are the numbers, and `+-1` is `-1`: parse.k drops
    the `+` before a number, so `let k:u8 = +200` fits as `200` does,
    and `var x = +1` is an `i64`.
  - Before anything else it is a node of its own, written `(+x)`:
    `+b` of a `u8` is an `i32`, `+f` of an `f32` an `f32`.
  - It took no operator of a struct, as kelvinc's took none: `+z` of
    a `c64` was C's error from both, until #563 and #564.
  - After `...` and `..<` it begins the range's end: `+1...+3`.
  - A line that begins with `+` goes on with the line before it, as
    it did: the binary one.
  - So a text with a sign pastes back into kc too: `+2.0`,
    `+0x1.8p0`, `(+0x1.8p0-0x1p+1.i)` of a `c64` (#558, #559).
  - tests/run's unary_plus.k, float_dec.k and complex_text.k are
    built by kc, and print what kelvinc's builds print; sample.k has
    a line of them.
  - Not yet as kelvinc's: `(+ok).typename` of a bool, of an enum's
    constant and of a character is kc's `bool`, the enum and `i64`,
    where kelvinc's is `i32`; so it is of `-ok` and `ok + 1`.
- **A fixed array of pointers** (#557), as kelvinc's:
  `var pp:[i32^](2) = [&a, &b]`, `let names:[const u8^](2) = ["a", "b"]`,
  an array of them in turn, a struct's member `at:[node^](3)`, and a
  parameter, `ns:[node^]`. kc took a number, a bool, a cstr or a struct
  for an element, and said "kc reads a fixed array as a variable ..."
  of a pointer.
  - gen.k's `fixed_elem_ok` takes a pointer; what the elements are is
    C's to check, as kelvinc leaves it: text for a `u8^`, `&x`, an
    array, `nowhere`.
  - **main's `argv:[u8^]`** is C's `char **`, as `u8^^` is (#524).
    - Either is now a variable of main's body, `uint8_t **argv`, of the
      `char **` C hands over, where it was a `#define` of a cast: so
      `var argv` steps, `argv := argv + 1`.
  - tests/run's pointer_step.k, pointers.k, references.k and
    references_params.k are built by kc now, and print what kelvinc's
    builds print; sample.k has a member, a parameter and two locals.
  - Not yet: an array of pointers shown by `print`; an element that is
    a function, `[(i32):i32](2)`; and `let ap := arr`, a pointer to an
    array by `:=`.
- **A hex float's fraction and its signed exponent** (#556), as
  kelvinc's: `0x1p-1074`, `0x1.8p+1`, `0x1.p3`, `0x.8p1`. kc read
  `0x1p4` since #472, and stopped a hex number at a `.` or a sign, so
  `0x1p-1074` was `0x1p` less 1074, C's error.
  - lex.k: after a `p` or a `P` of a hex number a sign before a digit
    is the exponent's; and a `.` is the number's where `hex_fraction`
    finds the rest of a float after it: hex digits, if any, then `p`
    and an exponent.
  - So `0xff.cstr` and `0xff.pow2()` are still a member's, the `p` of
    a name no exponent.
  - `0x1e + 3` is an addition, as it was; written `0x1e+3` kelvinc
    refuses it, as C does, and kc adds.
  - sample.k prints six of them; tests/run/float_constants.k, which
    compares `f64.leastNonzeroMagnitude` with `0x1p-1074`, is built by
    kc now.
- **`CBR`** (#552): modules/math+Rational.k, the overlay of math with
  Rational, is Kelvin alone, and kc builds it as it is: a struct of two
  BigRats, its operators with a BigRat, a BigInt or an `i64` on either
  side, and a BigRat's `.i`.
  - sample.k imports both modules, so it has `CBR`: the first overlay
    kc reads in the battery.
  - math's functions of a BigRat, to a precision (#553), are in that
    overlay too, Kelvin alone: kc builds them as kelvinc does, and
    sample.k prints `BigRat.pi(64)` and three more.
  - And a `CBR`'s (#554): sample.k prints Euler's `e^(i pi)`, a root, an
    `abs`, an `asin` on its branch cut and a whole power.
- **Overlays** (#551), as kelvinc's: where the modules `<A>` and `<B>`
  are both read, `A+B.kh`, else `A+B.k`, of ./modules or of the modules
  directory, is read too, with what it imports.
  - kc.k's `load_overlays`, after `load_prelude`: `module_names` holds
    each module read, by name, and each ordered pair is tried once.
  - kc reads the files one after another, so where an overlay stands
    matters to its aliases alone (#550): parse.k's `alias_order` passes
    the files as kelvinc reads them and places each overlay after the
    later of its two modules, before `alias_walk` reads any alias.
  - sample.k met one from #552 on, `math+Rational.k`, until #590 made
    it a part of `<BigNum>`; the tests of tests/project, built by kc,
    print what kelvinc's builds print.
- **math of the prelude** (#591), as kelvinc's `with_math`: kc.k's
  `load_math`, in `load_prelude`, reads modules/math.kh, takes the
  names it declares and the members it gives `f64` and `f32`, and
  keeps it where the files name one; else its tokens, its text and its
  file are taken away again.
  - parse.k: a header's `static let x:T` with no value is an extern,
    as kelvinc's, which `f64.tau` is; and an alias of a file no
    `#import` reads, `complex64`, reaches the files read after it, the
    program too.
  - kc.k names `pow`, so the stages are built with it.
- **Programs that import math** (#550): kc builds what
  `#import <math>` needs, where it stopped at the module's `typealias`,
  and its programs print what kelvinc's builds print.
  - **`typealias A = T`**, as kelvinc's #149: from there on `A` is `T`
    wherever a name is read, a struct, union or enum read before it or
    a built-in type; and `typealias op = (i64):i64` (#403) of a
    function type.
    - kelvinc reads an imported file where its `#import` stands; kc
      parses the program's file first, then the files it imports. So a
      pass before any is parsed, parse.k's `alias_pass`, walks the
      files as kelvinc reads them, each at the `#import` it was first
      read for.
    - An alias reaches what follows it there: the rest of its file, the
      files read for the imports in that rest, and what follows the
      `#import` its own file was read for. `complex64` of math.k is
      `c64` in the program that imports it, and the program's
      `typealias cx = complex64` is `c64` too.
    - kelvinc's errors, in its words: a built-in type's name, a name
      declared already, no `=`, a target that is no type, and
      parentheses that hold no function type.
  - **A type of a file imported**, where the parser asks whether a name
    is a type: `(c64){1.0, 2.0}` and `sizeof(c64)` in the program that
    imports it, where kc knew a struct only once it was parsed, later
    than the program.
    - parse.k's `scan_records` notes the structs, unions and enums at
      the top of every file before any is parsed.
  - **`self` has its own type** in a method of a number, a String or a
    Bytes, where it was a struct of that name: `exp(self)` in
    `extend f64` picks the overload of an `f64`, as math.k's methods
    ask.
  - **`Self(x)`**: the type's own maker, `c64(x)` in `extend c64`, or a
    number's converter, `f64(x)` in `extend f64`.
  - **A C header's name given to an overloaded function**:
    `copysign(INFINITY, y)` fits a parameter C converts it to, and
    where it leaves two overloads alike, `pow(z, NAN)`, C's `_Generic`
    chooses, as kelvinc's #41. It was read as `none` is, a word with no
    type of its own, and fit none.
  - **`-ffp-contract=off`**, kelvinc's (#43): kc's cc rounds `a * b + c`
    twice too, so `(z * conj(z)).imag == 0.0`, and `-Wno-psabi`.
  - Found on the way: an overloaded call whose argument is an
    overloaded call, `pow(c64(0.0), NAN)`, left the inner one's choice
    among the outer one's candidates, and kc ended on an index out of
    range; the candidates are cleared once the arguments are typed.
  - Not yet, and no part of importing: a pointer to a function type
    as a parameter, `out:((i64):i64)^`. A hex float, `0x1p-1074`, is
    read since #556, and a fixed array of pointers, `[u8^](2)`, since
    #557.
- **A function with no `$0`, trailing `map`** (#549), as kelvinc's:
  after `map`, `filter` and their kin a `{` that no condition ends is
  their function whatever it holds, `(0..<8).map { bool.random() }`,
  `xs.map { 7 }`; kc asked for a `$0` or written parameters, and said
  "a statement ends with its line".
  - In a condition's or a `for`'s head it still asks, as the `{` there
    may be the body's.
  - A statement that begins with a type's word, `{ i64.max }`, kc read
    already; kelvinc took it for C's declaration until #549.
- **`T.random()`** (#547), as kelvinc's: of an integer type, with a
  `Range<T>` or none, of a floating-point type, with a limit, a start
  and a limit or none, and of bool; written as kelvinc writes it, calls
  of runtime/random.k's `kv_random_u64`, `kv_random_span` and
  `kv_random_f64_in`.
  - gen.k's `random_of` and `gen_random`; `type_of` and `gen_method`
    ask them first, as `T` is no variable.
  - A range written there is of `T`, as where any `Range<T>` goes.
  - kelvinc's errors, in its words: arguments to bool's, two to an
    integer's, no range or another type's, a range to one of 128 bits,
    three to a float's, and text, a bool or a range there.
- **A floating-point type's constants** (#546), as kelvinc's:
  `f64.nan`, `f64.signalingNaN`, `f64.infinity`, `f64.pi`,
  `f64.greatestFiniteMagnitude`, `f64.leastNormalMagnitude`,
  `f64.leastNonzeroMagnitude`, `f64.ulpOfOne` and `f64.radix`, and
  `f32`'s, written as kelvinc writes them, `((double)KV_F64_INFINITY)`.
  - gen.k's `float_constant_c`, `float_constant_of` and
    `put_float_constant`, asked where `int_limit_of` is.
  - `f64.zero` and `f32.zero` (#596) are of them, `KV_F64_ZERO`; a
    rational's and a `BigFloat`'s three are their modules', stored or
    computed (#595), and need nothing of kc.
- **An integer type's limits** (#545), as kelvinc's: `T.min` and
  `T.max` of `i8` to `i128` and `u8` to `u128`, a `T`, written as
  kelvinc writes them, `((int64_t)INT64_MAX)`.
  - gen.k's `int_limit_of` and `put_int_limit`; `type_of` and
    `gen_field` ask them.
  - A type attribute of a number type, `static let i64.top:Self = 7`,
    is read as `i64.top`, as kelvinc's #148, where it was C's error:
    `resolve_attr` reads a number's word as it reads a struct's name,
    and `int64` is `i64` there too. The program's own `min` or `max`
    wins, as in kelvinc.
- **Programs that import Rational** (#542): kc builds what
  `#import <Rational>` needs, and the module's programs print what
  kelvinc's builds print.
  - So of `<BigFloat>` (#576), modules/BigFloat.k, which imports
    Rational: kc builds it as it is, and sample.k has a line of it.
    - And of its overlay with math, modules/math+BigFloat.k (#580),
      which imports the overlay math+Rational.k.
    - And of `CBF` (#581), the overlay's complex number of two
      BigFloats, and of math's functions of one (#582): kc builds
      them as they are.
    - They are one module since #590, modules/BigNum.k, with `CBR`
      and a BigRat's functions, the overlay math+Rational.k before:
      sample.k imports `<BigNum>`, and kc builds it as it is.
  - **A type's own text, `T.cstr()`**, as kelvinc's #53: `let
    T.cstr():cstr { `...` }` of a struct, a union or an enum with
    values, one template or one text.
    - `print`, `v.cstr`, `` `${v}` ``, and what holds a `T`, a struct, an
      Array or an Optional, show it.
    - kelvinc writes the template into the caller's buffer, which it
      sizes; kc's text of a value is its printer's, so to kc the method
      gives a String, shown whole, as `T.string`'s (#506).
    - kelvinc's errors, in its words: a built-in type's, `var`,
      parameters, a result that is no `cstr`, a body that is not one
      template, one written twice, one with no body, and one beside
      `T.string`.
    - `v.cstr()`, with parentheses, is no method, as in kelvinc.
  - **A number's methods**: `extend i64 { let over(d:i64):rat64 }` and
    `let f64.half():f64`, of any number's type, where kc read a `u32`'s
    alone (#527).
    - `int64` and `i64` are one receiver, and `Self` there is the
      number's type.
    - `1.over(3)` of a literal is an `i64`'s, and arithmetic of
      literals, `(1 << 40).over(3)`, is reckoned in an `i64`, as
      kelvinc's #538.
    - A number or a struct with no method of a name another type has is
      kelvinc's error of #539, in its words: `u8 has no method 'over':
      it is a method of 'i64', 'i32', 'i16', 'i8', 'BigInt'`.
    - `let x = 1 << 40` infers an `i64`, as kelvinc's #385; kc's
      arithmetic of literals had no `<<` and `>>`.
  - **A module that names BigInt**: kc.k reads each `#import <M>` before
    it asks whether the files name `BigInt` or `RegExp`, as kelvinc's
    with_imports, so Rational's `BigRat` has its BigInt where the
    program names none.
  - Found, and not kc's: kelvinc read a number's method only after it
    was written, where a struct's may come after (#505); #543 reads
    it, and sample.k's are written after `main`.
- **An overload picked by its type** (#537), as kelvinc's #41: an
  overloaded function's name, where a function type is written, is the
  overload of that type: `let h:(i64):i64 := over`, a global's,
  `v := over`, `apply(over, 2)` and `return over`.
  - gen.k's `pick_overload` keeps the choice in `fn_picked`, which
    `named_fn_type` and `gen_fn_value` read; `pick_call_args` picks an
    argument by its parameter's type, of a call by one function's name
    or through a function value.
  - With no overload of that type it is kelvinc's error; with no type
    written, `let h := over`, the name still "names 2 functions".
  - A global that holds a function's name has that function declared
    before it, where C had not seen it: `let top:(i64):i64 := twice`.
  - As kelvinc, kc picks none in a struct's member, an Array's
    element, a method's argument, or through `&over`.
- **`&f` is the function** (#536), as kelvinc's: `&f` of a function's
  name has the function's type, where kc made of it a pointer to one,
  `(i64):i64^`, which no call and no function's place took.
  - `let g := &f` calls as `g(x)`, and `&f` goes where a function goes:
    an argument, a member, an Array's element, a result.
- **`&` takes a place** (#535), as kelvinc's: `&x.i64`, `&f()`, `&5`
  and `&(x + 1)` are `no_place`'s values (#534), which have no address,
  and kc says so where C's "cannot take the address of an rvalue" was
  the error.
  - A name, text, and an owner an expression gives, which kc holds, are
    as they were.
- **An assignment's left is a place** (#534), as kelvinc's: gen.k's
  `no_place` names a left side kc sees is a value, a conversion, what a
  function, a method or an operator gives, a literal, a property, a
  function's name, or a member of one of them, and `gen_assign` says so
  where C's "expression is not assignable" was the error.
  - `p++` and `p--` keep their own messages.
  - A call kc has no function of is left to C, as a C macro may be a
    place.
- **`v.T` is `T(v)`** (#533), as kelvinc's #36: `b.i64` of a bool,
  `x.f64` of a number, `c.i64` of an enum's value and `"42".i64` of
  text are the converters' calls, which kc makes of the field read.
  - kc had none of them: `x.i64` was an unknown member.
  - A struct's field or attribute of that name stays its own, and so
    does a member of what only C sees.
  - Of a pointer or a fixed array it is the converter's error.
- **`Bits` is no more** (#532), as kelvinc's: kc's lexer says so at the
  word, `Bits(n)`, `Bits()` or a member's type, naming `x.bits` of an
  integer, `b.bits` of a BigInt and an `Array<bool>`.
  - Y_BITS is gone, with kc's `Bits(a, b, ...)`, a Bits's `bv[n]`, its
    `.append`, `.flip`, `.capacity`, `.count`, `.u64s`, `.bin` and
    `.copy`, its operators, its walk, its printing and its temporaries:
    gen.k's `gen_bits_assign`, `bits_part_ok`, `put_bits_push`,
    `bits_hold` and the rest.
  - What stays is `gen_bit_forms`: an integer's `x.bits` (#530), a
    bool's `b.flip()` (#457) and `!!n` (#387); `bit_number` checks a
    bit's place, an integer's and a BigInt's.
  - The entries before this one that name Bits are of their time.
  - sample.k's bits are a `u64`'s and a BigInt's.
- **A BigInt's `.bits`** (#531), as kelvinc's: `b.bits` is BigInt.k's
  attribute, an `Array<bool>`; `b.bits[n]` is its bit where it is, the
  call of BigInt.k's `kv_bi_bit_of(b, n)`, with no Array made;
  `b.bits[n] = v`, `|=`, `&=` and `~=` its `kv_bi_bit_put` of
  `&b.limbs`, and `b.bits[n].flip()` its `kv_bi_bit_flip`.
  - `BigInt([b, ...])` and `BigInt(bs)` of a fixed array of bools are
    its `kv_bi_from_bools` of them and their count; of an `Array<bool>`
    it is the `BigInt(bools:lent $[bool])` BigInt.k has.
  - kc reads `b:lent $[T]`, a lent Array parameter, which it took for
    an error where the type began with `$[`.
- **An integer's `.bits`** (#530), as kelvinc's: `x.bits`, its width of
  bools, a new `Array<bool>`, place 0 first, held and freed as `s.elements`
  is; `x.bits[n]`, its bit, read and set with `=`, `|=`, `&=` and `~=`
  where it is, and `x.bits[n].flip()`; an enum's value an `i32`'s.
  - `T(bools)` of an integer type reads a `[bool]` written, a fixed
    array or an `Array<bool>` through the prelude's kv_int_of_bools.
  - `x.bit(n)` and `x.flip(n)`, #457's, are kelvinc's errors that name
    the new forms; the entries before this one that name them are of
    their time.
  - kelvinc's `(x + 1).bits` takes kc's width, C's: 32 bools of a `u8`.
  - Not yet: `bs.u8`, as kc has no `v.T` of any value.
- **An enum with values prints as it is written** (#529), as kelvinc's:
  its printer writes the enum's name before the case, `num.n(1.5)`,
  `CodepointError.empty`, a nested one's path, `shape.kind.round`, so
  that the text pastes back; an untagged one, and kc's own Optionals
  and Results, `_kv_` names, stay bare.
- **What a struct holds that has no printer prints by its text** (#692),
  as kelvinc's text_writer: a pointer, its address or `nowhere`, a
  function's address, an IO `<IO>`, a plain enum's number, and a C
  header's type as C decides, where kc said "not yet what this holds".
  - tests/run's io_basics.k, local_types.k and nested_types.k, which kc
    refused, print what kelvinc's builds print.
  - A block's enum with values prints by its path, `pair.kind.sides(4)`:
    kc's own Optionals and Results, `_kv_opt_` and `_kv_res_`, alone
    stay bare, where every `_kv_` name did, a block's too (#529's).
- **A fixed array shown whole in a template and by `.pretty`** (#693),
  as kelvinc's #481: `${a}` is `[1, 2, 3]`, as print shows it, and
  `a.pretty` its elements a line each, at the level after the array's,
  as kelvinc's printer of one, where kc said "not yet in a template".
  - A let parameter's `[T](N)` is shown to its count as declared, where
    kc said "not yet a parameter's"; a var one's is kelvinc's error, a
    pointer that may have moved; a parameter's `[T]`, a pointer, is its
    address, and its `.pretty` kelvinc's error of a `T^`.
  - Found on the way and fixed: `for x in a` of an array of empty
    structs walks its declared count (#499's), where it walked none, as
    sizeof gave 0 / 0; and an empty struct prints `{}` at any level,
    where `.pretty` gave `{` and `}` a line each.
  - tests/run/empty_struct_count.k, which kc refused, prints what
    kelvinc's prints; template_bounds.k is built, and its `${w}` of a
    struct is the one difference left, listed in TODO.md.
- **An enum with no name and values, and the methods of a type with no
  tag** (#694), as kelvinc's #120 and #121:
  - `enum { red; rgb: {r: u8, g: u8, b: u8} }` at the top level is the
    type of its spelling, `_kv_anonN`, one with `enum{...}` written
    where a type goes, by anon_record_type; parse_enum makes no
    declaration of its own, and its cases are words of the program:
    `red` and `rgb(v)`, where no variable or function is named so, are
    `_kv_anonN.red` and `_kv_anonN.rgb(v)` from the first time gen sees
    them, resolve_anon_word.
  - `let enum{...}.m()`, `let {x: f64, y: f64}.m()` and `extend
    enum{...} { }` are of that type, its methods named
    `_kv_anon1__m` in C, as kelvinc's; kelvinc's errors of what extend
    of one holds stay.
  - A var method or attribute of an enum with values, named or not, is
    read, where kc said it was a built-in type's.
  - A line that starts with `.m` goes on with the expression before it
    where there is no self, as kelvinc's #35, `let q = b` then
    `.total()`.
  - tests/run's enum_anon_top.k, enum_anon_methods.k, extend_anon.k,
    self_type.k and self_member_lines.k, which kc refused, print what
    kelvinc's print.
- **Overloads of a variadic function** (#695), as kelvinc's #41 and
  #453: `total(n:i64, ...)` beside `total(s:const u8^)` is
  `total__i64__va` in C; it fits a call of as many arguments as its
  parameters or more, an exact fit of another wins, two are compared on
  the parameters both have, and C's `_Generic` choice falls back to it
  where no other takes the value there, where kc said "not yet one of
  several overloads".
  - Found on the way and fixed, as kelvinc's fit and value_type:
    - a call that C chooses for is of the result all it may choose
      have, or of what only C sees where they differ, so the call
      around it is chosen by C too, where the first gave its type;
    - text fits a `u8^` or an `i8^`, a cstr a `const u8^` exactly, and
      a pointer an `any^` and back, its const kept;
    - a fixed array fits an array parameter of its elements;
    - an overloaded function's name fits a parameter of one of its
      types, `apply(twice, 7)`, and is the overload of the parameter
      the call chose.
  - tests/run's overload.k and overload_unseen.k, which kc refused,
    print what kelvinc's print.
- **`x.type` and `typeof` of what kelvinc does not see** (#696), as
  kelvinc's #34 and #398: a Y_TYPEOF that gen tells, and where what it
  tells is only C's, `__typeof__(x)` in C:
  - `x.type` of a global whose type is inferred, where kc said "not
    yet"; of a C header's name, `errno.type`; of a member of a C type,
    `s.x.type`; of a variable whose written type is C's, `a.type`, its
    own `__typeof__(a)`, a parameter's a pointer; of an array of a count
    no number gives, which keeps its count as it was; and a function's,
    whose parameter is of such a type, `__typeof__(&g)`, its function
    type no typedef;
  - `typeof(e)` of an expression, or of a variable whose type is
    inferred, where kc said "not yet of an expression";
  - `(typeof(p)){...}`, `(const errno.type){6}`, `(errno.type){7}` and
    `(xs.type)[7, 8, 9]` as compound literals, and `(T){...}` of a type
    only C sees, where kc said "not yet of another type".
  - Found on the way and fixed, as kelvinc's: `:=` of a C type's
    variable, a call through a variable of a type only C sees, a range
    whose loop variable is of one, its counter `__typeof__((void)0,
    (x))`; `{ ($0:$0.type) * 3 }` a value, no parameters; `sizeof(any^)`
    a type's, `sizeof(f.type)` a pointer's; a member counted by a
    global or an enumerator; `struct cpt` and `((i64):i64)^` spelled so.
  - tests/run's type_property.k, type_property_edge.k and
    sizeof_c_pointer.k, which kc refused, print what kelvinc's print;
    typeof.k is built, `const i64` of a let's `typeof` the one
    difference left, listed in TODO.md.
- **A function defined inside a function** (#697), as kelvinc's #180:
  `let fib(n:i64):i64 { ... }` in a body is a function of the program,
  named in C by hidden_token as kelvinc names it, `_kv_main_fib`,
  `_kv_main_fib1` of another of its name in the same function; its name
  is its block's from its definition on, local_fns by depth, hiding one
  of the name outside and calling itself; parsed as a function at the
  top level is, the reading of the function around it kept, and put
  among decls. kelvinc's error of a local of the function around it
  stays; where kc said "not yet", tests/run/nested_function.k prints
  what kelvinc's prints.
- **A pointer walked up to a 0** (#698), as kelvinc's #30 and #610:
  `for v in p` of a pointer that is no list, and of what only C sees,
  `for _ in getenv("X")`, reads it once and walks it while it is not
  nowhere and what it points to is not 0, each `const
  __typeof__(*_kv_pN)`, where kc said "not yet up to a 0 or nowhere"
  and "does not walk what only C sees".
  - Found on the way and fixed: nowhere among a `[cstr]`'s elements,
    `["a", nowhere]`, as kelvinc takes it, where kc said it was of a
    type only C sees.
  - tests/run/for_each.k, which kc refused, prints what kelvinc's
    prints.
- **`[T?](n)` and an array of a count C computes printed** (#699):
  `[i32?](2)` is two Optionals, none each, where kc read `i32 ? ...`, a
  choice; and a fixed array shown whole, by print, a template or
  `.pretty`, reaches its elements through a pointer, `self->a`, its
  count read first, `_kv_fc`, so that `[f64](n)` prints to its count,
  where C refused a struct of a variable's length, and an array named
  `o` is counted, not #693's output of that name.
  - tests/run/print_fixed.k, which kc refused, prints what kelvinc's
    prints.
- **A global given its value at its first use** (#700), as kelvinc's
  #493: a global whose initializer is no constant, by kelvinc's
  const_init, a call, `$["a", "b"]`, `${"x": 1}`, `$/.../`, another
  global's value, is `static T _kv_lazy_x = {0}` with
  `static T *_kv_get_x(void)`; the getter, written before the
  functions, runs `_kv_init_x` once by `pthread_once`, which makes the
  value as a local `_kv_value` of a function and moves it in, and each
  use is `(*_kv_get_x())`; `#include <pthread.h>` where one is, and at
  exit the storage is freed.
  - `$[]`, `${}`, `${:}` and `$"..."` stay constants, as kc writes
    them so, where kelvinc gives an owner's every value at first use:
    the same value either way, and kc's own globals stay plain.
  - A value's text in a global's initializer, `String(n.dec)`,
    `String(p.cstr)`, is made in the getter, where kc said "not yet in
    a global's initializer"; a template stays kelvinc's error.
  - tests/run's global_first_use.k, converter_clamp.k and
    operator_lent.k, which kc did not build, print what kelvinc's
    print.
- **An atomic pointer** (#701), as kelvinc's #642: `var p:i64^ atomic
  := &x` is a pointer type of konst 2, as an atomic number's,
  atomic_pointer, which put_ctype writes `int64_t *_Atomic`, where kc
  said "no atomic pointer yet"; its typename `i64^`, as kelvinc's.
- **A type with no name in a block or inside a type** (#702) is
  kelvinc's error, which kc says as it does: `enum { ... }`,
  `struct { ... }` or `union { ... }` in a block, "declarations are
  written 'var name:type', as in 'var x:T'", and inside a struct,
  "expected a name, found 'union'", at the word, where kc said "not yet
  in a block", "not yet inside a type", "expected ';' or a new line" or
  that a member says its type; tests/error's block_type_no_tag.k and
  member_type_no_tag.k say so.
- **A parameter's array of arrays whose inner count C computes**
  (#703), as kelvinc's #366: `m:[[i64](n)](2)` is a pointer to rows of
  n, `__typeof__(int64_t[n]) * m`, put_ctype of a fixed array of a
  count C computes writing it as one of a number, where kc said "not
  yet" (vla_pending, gone); tests/run/param_rows_computed.k, new, says
  so.
- **A fixed array of Optionals given its elements** (#704), as
  kelvinc's: `([i64?](2))[none, 1]` and `var ys:[i64?](3) = [5, none,
  7]`, none and a value some(v) is made of, which fixed_list_fits took
  for no element of an i64?; tests/run/fixed_optional_elements.k, new.
- **A key, a Set's element and a fixed element where the type is
  written** (#705), as kelvinc's check_dict_key and its Array of a
  fixed array: cstr_key takes an integer of 8 to 64 bits or a String
  alone, of `Dictionary<K, V>`, `${K: V}`, `Set<T>`, `${T}` and their
  makers, and fixed_element refuses a fixed array as an Array's element
  or a Dictionary's value, `Array<[i64](2)>`, at the type's start,
  where kc built `Set<f64>`, `Set<bool>` and `Dictionary<f64, i64>`
  and said the rest at the variable; tests/error's set_key_float.k,
  array_of_fixed.k and dict_value_fixed.k, new.
- **A choice of bools is a bool** (#706): `a < b ? a > 0 : b > 9` is
  `((bool)(... ? ... : ...))`, as kelvinc casts it, where C's ?: of two
  bools, an int, printed `1`; tests/run/conditions.k prints what
  kelvinc's prints.
- **A record's text, `.cstr`, as kelvinc writes it** (#707), its
  emit_derived_cstr: a struct, a union or an enum with values of no
  text of its own, each member of a text kelvinc's text_writer writes,
  has `enum { _kv_T_cstr_size = ... }`, its longest text by text_bound,
  and `_kv_T_cstr(self, buf)`, written after the printers' prototypes,
  what it holds first: `{x: 1, xs: [1, 2, 3], tags: [...], name:
  "n"}`, an Array, a Dictionary or a Set member cut to `[...]` or
  `{...}`, `<union bits>`, `shape.at({x: 3, y: 4.0})`.
  - `v.cstr` of one is `_kv_T_cstr(v, _kv_textN)` in its block's
    storage, and `${v}` in a template its text to `_kv_T_cstr_size -
    1`, in `$`...`` whole, where kc wrote the printer's text, the
    elements, cut at KV_TEMPLATE_STR; print is the printer's still.
  - tests/run's print_values.k and template_bounds.k print what
    kelvinc's print.
- **`typeof(k)` of a let keeps its const** (#708), as C23's typeof and
  kelvinc's #398: const_number, a number's or a bool's type of konst 1,
  as [const T](N) is, which put_ctype writes `const int64_t` and
  type_text names `const i64`; tests/run/typeof.k prints what kelvinc's
  prints.
- **`x as T ? a : b` a choice, and `&$"b"` held** (#710): the type of
  `x as T` or `x:T` takes no `?` of its own, as kelvinc's TYPE_AS, so
  that `i < .array.count as i64 ? .array[i].copy() : Self.nil`, of
  modules/SION.k, is a choice, where kc read `i64?`, by type_depth and
  cast_depth; and a borrow a search takes of a String an expression
  gives, `$"abc".has(&$"b")`, is held and freed after, as kelvinc's,
  where C refused the address of a call.
  - tests/run's hex_exponent_sign.k, json_eq.k, msgpack_pack.k,
    msgpack_unpack.k, sion_parse.k, sion_stringify.k,
    sion_subscript.k, temporaries.k and unicode_graphemes.k, which kc
    did not build, print what kelvinc's print.
- **`Optional<T>()` and `Optional<T>(v)`** (#711), as kelvinc's #222:
  the typed none and some(v), as `Optional<T>.none` and
  `Optional<T>.some(v)` are, where kc said "expected '.'"; a choice of
  one and none is of its type; a typed word fits that type alone among
  overloads; none in a choice of owners, or given where an owner goes,
  is no place; and an owner variable moved into a `T?` parameter is
  some of it, `_kv__kv_opt_String_make_some(kv_string_take(&s))`,
  where kc took it as the Optional's own.
  - tests/run's optional_basics.k, optional_args.k, ternary_none.k and
    coalesce_owner.k, which kc refused, print what kelvinc's print.
- **An Optional's and a Result's `.map`, `.flatMap` and `.mapErr`**
  (#712), as kelvinc's #80 and #81, which kc said kelvinc's errors of
  and refused where they fit: the function, made of `{ ... }` of the
  case's value by anon_function_of, named, or a function value, gives
  U, and x.map(f) is a U?, or a Result<U, E>, r.mapErr(g) a Result<T,
  U>, x.flatMap(f) U itself; written as kelvinc writes it, x in a
  temporary, f of the case's value made into the new one's same case,
  the other case carried over, what an owner holds taken out so that
  the temporary's cleanup frees nothing of it.
  - tests/run's variant_map.k, variant_flat_map.k and
    anon_optional_result.k, which kc refused, print what kelvinc's
    print, and run clean under ASan and UBSan.
- **A Bytes's Base64, slice and `+`** (#713), as kelvinc's #155 and
  #188, where kc said "not yet": `b.toBase64(url, nopad)`, a String,
  `kv_bytes_base64(&b, url, pad)`, the words read before the count of
  arguments; `Bytes.fromBase64(text)`, a Bytes of a cstr or of a
  borrowed String's bytes, as `Bytes.unescape` is; `b[lo..<hi]`,
  `kv_bytes_slice`, as an Array's and a String's slice; and `b + c`,
  is_bytes_plus, a new Bytes, `({ kv_bytes _kv_cat = ...;
  KV_BYTES_APPEND(&_kv_cat, ...); _kv_cat; })`, the left one a copy of
  a variable's, the value an expression gives, or of text, the right
  borrowed of a variable, else taken.
  - tests/run's base64.k, string_escape_edges.k, slices.k,
    slice_range.k and bytes_concat.k, which kc refused, print what
    kelvinc's print, and run clean under ASan and UBSan.
- **A switch's empty last case, a pointer's element, IO.strerror, an
  enum's compound literal** (#714), as kelvinc's: a case with no body
  is kelvinc's error only where another case follows it, so `default:`
  may end a switch empty; `p[i] = v` through a let parameter `p:u8^`
  changes what p points to, not p, C's to judge of a const one, as
  kelvinc leaves it, where kc said p is a let; `IO.strerror(code)`, a
  String of kv_os_strerror, as OS.strerror; and `(shape){.rect = {2.0,
  3.0}}`, an enum with values' compound literal, its braces written as
  a value of the type, where kc read (shape) then a block.
  - tests/run's switch_cases.k, duff_fallthrough.k and io_isatty.k,
    and examples/bfc.k, bfi.k and results.k, which kc refused, print
    what kelvinc's print.
- **Forms of statements** (#715), as kelvinc's:
  - a binary operator at a line's end goes on with the next line, in
    its own file, `price -` then `count`;
  - `$"a" "b"`, C's adjacent literals after a String's;
  - a label, `again:` on its own, S_LABEL, and `goto again`, S_GOTO,
    C's, where `x:i32` stays kelvinc's error of a bare declaration;
  - `[[2] = 9, [0] = 1]`, N_ADESIG, C's designators of elements;
  - `(T){` in a condition a compound literal only where the expression
    goes on after its }, as kelvinc's brace_is_compound, so that `if n >
    sizeof(int64) {` opens the body, `(i64){2}..<4` in a for still one;
  - a comma in an if's or a C for's condition, parse_comma_expr;
  - `let bag.each(f:(i64));`, a method's prototype, as a function's;
  - `var a = 1, b = 2` at the top level, each a global.
  - tests/run's semicolons.k, dollar_shortcuts.k, statements.k,
    conditions_edge.k, templates.k and template_storage.k, and
    examples/lambda.k, which kc refused, print what kelvinc's print.
- **Appends to an Array** (#716), as kelvinc's:
  - `xs += &ys` and `xs.append(&ys)` of an Array of the same type append
    its elements, `_append_ref`; such an Array an expression gives is
    appended and freed, `_append_owned`, as kelvinc's array_append_kind;
  - `ps += &p` of a plain element appends what it points to, `(*(&p))`,
    as kelvinc's element_copy;
  - `ws.append("lit")`, text where a String element goes, is a String of
    it, `KV_STRING_LIT`;
  - `xs.capacity`, an i64, the Array's room, `.cap`;
  - tests/run's array_elem_values.k, array_heap.k, array_owners.k and
    append_borrow.k, which kc refused, print what kelvinc's print.
- **Arrays of literals, `:=` of an array, sizes** (#717), as kelvinc's:
  - `let s:[u8] = "hi"`, C's array of text, `const uint8_t s[] = "hi"`,
    its count C's, its typename `[u8]`, `s.count` C's sizeof; text for
    a `[T](N)` of any T, C's to judge;
  - `[[T]]` and `[[T]](N)` of rows, and `([[T]])[...]`, every count from
    the first row, counted as `counted` counts a compound literal's;
    their rows' counts checked as written, first, as kelvinc's;
  - `let ap := arr` of a fixed array, a pointer to its first element,
    `i32^`, `const i32^` of a let's or a `[const T]`'s; of an array of
    arrays a pointer to its first row, `[i32](2)^`, whose `ap[i]` stays
    kc's error of #362;
  - a variable inferred from `sizeof`, `x.size`, `x.align`, or the
    count of a String, a Bytes, an Array, a Dictionary, a Set, a cstr or
    a fixed array is C's `size_t`, as kelvinc's arg_type, where kc
    inferred an i64;
  - tests/run's array_literals.k, array_nested_counts.k and
    infer_seen.k, which kc refused, print what kelvinc's print.
- **`.pretty(n)`, `cstr restrict`, `$(...)` of a static function, an
  anonymous function's `:()`** (#718), as kelvinc's:
  - `v.pretty(n)`, n a literal of 0 to 10 or an integer
    `kv_out_width` clamps, a new String, in println and anywhere a
    value goes, as a template's was already, pretty_width_ok and
    gen_pretty_string; another value in kelvinc's words, text, its type
    or not one, and a second argument kelvinc's parser's error at its
    comma;
  - `cstr restrict`, a cstr type of name 2, `const uint8_t *restrict`,
    its typename `cstr restrict`; type_of_kind tells cstr types by
    their name;
  - `$(...)` in a `static let` of a type, a call of `T.f(...)`, where
    only a method with a self is kelvinc's error;
  - `{ (n:i64):() in ... }`, no result, as `(i64):()` written, the
    type kelvinc spells `(i64)`;
  - tests/run's print_pretty_width.k, restrict_pointers.k and
    void_result.k, which kc refused, print what kelvinc's print;
    self_call.k goes on to `$(...)` in an anonymous function, of the
    group of anonymous functions.
- **Anonymous functions** (#719), as kelvinc's:
  - `{{ $0 + 1 }, { $0 - 1 }}`, a list of initializers that hold
    functions: anon_ahead takes a `$0` in a brace within for the outer
    one only where no comma at its level comes first;
  - `$(...)` in an anonymous function calls it, its N_ID named by
    anon_function_of when it makes its D_FN, self_call_ids; in a
    function inside a function, by its hidden name, local_fn_named;
  - `c ? f as (i64) : g`, the `:` the ?:'s where no type's word follows
    and a name may not be a type, fn_result_ahead of kelvinc's
    parse_fn_type; and a `?` or `:` that begins a line, or ends one,
    goes on, lines_before and lines_after;
  - a top-level struct's member counted by any expression, a local
    struct's still kelvinc's error; `sizeof` of a call in it written
    of the call's type, which no prototype need come before, where
    kelvinc writes its functions before the struct;
  - a global's or an enumerator's count reaches an anonymous function's
    `$0`; its parameters of `[T](N)`, written or the context's,
    pointers as a function's are, anon_fixed_params; a function type's
    parameter of a count C computes written `T *`;
  - tests/run's anonymous_lines.k, hidden_names.k and self_call.k,
    which kc refused, print what kelvinc's print.
- **Function types in containers, imports by another path, a case's
  literal** (#720), as kelvinc's:
  - `((i64):i64)^`, the parentheses grouping one function type that no
    result follows, fn_typed of kelvinc's parse_fn_type; `[op](2)`, a
    fixed array of functions; `[((i64):i64)^](2)`, zeros of a type that
    begins with `(`;
  - `#import "lib/../lib/late.k"`, a file read already by its real path,
    read_already, where the quoted imports compared the path as written;
    a header `"x.h"` that an imported file imports written by its real
    directory's path, as kelvinc's, put_header;
  - `var m:json = {.s = v}` where a variable `s` hides the case's word,
    written `json.s(v)`;
  - tests/run's function_type_containers.k, import_boundary.k and
    enum_json.k, which kc refused, print what kelvinc's print.
- **`.pretty` of an enum, `async` of a function value, text in a
  brace-less for body** (#721), as kelvinc's:
  - `j.pretty` of an enum with values and no case of the name, its text,
    gen_pretty_string, where gen_field took it for a case's value, which
    a temporary held, `_kv_JSON_at_pretty`;
  - `async twice(21)` of a variable of a function type: the function
    kept in the environment, `_kv_fn`, with the arguments, values, the
    thread calling it, async_fns, gen_async_value;
  - `t := b.hex` as a brace-less C for body, the text's storage declared
    before the for, in the block that holds it, as kelvinc's, where its
    text lives: the body an S_BLOCK of flag 1, gen_stmt_kept, and
    text_outlived judging by the block storage_up names; a braced body's
    text still kc's error of #447;
  - tests/run's print_pretty.k, async_await.k and properties_lifetime.k,
    which kc refused, print what kelvinc's print.
- **Owners through function values** (#722), as kelvinc's: a call
  through a function value takes and gives owners, where kc said its
  function values took and gave none yet:
  - an owner variable given by value moves in, dead after the call, as
    into a function by its name, gen_fn_arg; a member of one is
    kelvinc's error of an owner moved only as a whole variable;
  - what the function takes by value is not held for the call, the
    function freeing it, hold_fn_args; a borrow's owner an expression
    gives is held, as hold_args holds it;
  - the owner it gives is the caller's, held or kept as a named
    function's result is;
  - tests/run's anon_owner_result.k and method_overload.k, which kc
    refused, print what kelvinc's print: the last of the unlisted
    failures the user ordered taught after #709.
- **A let's array const in C, and a list where no array is declared**
  (#724), as kelvinc's, the two differences found while #717 was made:
  - a let's local array is written with C's const, `const int32_t
    a[2]`, by put_fixed_decl, a pointer's own const after its star,
    `const uint8_t * const names[2]`; a global's `[const T]` of a let
    has one const where it had two;
  - a list where no array is declared is kelvinc's error in its words,
    list_refused: `'[...]' initializes an array, and this is
    Array<i64>: write a value`; a record's, an Optional's and a
    Result's say `a struct or union is initialized with '{...}'`; and
    `[T](n)` there is `'x' is an i64, and this is i64^`;
  - tests/error's brackets_not_array.k and zeros_not_array.k have them.
- **An Optional's empty braces are none** (#725), as kelvinc's since
  the same number, the user's answer:
  - `{}` where a `T?` is initialized is none, a struct's too, where kc
    wrote some of its zero, gen_value_of; braces that hold something
    are the T's initializer, wrapped, and `{}` of a Result is ok of its
    zero;
  - `(T?){...}`, `(Optional<T>){...}` and `(Result<T, E>){...}` are
    read, compound_ahead;
  - a global of an Optional, a Result or an enum with values is given
    its value at its first use, global_const, as kelvinc's, where C
    refused the initializer kc wrote;
  - braces given as an argument where an Optional, a Result or an enum
    with values goes, and braces assigned to a variable, are kelvinc's
    `a list is not a value here`, where kc built them;
  - tests/run's optional_empty_braces.k and tests/error's
    optional_braces_arg.k and braces_assigned.k have them.
- **`q[i]` of a pointer** (#726), as kelvinc's, the user's answer:
  - of a `[T](N)^` it is the array `i` rows on, C's `q[i]`, where
    gen_element said kc's own error of #362;
  - of a `T^` it is a `T`, type_of's, where it was a `u8` of any
    pointer: `p[1] += 300` of an `i64^` was refused, and `let x = p[1]`
    an `u8`;
  - tests/run's array_pointer_rows.k has them.
- **`#inline C { ... }`** (#727), as kelvinc's #197 and #198, the
  first of the 30 programs' batches: kc passes its C through to the C
  it writes, where its lexer checked it and refused it after.
  - The lexer makes it a token, T_INLINE, the C between its braces,
    the line going on after its `}`, where a comment of either kind
    may follow.
  - At the top level it is a D_INLINE, written where it stands among
    the globals: the functions written before it are declared first,
    for its C to call, and the structs and enums with values written
    after it are written after it, as they may hold its types.
  - Among a block's, an anonymous function's or a case's statements it
    is an S_INLINE, written as it stands after its `#line`, seeing the
    locals by their names; as the body of a statement or after a label
    it is kelvinc's error.
  - A `?` after a `?` in it is written `\?`, as kelvinc's
    untrigraphed: Kelvin has no trigraphs (#220).
  - What it declares is C's, as a header's (#207), and a function that
    holds it is not asked for its return, as kelvinc's unfollowed.
  - On the way, as kelvinc's: `'#' must start a line`, which kc did
    not say; and `expected '{': the body of 'if' is a block, as in ...`
    where no parenthesized condition comes before what C would take
    for a body, of `if` and `while`.
  - tests/run's inline_c.k, inline_c_fn.k, inline_c_hash.k,
    no_trigraphs.k and stmt_macros.k, which kc refused, print what
    kelvinc's print; inline_c_order.k and tests/error's
    hash_mid_line.k and inline_c_body.k are new.
- **Lines that go on, and five forms beside them** (#728), as
  kelvinc's, the second of the 30 programs' batches:
  - a `{` on the line after a head is its body, word_below: of a
    function, `if`, `else`, `while`, `for`, `switch` and `do`; an
    `else` after a `}` and a `do`'s `while` on the next line too;
  - `as` and `[` at the start of a line go on with the expression
    before them, as an operator and `.m` do; a `*` there goes on with a
    product, `*PI*r`, and is kelvinc's error of C's dereference only
    where what it touches is assigned, assigned_after;
  - in a function with a result, `return` takes the value on the next
    line; in one with none, what follows a `return` is no error where
    it is a label or holds one, holds_kind;
  - `q++` and `q--` step a pointer in a `for`'s clause and a comma
    list, simple_level, where kc said they were no value;
  - `1.e5` and `1.E+3` are numbers, C's, where kc read a member `e5`;
  - a function with a name past ASCII is known before it is written,
    as any function since #505;
  - `(point) as T` of a variable in parentheses is no C cast;
  - `sizeof(big^)` where a variable `big` hides its struct, in its own
    declaration too, is of what it points to, C's `sizeof *p`;
  - a method of a header's struct declared `struct timespec;` takes
    C's `struct timespec`, recv_type;
  - tests/run's semicolons_edge.k, semicolons_more.k, pointer_step.k,
    methods_edge.k, order_free.k and tag_names_edge.k, which kc
    refused, print what kelvinc's print.
- **C's types and values** (#729), as kelvinc's, the third of the 30
  programs' batches:
  - **A fault of #724, mended:** `var a:i64^ := ([i64](2))[7, 8]`, an
    array's compound literal where a pointer goes, was refused by
    list_refused as a list where no array is declared; it is a value,
    its first element's address, and where neither an array nor a
    pointer is declared it is kelvinc's `'x' is an i64, and this is
    i64^`, at the `(` of its type.
  - `(div_t){...}` of a header's type and `(size_t const){3}` are
    compound literals, compound_ahead; an element of a type only C
    sees is C's to check; a count by `sizeof` is C's constant.
  - **`volatile`**, a type of its own, konst 3, as an atomic one is of
    2, volatile_base: `volatile u8^`, `u8 volatile^`, `const volatile
    u8^`, `volatile i64`; C's `volatile T`, named so; a `volatile u8^`
    is no text, as kelvinc has it. A qualifier after what it qualifies,
    `i64 const^`, is read, type_suffixes.
  - **`(T, ...):R`**, a variadic function's type, konst 4 of a Y_FN,
    variadic_fn: C's `R (*)(T, ...)`, called with more arguments than
    its parameters; a variadic function's name is a value of it, and a
    prototype with its body is one function, prototype_of_body.
  - `nowhere` whose property is read is an `any^`: `nowhere.isNull`,
    `.addr`, `.hex`, `.cstr`; `var r := nowhere` infers `any^`; it goes
    where an `i64^?` goes, some of it; it is written `((void *)0)`.
  - `p.addr` is a `uintptr_t`, whose `.size` and `.hex` are
    properties; `f.hex` of a function value is its address.
  - Of a header's struct, written `struct blob` or by a typedef, a
    member named as a property wins, `.size`, `.addr`; a member named
    `int64` is `i64`, the word's other spelling, put_tok; `l.label.cstr`
    of its member is by C's `_Generic`, as `(a, b).cstr`; a pointer
    member to a header's type, `xmlChar^`, prints as C decides,
    `kv_cstr_put_pointer`; `int64(v)` of one reads its text, and of an
    `i8^` and an `[i8](N)` too.
  - A struct's last member of no count, `a:[i32]`, is C's flexible
    array member.
  - tests/run's casts_edge.k, casts_edge2.k, casts_edge3.k, cstr.k,
    text_numbers.k, text_numbers_more.k, function_types.k, nowhere.k,
    is_null.k, addr.k and properties_c.k, which kc refused, print what
    kelvinc's print; selfhost/sample.k has the forms.
- **The last eight of the 30 programs** (#730), as kelvinc's: with
  them kc builds every program of tests/run and examples, and each
  prints what kelvinc's prints.
  - `IO.popen(command, mode)`, a process's IO, `kv_io_popen`, where kc
    knew its type and wrote no call.
  - Text and a cstr where a `u8^?` falls back, `p ?? "bytes"`, as text
    goes where a `u8^` goes; the text cast to the pointer's type.
  - `{ (a:i64) in a * 2 }` where `(i64):i64` goes: a written signature
    with no result takes the context's; `$k` in a function that writes
    its parameters names the k-th of them, at the parser.
  - A struct's member `[u8](N)` takes text, C's array of it, beside a
    list and `[T](n)`, gen_written.
  - A global's array of functions: each is the global's, named of it
    and declared before it; `sizeof` of a call in an enum's value is
    of the call's type, as in a member's count.
  - Function types that differ only by the counts C computes of their
    parameters' arrays are one, fn_counts_apart; `$k` of such an array,
    its count a name of another scope, is the pointer C makes of it,
    dollar_type, a global's or an enumerator's count kept.
  - A parameter's `[cstr]` is named `cstr^` by `.typename`.
  - `extern lazy var x:T` of a module's header, as kelvinc --lib writes
    it: the module gives it its value at its first use, and the program
    reads it through `_kv_get_x()`, lazy_externs; the module frees it.
  - tests/run's io_process.k, io_kill.k, io_signal.k, coalesce_text.k,
    anonymous_edge.k, array_types.k, anonymous_values.k and
    local_storage.k, which kc refused, print what kelvinc's print;
    selfhost/sample.k has the forms.
- **A compound literal where a macro's argument goes** (#732), as
  kelvinc's since the same number, a fault of both: `println(([i32](3))[1,
  2, 3][1])` and `(point){1, 2}.y` there were C's error, the literal's
  commas dividing the macro's arguments.
  - gen_macro_arg writes an argument in parentheses where bares_list
    tells its C shows a compound literal that no parentheses hold,
    under an index, a member, a sign, a cast, sizeof or an operator;
    gen_args and println's and print's arguments ask it.
  - tests/run's compound_macro_args.k and selfhost/sample.k have them.
- **What const keeps from changing** (#733), as kelvinc's since the
  same number, where its C said it: kc's words of an element of a
  `[const T](N)` are kelvinc's now, and may_change is brought to its
  order.
  - `p[i] = v` through a `const T^` is kelvinc's `this changes what a
    const i64^ points to`, where kc left it to C; `q[i]` of a
    `[T](N)^` is a row, its elements judged as the array's.
  - A let's own `[const T](N)` says first that it is a let, let_owned;
    a let cstr's byte that a cstr is immutable.
  - A row's type recounted keeps its const elements, counted, which
    lost them of `[[const i64](2)](2)`; `[const T]` of no count is
    counted in a compound literal and a row; a let's `[const T]` is
    named so; and a var of `[const T]` is taken, as kelvinc takes it.
  - tests/error's const_elements_behind_pointer.k,
    const_pointer_indexed.k and const_elements_var.k have them.
- **The words of five errors** (#736), as kelvinc's, the first batch
  of kc's small differences, the user's order after #735:
  - an array where a value goes is named by its first element's
    address, `i64^`, where kc named the array, `[i64](3)`:
    value_mismatch_text and typed_value_ok; a row of an array of
    arrays, `a[1]`, where a number goes is said so too, where it was
    C's error;
  - an error of a compound literal, `([T](N))[a, b]` or `(T){a, b}`,
    is said at the `(` of its type, literal_open, which gen_error asks;
  - braces assigned to a member, an element and `p^` are kelvinc's `a
    list is not a value here`, braces_refused, where they were C's
    error; a case's value and a Dictionary's entry take them still;
  - `ok({1, 2})`, `err({1})` and `some({1, 2})` as written are
    kelvinc's error past the first element, where kc built them;
  - a method a fixed array has not, `a.sum()`, is `[i64](3) has no
    member 'sum'`, member_unknown, where kc said the method is not
    known;
  - tests/error's array_where_value.k, row_where_value.k,
    braces_member_assigned.k, case_word_braces.k and fixed_no_method.k
    have them.
- **Zeros where a pointer goes, and `[T](n)^`** (#737), as kelvinc's,
  the second batch of kc's small differences:
  - `[T](N)` where a value goes is C's zeroed compound literal,
    `(int64_t [3]){0}`, its first element's address: `var p:i64^ :=
    [i64](3)`, an argument, `p := [i64](2)`, and rows, `var r:[i64](2)^
    := [[i64](2)](3)`, where gen_expr_of said an array is not a value;
  - `[T](n)^`, a pointer to an array of a count C computes, is read as
    one of a count written, `__typeof__(int64_t[n]) *`: fixed_inside
    no longer refuses it, and fixed_ptr_ok takes two computed counts
    for alike, C's to judge;
  - tests/run's array_zeros_pointer.k has them.
- **The names of what is read through const** (#738), as kelvinc's,
  the third batch of kc's small differences:
  - `q[1]` and `q^` through a `const i64^`, a cstr's `s[1]` and an
    element of a `[const T](N)` are named `const i64`, `const u8`,
    const_read, which gen_typename asks; the variable inferred of one
    is the plain type in both, kelvinc's fix of the same number;
  - a pointer's own const follows it: `[cstr const](2)`, `cstr const`,
    `const i64^ const^`, type_text; `T^ const^` is read, type_suffixes,
    and written `const int64_t * const *`, put_ctype, where kc wrote
    const twice before the type;
  - tests/run's const_read_types.k has them.
- **A call through a function value of the wrong count** (#740), the
  first of the six left to C, the user's order after #739: kc's
  sentence is kelvinc's since the same number.
  - A variadic one's says `or more`, gen_fn_call; a member's, `o.f(1)`,
    is said at its `(`, as any call's.
  - tests/error's fn_value_arg_count.k, fn_value_arg_count_variadic.k
    and fn_value_arg_count_member.k have them.
- **A member's value of its kind** (#741), as kelvinc's since the same
  number, the second of the six: `'y' of point is an i64, and this is
  text`, member_value_ok, which gen_init asks of a number's, a bool's,
  a String's, a cstr's and a pointer's member, by typed_value_ok.
  - An array member, and `var a:[i64](3) = 5`, say `... is a
    [i64](3), and this is a number`, or text, wrong_for_array, where kc
    said an array is not copied by '='.
  - A number where a cstr goes is `'s' is a cstr, and this is a
    number`, typed_value_ok, which kc took, `var s:cstr := 0`.
  - tests/error's member_value_text.k, member_array_number.k,
    array_declared_number.k and cstr_takes_no_number.k have them.
- **A pointer that is itself const** (#742), `T^ const` and `cstr
  const`, the third of the six, as kelvinc's since the same number:
  - it is a type of its own, konst 5, own_const of parse.k, which
    type_suffixes makes of a `const` after a `^` or a cstr, with
    `restrict` in either order; own_plain is the pointer it is the
    const of, and `const i64^ const` keeps both, const_pointee;
  - it is written `int64_t * const`, put_ctype, where kc wrote no
    const, and named `i64^ const`, `i64^ const restrict`, type_text;
  - `p := &y`, `p += 1`, `p++` and a member's `h.p := &y` are `'p' is
    an i64^ const, a pointer that does not change: declare it without
    const to point it elsewhere`, may_change, and an element of a
    `[i64^ const](2)` the array's, whose elements are const;
  - where a value goes it is the plain pointer: a variable inferred of
    it, inferred, a `$[...]`'s, a `${...}`'s and a `[...]`'s element,
    type_of, and what a `T?` wraps, fits_value and
    value_mismatch_text;
  - tests/error's pointer_own_const.k, pointer_own_const_member.k,
    pointer_own_const_step.k, pointer_own_const_elements.k and
    cstr_own_const.k, and tests/run's pointer_own_const.k, have them.
- **`ok({})` and `err({})`** (#743), the fourth of the six, as
  kelvinc's since the same number: `a list is not a value here: ...`,
  gen_value_of, at the `{`, where kc built the one of a struct's case
  and left a number's to C.
  - `some({})` is still `some(v) makes no Optional`, as kelvinc's.
  - tests/error's case_word_empty_braces.k and err_word_empty_braces.k
    have them.
- **The last two of the six** (#744), kc's alone:
  - `while (i == 0) (i) += 1` and `if (i == 0) (i) = 1` are kelvinc's
    `assignment is a statement in Kelvin, not a value: assign on a
    line of its own`, parse_if and the while of parse_statement, where kc
    said the body is a block: the parentheses after a condition's are
    a call's, and the assignment the condition's.
  - a function type's parameter of rows whose count another parameter
    gives, `f:([[i64](n)](2)):i64`, is written `T (*)[]` in the type's
    typedef, a pointer to a row of no count written, which a row of
    any count goes to, write_type, where kc wrote `n` at the top of
    the file, C's error; kelvinc writes `T (*)[n]` in the function's
    own line and no typedef.
    - A function of rows of three goes where it goes, fn_counts_apart,
      as kelvinc's C takes it.
  - tests/error's condition_call_assigned.k and tests/run's
    fn_type_row_count.k have them.
- **A value read of a volatile is of the plain type** (#746), as
  kelvinc's, with its fix of the same number, a literal's element
  read through const:
  - plain_value(y) of parse.k is own_plain of unvolatile: `var d = v`
    of a `v:volatile i64` is an `i64`, inferred, where kc kept the
    volatile and kelvinc dropped it since #738;
  - an element of a `$[...]` and a `[...]`, a `${...}`'s key and value
    and a Set's element are of it, type_of and dict_key_type, as they
    were of a pointer's own const since #742;
  - tests/run's literal_plain_elements.k has them.
- **The name of a v.type of a count C computes** (#747), as kelvinc's
  since the same number, which names such a type as written where it
  was C's `?`: kc named `[i64](n)` already, and a function's that
  takes one.
  - seen_through(y) is the array a `v.type` stands for where `v` is a
    fixed array of a count C computes, which kc's parser leaves a
    `v.type`: gen_typename names a `w:v.type` by it, `[i64](n)`, where
    it wrote C's `?`, and type_of a row of it, `w[0]`, where it was a
    `u8`.
  - tests/run's typename_computed_count.k has them, and
    type_property_edge.k's `b.typename` is `[i32](n)`.
- **A value where a function type goes** (#748) is kelvinc's error in
  kc's words since that number, `this is (f64):i64, where (i64):i64
  goes`, gen_fn_value's, which kc said of a function of another type
  and of what is no function, where kelvinc left them to C.
  - kc is as it was; tests/error's fn_value_other_type.k,
    fn_value_no_function.k, fn_value_member_type.k,
    fn_value_returned_type.k and fn_value_assigned_type.k, and
    tests/run's fn_value_rows_named.k, have them.
- **A cstr variable is no String, and a Set was declared by :=**
  (#749), as kelvinc's, kc's two listed differences:
  - a cstr variable, a member or a template that is a cstr, where a
    String goes is `'t' is a String, and this is cstr`,
    typed_value_ok, which took any cstr as text: a declaration, an
    assignment, a member and a `return`, whose function inside a
    function is named by its own name, local_own_of;
  - a parameter's and an Array's element's are said so, where an
    owner's move and copy were refused first, cstr_place;
  - an Optional's and a Result's case holds a String, `and this is
    cstr`, value_mismatch_text, where it was C's error;
  - `var d := ${"a"}` was taken, assigns_as, as an Array's and a
    Dictionary's, until #755, which refuses the three;
  - tests/error's cstr_variable_string.k,
    cstr_variable_string_param.k and cstr_variable_optional.k have
    them; tests/run's set_declared_reference.k had the Set's until
    #755.
- **An element's and a literal's value's kind** (#752) are kelvinc's
  errors in kc's sentences since that number, `an element of [i64](2)
  is an i64, and this is text` and `a value of Dictionary<String, i64>
  is an i64, and this is text`, where kelvinc left them to C; kc is as
  it was.
  - tests/error's array_element_text.k,
    array_element_struct_number.k, array_element_fn_type.k,
    dict_value_text.k and dict_value_cstr.k have them.
- **A pointer to a row of a count C computes in a function type**
  (#753) is written with no count in the type's typedef, `T (*)[]`,
  write_type, as #744 wrote an array of such rows: `let g := grid` of
  a `grid(n:i64, m:[[i64](n)](2))` and of a `p:[i64](n)^`, where kc
  wrote `n` at the top of the file, C's error; kelvinc writes the
  same since that number, where it wrote `n` in the variable's type.
  - tests/run's fn_value_counted_rows.k has them.
- **A function's array parameter in its type** (#754), as kelvinc's:
  - written_param(p) is the type a function's type names its
    parameter by, the array as written, `[i64](3)`, `[i64]` or
    `[const i64](3)`, param_arrays's, and the pointer C makes of one
    whose own count C computes; decl_fn_type, function_typename and
    anon_type name by it, where they named every array's pointer,
    `(i64^):i64`;
  - fn_same(a, b) tells two function types that are one in C, as
    kelvinc's fn_types_same: an array parameter is its pointer
    whatever its count, pointed_of and pointed_const, a row of a count
    C computes or of none is a row of any count, and a parameter that
    is a function is compared by its own, fn_param_same; gen_fn_value
    takes a function of such a type for the type that goes, where
    fn_counts_apart took those of counts C computes alone, and
    fn_of_type the first function of a name that is the type in C;
  - write_type writes a written array parameter as its element's
    pointer in a function type's typedef;
  - tests/run's fn_array_params.k, and tests/error's
    fn_value_rows_type.k and fn_name_const_elements.k, have them.
- **An Array, a Dictionary and a Set are values** (#755), as kelvinc
  has them since that number: `:=` of one is `'d' is a value
  (Array<i64>): assign it with '=', not ':='`, assigns_as, which took
  `:=` of them as kelvinc did, of a Set since #749; the Array is
  spelled `Array<T>` there.
  - An element's and `p^`'s `=` and `:=` are judged too, `this target
    is a value (i64)` and `this target is a reference (i64^)`,
    gen_assign, where kc judged a variable's and a member's alone and
    built `a[0] := 5`.
  - tests/error's array_declared_reference.k,
    set_declared_reference.k, owner_reference_assigned.k and
    element_reference_assigned.k have them; tests/run's
    set_declared_reference.k is gone.
- **Three that kc did not read** (#756), as kelvinc's:
  - a `w:v.type` of an array of a count C computes is read as the
    array, seen_through, wherever its name is read, type_of: its
    `.count` and `.size`, a walk, `for x in w`, and its text, where kc
    knew no member of it and walked none; it is declared by
    `__typeof__(v)` still;
  - an array of a constant count that C computes, `[i64](sizeof(i64))`,
    `[i64](K)` or `[i64](2 * 4)`, is declared with no value and zeroed,
    gen_fixed_var, where kc asked for its elements;
  - a struct's braces whose first value is an Array, `{$[1], 2}`, are
    its values: `$[0]` at the brace's own level is `$0` only where no
    comma of the brace follows, anon_ahead of parse.k, where kc read
    an anonymous function at once;
  - tests/run's typeof_counted_array.k, constant_count_array.k and
    struct_array_member_first.k have them.
- **Sentences and places of a value's kind** (#757), as kelvinc's:
  - a Set's key: key_of_ok(y, key, k), which dict_key_ok asks of a
    Dictionary's, is asked of each element of a Set's literal of a
    written type, before their one type is, gen_set and gen_var_of, and
    of `s += v`, insert, has and remove, where they were C's errors;
  - an Array's `+=`, append and insert: gen_array_add asks
    typed_value_ok of what is appended, with an element of the Array's
    type is, and says it of a function's element, a number, text or a
    function written of another type, where they were C's or `this is
    i64, where (i64):i64 goes`;
  - an Optional's element and value: a fixed list's and a Dictionary
    literal's of another kind are said by case_value_fits, `case
    'some' of i64? holds an i64, and this is text`, where kc said an
    element of [i64?](1) is an i64?;
  - a designated element's value, `[[1] = "a"]`, is of the element's
    kind, fixed_list_fits, where it was left to C;
  - value_error(v, what) says an error of a value that is a member
    read at its `.`, kelvinc's place: typed_value_ok, gen_fn_value,
    gen_array, fixed_list_fits, the Dictionary literal's value and
    case_value_fits ask it, where kc said them at the member's name;
  - cstr_place(a) tells any variable or member whose type is no
    owner's, so that a number's member where a String parameter goes
    is said by its kind, where kc said an owner moves in;
  - tests/error's set_literal_key_kind.k, set_insert_key_kind.k,
    array_append_kind.k, array_append_fn_kind.k, member_value_place.k,
    optional_element_kind.k, designated_element_kind.k and
    string_param_member_number.k have them.
- **A container of structs by the struct's bare name** (#758) is
  kelvinc's since that number, `Array<point>`, which kc named so:
  kelvinc's `.typename` and its errors said `Array<struct point>`; kc
  is as it was, and tests/run's container_struct_names.k has them.
- **A number is no pointer** (#760), as kelvinc's since the same
  number: no_pointer_number(v) tells a number, a character or a bool
  written that is no 0, zero_literal of any base; typed_value_ok says
  it where a pointer goes, `'p' is an i64^, and this is a number`,
  where it was C's error, and fixed_list_fits of an element, a
  designated one too.
  - `0` is C's null: value_mismatch_text and fits_value take it where
    a pointer and a pointer's Optional go, where kc said a number of a
    Dictionary's value and of an Array's element.
  - tests/error's pointer_number.k, pointer_number_argument.k and
    pointer_number_element.k, and tests/run's pointer_zero.k, have
    them.
- **A variable declared with no value is zero** (#761) in kelvinc's C
  since that number, as kc wrote it, put_zero_of: a number 0, a struct
  and a fixed array `{0}`, an empty record `{}`, a count C computes by
  `memset`. kc is as it was; tests/run's unset_variables_zero.k has
  them.
- **An array of no count and no value** (#762) is kelvinc's error in
  kc's sentence since that number, `[i64] takes its count from its
  elements: write [i64](N), or the elements`, gen_fixed_var's, where
  kelvinc left it to C; tests/error's array_no_count_no_value.k has
  it.
- **An Array, a Dictionary and a Set have += alone** (#763), as
  kelvinc's since the same number: `s -= x` is `a Set has no '-=':
  remove an element with s.remove(x)`, an Array's and a Dictionary's
  with their own `remove`, any other operator `a Set has no '*='`,
  and a Dictionary's `+=` kelvinc's `a Dictionary has no '+=': add an
  entry with d[k] = v`, gen_assign, at the operator, where kc said an
  owner is assigned only as a String.
  - tests/error's set_minus_assign.k, array_minus_assign.k and
    dictionary_minus_assign.k have them.
- **kc's eight** (#764), the differences left listed after #759:
  - A function defined inside a function is named as written in an
    error: parse.k's `local_uses`, the node of a use to the token
    written, which gen_error and fn_name_refused read, where kc
    printed the hidden `_kv_main_t1`.
  - `Set` and `Dictionary` with no `<` and no `.` are `expected an
    expression, found 'Set'`, parse.k's.
  - `{$[1]}` where a struct is declared is its values, parse.k's
    `literal_brace`, where it was `$0`'s function.
  - A Dictionary in a Dictionary's literal is checked by
    dict_entries_fit of the inner type.
  - `nowhere` where no pointer goes is an `any^`, typed_value_ok's
    and value_mismatch_text's, an owner's too.
  - `a := $[]` asks assigns_as before the empty Array's type,
    gen_assign's and gen_var_of's.
  - `xs += { $0 + 1 }` of functions was built already, and is
    kelvinc's since this number.
  - Found with them, and changed:
    - a function's name where functions are the elements is the
      overload of their type: fn_name_refused, which picks, asked by
      pick_overload of a literal's elements, by gen_array_add, by
      member_value_ok, and by gen_stmt_of before `+=` is read;
    - a function's own name where a number, a bool, a String or a
      record goes, and a function where a pointer goes, are
      typed_value_ok's sentences, an element's by `fn_id` in
      fixed_list_fits;
    - braces appended, a Set's key and a number's entry are
      `brace_no_value`'s `a list is not a value here`;
    - `d[k]` of a Dictionary of functions is type_of's `an Optional
      of a function type has no spelling yet`; `d[k]!` is read as it
      was.
  - Left: `[v.type](2)` of a `v` whose count C computes.
  - tests/run's fn_elements_overloaded.k and
    struct_one_array_braces.k, and fourteen of tests/error, have
    them.
- **A String and a Bytes have += alone** (#766), as kelvinc's since
  the same number: `t -= "a"` is `a String has no '-='`, `b *= 2` `a
  Bytes has no '*='`, gen_assign, at the operator, where kc said an
  owner is assigned only as a String.
  - `**=` of them, and of an Array, a Dictionary and a Set, is said so
    too, where gen_assign read the power first, `'**' takes numbers`.
  - tests/error's string_minus_assign.k, bytes_times_assign.k and
    array_power_assign.k have them.
- **An array is not declared with another** (#767), as kelvinc's
  since the same number: `var a:[i64](2) = b`, a member's `{b}` and a
  row's `[[1, 2], b]` are `an array is not assigned: assign its
  elements, a[i]`, gen_fixed_var's, gen_written's and
  fixed_list_fits's by `array_read`, said by value_error, a member
  read at its `.`, where kc said an array is not copied by '='.
  - `var a = b`, no type written, is kelvinc's `'a' is a reference
    (i64^): assign it with ':=', not '='`, at the `=`, `const i64^` of
    a let's array.
  - tests/error's array_declared_array.k, array_declared_nowhere.k,
    array_member_given_array.k, array_rows_given_array.k and
    array_inferred_by_eq.k have them.
- **What a Set and a Dictionary take** (#768): `Set<i64>([1, 2])` and
  `Dictionary<K, V>(["a": 1])` are said at the `[` by parse_make, in
  kelvinc's words since the same number, where kc said the first
  where it was written and `expected ']'` of the second.
  - `var s := Set<i64>(5)` says what a Set takes before `:=` of a
    value: `make_arg_refused`, which gen_var_of asks first.
  - tests/error's set_made_of_array.k, dictionary_made_of_array.k and
    set_made_declared_reference.k have them.
- **kc's of the order after #765** (#769), each kelvinc's sentence at
  its place:
  - An operator in an assignment:
    - `q -= 1` of an Optional, and of any enum with values, is `no
      operator - takes i64? and i64`: resolve_op settles such a type's
      operators as its own but where `compound_now` says the operator
      is an assignment's, or it is a unary `-` or `~`.
    - `o -= 1` of a struct is said at the operator: the token
      compound_by_operator makes keeps the assignment's place.
    - `c += 1` and `c -= 1` of a cstr are gen_assign's `a cstr is
      text, not a cursor`.
  - `reject_string_math` says `a String has no operator '*'`; inferred
    asks it, reject_container_math and a Bytes's before `'u' needs a
    type`.
  - An overloaded function's name in a literal of no type written is
    `literal_names_overload`'s, asked by inferred and by gen_assign: an
    Array's at its `[`, a Dictionary's value at its key, a Set's
    element, a later one `unseen` beside the first's; `[twice]` is
    `'a' needs a type`.
  - `nowhere` fits a pointer's, a cstr's and a function's parameter
    alone, arg_fit, and is a type kelvinc sees to sees_c_arg, so a tie
    is kelvinc's error and no `_Generic`.
  - `:=` of `v as T` is `would be a value`, assigns_as, of a
    declaration of no type written alone.
  - parse.k says `expected ';' or a new line before` of what follows a
    typealias's type on its line, and names a key that is a struct
    with its word, `struct pt`, by gen.k's tag_word.
  - `Array<T>({1, 2})` is brace_no_value's; typed_value_ok names a
    number or text where an array is declared `a number` and `text`,
    and wrong_for_array reads arithmetic.
  - fixed_list_fits takes text for a row of bytes of a count.
  - tests/error's fourteen and tests/run's rows_of_bytes_text.k have
    them.
- **What an Array<T>(x) takes** (#771): kelvinc says kc's sentences
  since that number, gen_make's `Array<i64>(n) takes a count, and this
  is text` and `Array<i64>(&a) copies an Array<i64>, and this lends
  i64`, and gen_from_fixed's `Array<i64>(a) takes a fixed array of
  i64`, where it left them to C or built them.
  - kc says the count's sentence of `nowhere` too, `this is any^`,
    where it was C's error, and the fixed array's of rows before `an
    Array of [i64](2) is not here yet`.
  - tests/error's array_made_of_text.k, array_made_of_cstr.k,
    array_made_of_address.k, array_made_of_fixed_other.k and
    array_made_of_nowhere.k have them.
- **A value of another kind where an array goes** (#772):
  `array_kind_wrong` says kelvinc's sentence of a name, a member, an
  element, a call or `p^` that is no array read, `'a' is a [i64](2),
  and this is shape`, an Optional's `this is i64?, an Optional, where
  [i64](2) goes` where one is declared, and of braces `an array is
  initialized with '[...]', not '{...}'`, asked by gen_fixed_var and
  by member_value_ok, where kc said an array is not assigned.
  - kelvinc names the array as written since this number, where it
    said `'a' is an i64^`.
  - tests/error's array_declared_struct.k, array_declared_optional.k,
    array_declared_function.k, array_member_given_struct.k and
    array_member_braces.k have them.
- **Zeros and a compound literal of an array's shape** (#773):
  `array_shape_wrong` says the kind's sentence of a `[T](n)` or a
  `([T])[a, b]` of another element or count, `'a' is a [i64](2), and
  this is [i64](3)`, asked by gen_fixed_var, by member_value_ok and by
  fixed_list_fits of a row, each with its lead, where kc said `'a' is
  [i64](2)` of zeros and `this is [i64](3), where [i64](2) goes` of a
  literal.
  - A row takes zeros and a compound literal, as kelvinc's since this
    number: gen_fixed_list writes `{0}` of a row of zeros.
  - tests/run's array_member_zeros.k and tests/error's
    array_declared_zeros_shape.k, array_declared_compound_shape.k,
    array_member_zeros_shape.k and array_row_zeros_shape.k have them.
- **kc's of the order after #770** (#774):
  - `[v.type](2)` of a `v` whose count C computes is built, the last
    of the eight left after #759: fixed_elem_ok takes a row that is a
    v.type seen_through tells an array, fixed_computed tells such an
    array one of a count C computes, so it is declared and zeroed by
    `memset`, put_ctype writing `__typeof__(v) w[2]`; type_of of an
    element sees through the row; gen_typename names it `?`.
  - `nowhere` is an `any^` to type_of, where it was a type only C
    sees, so a literal of no type written that holds it is of `any^`;
    gen_fn_value takes it where a function goes, as it did.
  - `untyped_key_refused` says kelvinc's sentence of a key or an
    element of a `${...}` of no type written that is no integer and no
    String, asked by inferred, by gen_set and one_entry_type, and by
    gen_assign; parse.k's cstr_key says a pointer's at its `^`.
  - one_type says kelvinc's `the elements have no one type kelvinc
    sees here`, at the `[`, by `array_open_error`.
  - gen_make and gen_make_inferred copy the Array a pointer in a
    variable lends, `Array<T>(p)` and `Array(p)`, as `Array<T>(&a)`.
  - tests/run's nowhere_untyped_literals.k, typeof_rows_computed.k and
    array_of_borrow_variable.k, and tests/error's set_untyped_key.k,
    set_untyped_nowhere.k, dictionary_key_pointer_place.k and
    dollar_array_mixed.k have them.
- **An array of arrays of a count C computes is not printed whole**
  (#776), as kelvinc's since the same number: fixed_ok says it of a
  fixed array one of whose rows has a count that count_names_local
  tells a local's, or is a v.type, before it asks whether the
  elements print, where kc said its own `kc prints a number, a bool,
  text` or left it to C.
  - tests/error's print_rows_computed.k and
    print_typeof_rows_computed.k have them.
- **kc's of the order after #775** (#777):
  - A choice in a declaration of no type written: `choice_typed`, as
    kelvinc's value_type of `c ? a : b`, takes a function's arm, or two
    arms of one type that is no pointer's, cstr's or array's and none
    only C sees; `choice_arm_type` gives none of a number or a
    character written, of a unary but `!`, and of arithmetic; a word,
    none or ok(v), takes the other arm's, as it did. inferred says
    `'q' needs a type` of the rest, which kc built.
  - inferred says kelvinc's `Array(x) has no element type` of an
    Array(x) or Array(&x) of no type written whose type type_of does
    not see, and `an Array of [i64](2) is not here yet` of rows.
  - `zeros_row` gives rows of no count written, whose first is zeros,
    the zeros' type, to fixed_list_fits and gen_fixed_var.
  - tests/run's choice_untyped_values.k and rows_zeros_first.k, and
    tests/error's choice_untyped_literals.k,
    choice_untyped_pointers.k and array_untyped_text.k have them.
- **A list where an array's count is computed** (#779): kelvinc says
  kc's `an array of a count computed at run time takes no elements in
  C` since that number, by constant_count's rule, a let's name no
  constant, where it left the count to C.
  - gen_var_of says the sentence of a list or text given to a
    `w:v.type` of an array of such a count, where kc said an array is
    not a value here.
  - tests/error's array_computed_list.k, array_let_count_list.k and
    typeof_computed_list.k have them.
- **kc's of the order after #778** (#781):
  - choice_arm_type gives none of a property, a member read that is
    no member of a struct by field_type, and of sizeof and alignof, so
    a choice of `a.count` is `'q' needs a type`, as kelvinc's.
  - `read_elem_type` gives a fixed array read where an element goes
    its first element's address, an `i64^`: type_of of `$[b]`, of
    `${"k": b}`, of `Array([b])` and of `[b, c]` of no type written,
    one_type and untyped_key_refused ask it, and value_mismatch_text
    takes one where an `i64^` or an `any^` goes.
  - tests/error's choice_untyped_properties.k and tests/run's
    array_of_fixed_reads.k have them.
- **A count is an integer** (#783), kelvinc's since that number, in
  kc's sentence: `an array's count is an integer, and this is f64`.
  - computed_ok says it of a float's or text's count before a list's
    `takes no elements in C`, as kelvinc reads the type first.
  - parse.k says it of a float or text written where any array's type
    is read, a member's and a parameter's too, which kc left to C.
  - tests/error's array_count_float.k, array_count_text_member.k and
    array_count_struct.k have them.
- **uchr is no more** (#528), as kelvinc's: kc's lexer says so at the
  word, `uchr`, `n.uchr` or `for c:uchr in s`, naming the `u32`, and
  `.utf32` or `.codepoint` of a number is an error that says it is one.
  - Y_UCHR is gone, with kc's `uchr(x)`, its comparisons, its printing
    as `uchr("x")`, its walks up to `uchr(0)`, its sort and its
    templates; a codepoint loop's variable is a `uint32_t` whatever is
    written.
  - The entries before this one that name uchr are of their time.
- **A codepoint is a `u32`** (#527), as kelvinc's: `for c in
  s.codepoints` gives each as a `uint32_t`, and UnicodeData's `extend
  u32` is found on a u32, `c.name`, `c.category`, its C names
  `u32__name` and its kin.
  - kc's own `.uchr` of a number is gone: `s += n` appends the
    codepoint, and `c.utf32` of a codepoint loop is `c`.
- **`grapheme(c0, c1, ...)` and `String.fromCodepoints(c0, c1, ...)`**
  (#526), as kelvinc's: UnicodeData's, of one `Array<u32>`, or of any
  number of integers, which kc reads into an array of them as i64 and
  the call of `kv_codepoints_string`, the count, and whether the first
  grapheme alone; with kelvinc's errors of a float, a bool or text.
- **The edges of `for x in s`** (#524), as kelvinc's #30, tests/run's
  for_each_edge.k:
  - A fixed array is read once, by its address, so `for x in m[row()]`
    calls `row` once, and walked to its count, a zero the terminator but
    of structs, which are walked whole.
  - A let parameter's array is walked to its declared count, a number
    or an expression; a var one, which may have moved, `xs :=
    xs.next`, as a pointer, up to a 0.
  - A pointer to numbers or pointers is walked up to a 0 or nowhere:
    main's `argv`, written `u8^^`, which C has `char **`, as kelvinc
    writes it.
  - `(int64){1}`, a number's compound literal, in a range's head too.
- **A type written in a loop** (#523), as kelvinc's #480: `for x:T in`
  a range, a Range, a String, an Array, a fixed array, a cstr, a list, a
  Dictionary, a Set, an iterator, `f.lines` and `f.read(n)`.
  - A range's count is of T, an integer, else kelvinc's error; `lo...`
    goes up to T's largest.
  - An element is converted as `T(v)` does: a uchr to its codepoint, an
    integer to `uchr(v)`, a number to another; a float or a bool to a
    uchr is kelvinc's error.
  - A String walks its codepoints, but `for c:String in s` its
    graphemes.
  - An iterator, `f.lines` and `f.read(n)` give what they give, and T
    is that, else kelvinc's error.
- **Graphemes, a String's elements** (#522), as kelvinc's.
  - `for c in s` walks graphemes, each a String the loop frees;
    `for c in s.codepoints` walks codepoints, in place.
  - `s.count`, `s[i]`, the slices and `s.prefix` count graphemes, by
    the runtime's kv_string_graphemes and its kin; `find` and RegExp's
    offsets are the runtime's.
  - A String compares with text, a uchr or a character, on either side.
- **`s.codepoints`** (#521), as kelvinc's: UnicodeData's `Array<u32>`
  (#527); `for c in s.codepoints` walks the String in place, with no
  Array made, each a `u32`.
  - kc's own loops over a String's codepoints are written so, ready for
    #522, where `for c in s` walks graphemes.
- **UnicodeData in every program** (#520), as kelvinc's: kc reads
  `UnicodeData.kh` before the prelude's others, so `s.normalize(nfc)`
  and `$"é".codepoints[0].name` need no import.
  - A file is read once by its real path, so `modules/M.kh` and
    `./modules/M.kh` are one.
- **A type's own `x op= y`** (#518), as kelvinc's.
  - `static let +=(a:Self^, b:U)`, and `let +=(a:T^, b:U)` at the top
    level, are read, with kelvinc's errors of another shape.
  - `x += y` calls it with `&x` and `y` where its types fit, by
    kelvinc's C name, `_kv_add_assign_op__BigIntp__i64`; else it is
    `x = x + y`, as before.
  - So BigInt's `s += i` is in place in kc's build too.
- **The modules of the prelude** (#515), as kelvinc's #504: BigInt,
  RegExp and UnicodeData.
  - A program that names BigInt or RegExp, or writes `123n` or
    `$/.../`, reads `M.kh` from the modules directory, `-m`, as if it
    began with `#import <M>`.
    - So does `#import <M>` of one, and RegExp.kh's of UnicodeData.
    - A type of the program's own of that name hides it under the bare
      name there, and `Kelvin.M` and the module's literal are the
      prelude's (#600); it kept the module out before, and the
      literal was kelvinc's error.
  - kc reads a `.kh`'s declarations, which have no bodies, and writes
    their prototypes; libkelvin, which kc links already, defines them.
  - The C names are kelvinc's, so objects of both mix:
    - a module's functions by their types, `BigInt__i128`;
    - a pointer by its Kelvin text, `const_Stringp`, and a function
      type too, `FMatchEString`.
  - What came with it, for any program:
    - methods of a name that differ in their parameters, each named by
      its types, `T__pow__i64`, and chosen by the arguments, as
      kelvinc's #158;
    - methods of String, Bytes and uchr, which a module extends; kc's
      own serve where none of the module's fits;
    - `:()` as no result, as a header writes it;
    - a `T^` given where a `const T^` is taken;
    - an owner an expression gives, held and lent where a `T^` is
      taken, as kelvinc's #187: `s.split($/\s+/)`;
    - `{ ... $0 ... }` given to an overloaded function, its parameters'
      types those of the overload its other arguments choose;
    - a function value that takes or gives an owner, given to a
      module's function, which calls it as kelvinc's code does; a call
      through one in kc's own code is still refused;
    - `b.escape()` and `Bytes.unescape(text)` of a Bytes.
  - A `$/.../` pattern is checked as the program runs, where kelvinc
    checks it as it builds.
- **`Kelvin.name`** (#600), the prelude's name whatever the program
  calls its own, as kelvinc's.
  - It is settled in the tokens, once every file is read, by kc.k's
    `kelvin_names`, as kelvinc's `with_kelvin`:
    - `Kelvin.T` of a type of the prelude's is the one token `T`;
    - `Kelvin.f` of a function is the one token `Kelvin.f`, or `f`
      where the files have nothing of the name, which `nothing_named`
      asks of the tokens, where kelvinc asks its scopes;
    - `Kelvin.nfc`, a word of an enum of the prelude's, is
      `(0 as NormalForm)`, its number as its type;
    - `Kelvin.String`, `Kelvin.print` and the like are the word alone;
    - any other `Kelvin` is kelvinc's error, in its words.
  - A file of the prelude is told by its name, lex.k's `prelude_file`:
    UnicodeData, RegExp, BigInt or math.
  - **A type of the files' own with the name of one of the prelude's**
    is `_kv_own_T` in the files that see it, kc.k's `own_types`: the
    file that defines it and those that import that file, by the
    imports `note_import` keeps.
    - So the two are two types, to kc and to C.
    - A message, `x.typename` and a header show `T`, and the
      prelude's `Kelvin.T`: lex.k's `shown_text`.
  - **A function of the files' own with the name and the types of one
    of the prelude's** is another function: gen.k's `hides_prelude`.
    - Its key among the signatures is marked, `sig_key`, so both are
      kept; `choose_overload` leaves the prelude's out of a bare
      call, and takes the prelude's alone of `Kelvin.f`.
    - Where libkelvin defines the prelude's, the files' own is
      `_kv_own_f__types` in C, as kelvinc's.
  - **A name of the files' own top level that is no function**
    (#604) hides the prelude's of that name the same way, `_kv_own_x`:
    a variable named as a function of the prelude's, a word of an
    enum of the files' own, anything named as a word of the
    prelude's enum.
    - `own_types` takes the prelude's types, functions and words;
      `enum_words` reads an enum's.
    - A member's declaration, a struct's `x: T` and an extend's
      `let x`, is not renamed: `member_toks`.
    - Where the files have such a name of math's, math is read,
      named or not, as C's `math.h` declares its functions in every
      program; kelvinc keeps math's names instead.
  - **An operator of the prelude's own types** in the files (#606)
    is kelvinc's error, in its words: `count_overloads` keeps the
    prelude's operators by their types, `prelude_ops`, and refuses
    one of the files' own of the same. kc wrote both before, and the
    linker refused them.
  - **`Kelvin.f` that stays so** is called through `_kv_ns_f`, a
    constant pointer to the function written before the functions,
    which a variable of the name does not hide in C: `put_ns_name`.
    - kc writes it of each such call, where kelvinc writes it only
      where a variable of the name is in scope; the programs print
      the same.
  - sample.k has a line of them.
- **The modules a program imports** (#516), as kelvinc's #46 and #143.
  - `#import <M>` is `M.kh`, a module's header, else `M.k`, in
    ./modules, else in the modules directory, `-m`.
    - `#import <x.k>` is that file, looked for the same way.
    - Each is read once; one not found is kelvinc's error.
    - `<IO>` and `<OS>` stay kc's own.
  - A header's library is linked, before libkelvin:
    - `libkM.a` beside it, else `-lkM` of a shared one;
    - with the flags of `libkM.link`, as fetch's;
    - and before the libraries of the modules its header imports
      (#599), as kelvinc's: kc.k's `lib_after` moves one imported
      already after the module that imports it now, so
      `libkBigNum.a` is before `libkRational.a`, whichever is
      imported first. `<Rational>` and `<BigNum>` are libraries
      since, which kc reads as it reads `<JSON>`'s header.
  - ./modules is where C looks for headers too.
  - What came with it, for any program:
    - `"""text"""` and `$"""text"""`, as kelvinc's #115 and #118;
    - `j["key"]` and `j[i]` of an enum with values, through its
      Dictionary or Array case, as kelvinc's #117;
    - a function's name given to an overloaded function,
      `JSON.stringify(&j, f)`;
    - `&d[k]`, the entry's place.
  - Not yet: SION's subscripts and localStorage's `extern lazy var`;
    math's `typealias` came with #550.
- **A converter clamps** (#513), as kelvinc's: `T(v)` of a number is
  KV_CLAMP's nearest value, or C's conversion where T holds every value
  (kind_widens); KV_TEXT_CLAMP where kc cannot see text; a pointer's is
  kelvinc's error. kc's cc takes clang's
  -Wno-tautological-constant-out-of-range-compare too.
- **A converter of a struct** (#512), as kelvinc's: `i64(v)` of a struct
  that has an attribute `i64` is `v.i64`, by gen_converter making the
  call that attribute's read; one without it is kelvinc's error.
- **A lent parameter** (#510), as kelvinc's: `b:lent T` of a function or
  a method is its caller's, as an operator's operand (#501), by
  lent_params, which parse_type steps the `lent` of; errors in
  kelvinc's words.
- **A 123n literal** (#508), kelvinc's BigInt: kc's lexer refuses it in
  words, as kc links no module written in Kelvin; #515 reads it.
- **BigInt, the prelude's** (#507): kelvinc's, a module written in Kelvin;
  kc links no module built of Kelvin, so its programs name no `BigInt`;
  #515 reads it.
- **A type's own text as a String** (#506), as kelvinc's: where a
  struct or an enum with values has `let T.string:String`, its printer
  shows that String, whole, by `T__string`; `$`...``, `` `...` `` and
  `.pretty` with it.
  - `T.cstr()` (#53) and the error of both came with #542.
- **Called before written** (#505): kc reads every declaration first, so
  a function, a method or a function of a type called before it is
  written was kc's already; kelvinc is now the same, by the prototypes
  it writes.
  - Found: kc's overloads take no borrow of a String an expression
    gives, `say(&$"said")` of `say(s:const String^)` beside `say(s:cstr)`,
    in order or not; with a variable, `say(&t)`, they do.
- **RegExp, the prelude's** (#504): kelvinc brings it in where a
  program names it, and libkelvin holds it; kc still reads no `$/.../`
  and links no module built of Kelvin, as before, so a program of kc's
  names no `RegExp`; #515 reads it.
  - kc links libkelvin.a, which now holds RegExp and UnicodeData; a
    program of kc's links none of them, as it uses none.
- **An owner moved into a literal** (#503), as kelvinc's: a local owner
  named in `{...}` or `(T){...}` of a struct is taken, `kv_string_take`,
  and dead after, where it was kelvinc's error; its move is made when
  the statement ends, so `(P){s, s.count}` is #500's error.
  - A member or an element, `(P){p.name, 2}`, is kelvinc's error, where
    kc had copied it, and the program freed it twice (found in #501).
  - A global, an element of a `for` and a lent operand say to copy.
- **Bitwise operators** (#502), as kelvinc's: a struct, a union or an
  enum with values defines `& | ~ << >>` and unary `~`, named
  `_kv_and_op`, `_kv_or_op`, `_kv_xor_op`, `_kv_shl_op`, `_kv_shr_op`
  and `_kv_compl_op`; `x &= y` to `x >>= n` are `x = x op y`.
  - kc's compound_op gives Kelvin's `~`, `<<` and `>>`, where it gave
    C's `^`, and `**` of `<<=` and `>>=`, to a setter's `x.y op= v`.
  - Found: kelvinc writes `W.of(...)` in an operator of `extend W` as C,
    which does not know W, where `of` is defined after it; kc's build is
    right.
- **An operand lent** (#501), as kelvinc's: an operator's owner
  parameter, unless var, is its caller's, read, never freed nor moved;
  `a * a + b` and `c + c` leave `a`, `b` and `c`.
  - One an expression gives is held for the call, by hold_args; a var
    parameter is given a copy of a place.
  - Returning, moving or changing one is kelvinc's error, in its words.
  - Found: kc copies an owner member into `(T){a.name}`, which kelvinc
    refuses (O3), and the program frees it twice; and kc writes a global
    given a function's value, `let g = mk(1)` (#493), before the
    function's prototype, C's error.
- **An owner named once** (#500), as kelvinc's: an owner that moves
  out in a statement's expression is named nowhere else in it, but as
  the target of `=`; `f(s, s)`, `c + c` and `s.count + f(s)` are
  kelvinc's errors, in its words; `c + c` is not since #501.
  - kc checks when the statement is written; kelvinc as it parses.
  - kc's `==` already wrapped a copy of an owner, as kelvinc's now does.
- **An empty struct's count** (#499): an array of elements of no size
  counts by its declared length, as kelvinc's: `.count`, `==`, `print`
  and `Array(a)`, where `sizeof(a) / sizeof(a[0])` was 0 / 0.
  - A length that names a local is kelvinc's error.
  - kc walks no fixed array of structs with `for` yet, as before.
- **A fixed array printed** (#481), as kelvinc's.
  - `println(f)` of a fixed array is `[a, b]`, as inside a struct; a
    `[u8](N)` is its text.
- **A walk of codepoints** (#480), as kelvinc's.
  - `for c in f` of a `[uchr](N)` stops at `uchr(0)`, as an array of
    numbers stops at 0.
- **A codepoint inside a value** (#479), as kelvinc's.
  - A uchr inside a value prints as `uchr("x")`, U+0000 as `uchr(0)`.
  - `[uchr](N)` is a fixed array's type; `int64(x)` and `uchr(x)` go in
    its `[a, b]`.
- **A codepoint of text** (#478), as kelvinc's #56.
  - `uchr(x)` is the codepoint of an integer, or the first of text.
  - A uchr compares by its codepoint with a uchr or a number,
    `c == ' '`, `c < d`; it has no arithmetic, in kelvinc's words.
  - `c.codepoint` is `c.utf32`, and `i64(c)` converts the codepoint.
- **A case's tag** (#477), as kelvinc's #61.
  - `v.case` is the tag, a u8, of an enum with values, an Optional or a
    Result; of a call's value that owns, the value is freed after.
  - `T.c({1, 2})` and `v.c = {1, 2}` take a brace list where the case's
    value is a struct.
  - `v.case = x` is refused: a case is set with its value.
- **Types with no tag** (#476), as kelvinc's #59, #60 and #61.
  - `{x:f64, y:f64}`, `struct{...}`, `union{i:i32, f:f32}` and
    `enum{none, n:i64}` go wherever a type goes: a parameter, a result,
    a member, an element, a case's value, `Array<...>`, `${K: ...}`.
  - One spelling is one type, `_kv_anonN`, declared before what first
    writes it; its text and errors spell it, `{x: f64, y: f64}`.
  - `({x:f64, y:f64}){1.0, 2.0}` is its compound literal.
  - A struct an OS member gives is the one written alike, as kelvinc's.
- **Subscripts** (#475), as kelvinc's #136.
  - `let T[](i:I):R { }`, and `let [](i:I):R { }` in `extend`: `v[i]` is
    the call of its getter, found once the type is known, as an attribute
    is (#473). It wins over indexing an enum with values through a case.
  - `var [](i:I):R { get { } set(v) { } }`: `v[i] = y` is the setter on
    the var that holds `v`, and `v[i] += y` reads it first.
  - `v[r, c]` takes several indices, and subscripts overload by their
    count and types, with kelvinc's choice and words:
    `T__subscript__i64__i64` where a type has several.
  - The getter's `self` is a const pointer, so a receiver is neither
    copied nor moved; what no variable holds goes in a literal of its own,
    `(const struct T[]){f()}`.
  - `var a:[T](2) = []` is its count's zeros, as kelvinc's.
- **Attributes** (#473), as kelvinc's #131, #132, #133 and #137.
  - `let T.x:R { }` and `let x:R { }` in `extend`: `v.x` is the call of
    `T__x(v)`, found once the type is known, as `a + b` of an operator
    is (#471).
  - `var x:R { get { } set(v) { } }`: `v.x = y` is `T__set_x(&(v), y)`,
    and `v.x += y` reads it first.
  - `static let T.x:R = v` and `static var T.x = v`, or in `extend`: a
    global, `T__x`, read and written as `T.x`.
  - `static let T.x:R { }`, or in `extend`, a computed one (#595), as
    kelvinc's: a function of the type with no parameters, told from a
    stored one by `static_computed`, a body after its type, and parsed
    by `parse_static_attribute`; `T.x` is the call `T__x()`, made of
    the `N_FIELD` by `resolve_attr`.
    - In a module's header it is `static let x:R { get }`, with no
      body.
    - kelvinc's errors of it are kc's, in its words: read with
      parentheses, declared `static var`, assigned, and a name that is
      a stored attribute or a function of the type already.
    - Not kc's yet, as of any function of a type: `self` in its body,
      one of a number type, and a body with no value, each C's error
      or none.
  - `Self.f()` and `Self.x` in an expression.
  - A getter reads `self` and never changes it, and `v.x()`, `v.x = y`
    of a let attribute and a member of the name are errors, in
    kelvinc's words.
  - An attribute of a built-in type waits for its methods.
- **The rest of the integers** (#472), as kelvinc's: `i8`, `i16`, `u16`,
  `u64`, `i128` and `u128`, and their full names.
  - A number's text, reading one from text, overloads, `.abs`, `.sign`,
    `.bit(n)`, `**`, Arrays, Ranges to 64 bits, and `bv.u64s`.
  - Arithmetic of numbers has C's type, as kelvinc sees it: `k * 100` of
    an `i8` is an `i32`, and `f * 2.0` of an `f32` an `f64`.
  - `x.size` and `r.count` are a `u64`; other counts stay an i64, and
    `sizeof(T)` too.
  - `int32(n)` of a C typedef, `n:size_t`, is C's to convert.
  - `0x1p4` is a hex float, and a decimal literal above an `i64` says
    `U` in C, as kelvinc's.
- **A struct's operators** (#471), as kelvinc's #42, #128, #135 and
  #380:
  - `let +(a:T, b:U):R` and the rest, `static let +(...)` in `extend`,
    `_kv_add_op__T__U` in C, with kelvinc's errors in its words.
  - `a + b`, `-a` and `a < b` where a struct, a union or an enum with
    values is an operand: from there on the call of the operator chosen.
  - `x += y` is `x = x + y`; `xs.sort()` by the elements' own `<`.
  - An owner moves into an operator, as into a function; kelvinc now
    says the same of one read after. Since #501 an operator is lent it.
  - Where only C sees an argument's type and overloads tie, `_Generic`
    chooses, of functions too, as kelvinc's #41.
  - Under them: `struct T;` before its body, an operator starting the
    next line, `{.some = v}`, `{.none}` and `{1}` where an enum with
    values goes, and `T.none`, which kc had come to refuse.
- **Functions trailing a call, and sorting** (#470), as kelvinc's:
  - `f(a) { ... }` of a plain call, any `{` on a call's line outside a
    condition; `atexit() { ... }` of no parameters.
  - `{ (var s:T):R in ... }`.
  - `xs.sort()`, `.sort { ... }`, `.sorted()`, `.sorted { ... }`,
    `.reverse()` and `.reversed()` of an Array, a stable merge sort.
    - A comparator is given copies of what owns, as `.map`'s function
      is, where kelvinc lends them to an anonymous one (#242).
    - A struct's own `<` came with #471.
  - `<`, `<=`, `>` and `>=` of Strings, `any^`, and `Array<T>(n)` of a
    C count.
- **An enum's value is C's int** (#469), as kelvinc's: `LIMIT.bit(2)`,
  `.flip(n)`, `.abs`, `.sign`, `.pow`, `**` and `.hex` of an
  enumerator or a var of its enum, as an `i32`'s; an enumerator never
  changes.
- **No cast makes a uchr** (#468), as kelvinc's: `x as uchr` and
  `x:uchr` of what is no uchr are an error that names `uchr("k")`.
- **An IO an expression gives, walked** (#466), as kelvinc's: `for
  line in IO(path).lines` and `.read(n)`, the IO held in the block
  around the loop and closed after it.
- **An IO's members and a String's methods** (#464), as kelvinc's:
  - `f.stat`, `f.abspath`, `f.listdir`, `f.glob(p)`, `f.chmod(m)` and
    the rest; `for b in f.read(n)`; `IO.pipe()`.
  - `s.find(x)`, `has`, `starts`, `ends`, `trim()`, `append(x)`, and
    `s.bytes`; a Bytes's `.isUTF8`.
  - kc had dropped a loop over `f.read(n)` from its C; it reads it, and
    says so where it sees no type of what a loop walks.
- **OS and SYS** (#463), as kelvinc's: each member of its table, by the
  same runtime.
  - Results and Optionals of Strings, Arrays and Bytes; SYS.argv.
  - OS.stat's and the other structs, made as kelvinc's anonymous ones.
  - main takes `_kv_argc` and `_kv_argv`, and calls kv_sys_init where
    SYS is read or OS imported.
- **The general properties** (#462), as kelvinc's:
  - `x.size` of any value, a struct's where it has no field of the name.
  - `x.cstr` of a number, a bool, a uchr or a pointer.
  - `p.addr`, and `p.next` and `p.prev` of a pointer.
  - `alignas` before several declarators aligns each of them.
- **`xs.join(sep)` and `xs.joined(sep)`** (#461), as kelvinc's: a new
  String of the elements as `${x}` shows them, `sep` between.
  - kc's `x ?? "text"` of a `cstr?` had printed an address; the text is
    cast, as kelvinc casts it.
- **More of Dictionaries and Sets** (#460), as kelvinc's:
  - `${K: V}` and `${T}` as types; `{k: v}` where a Dictionary is
    written; `Set<T>()`, `Set<T>({a, b})`, `Set<T>(&s)`.
  - `d[k] ??= v` and `d[k] !!= v`; `d0 ?? d1`, `d0 !! d1`, and `??=`
    and `!!=` of two Dictionaries.
  - `x = v` of an Array, a Dictionary or a Set; `d[k] = v` of text, a
    number or `{...}` made the entry's type; `p.isNull`.
- **More of C** (#459), as kelvinc's: `do { } while c`; `p++` and
  `p--` of a pointer; a char's `'\x6b'`; `static` and `extern` before a
  function or a variable, and a local's `static`.
  - kc had dropped all but the first of adjacent string literals,
    `"a" "b"`; it writes them all, which C joins.
- **C's for and several declarators** (#458), as kelvinc's:
  `var a:T = 1, b:T = 2`; `for (init; cond; step) body`, its init the
  loop's own, its steps a list, its body a block or one statement; and
  `x = 1, y = 2`, C's comma.
- **An integer's bits** (#457), as kelvinc's #454: `b.flip()` of a
  bool, `x.flip(n)` and `x.bit(n)` of an integer, and `x.bit(n) = b`
  with `|=`, `&=` and `~=`, through the unsigned type of its width.
- **The new `Bits`** (#456), as kelvinc's: `Bits(a, b, ...)` and
  `bv.append(x)` of bools, `[bool]`s, integers and text `"0b..."`;
  `bv.capacity(n)`, `bv.copy()`, `.count`, `.capacity`, `.isEmpty`,
  `.bin`, `for b in bv` and `bv[n].flip()`.
  - kc had no `u64`, so `.u64s` was its error until #472.
- **`Bits` past 64 bits** (#455), as kelvinc's: a Bits is an owner,
  runtime/bits.c's `kv_bits`, freed where its block ends; `Bits()` is
  empty, and `Bits(n)` is an integer's width of bits.
  - `bv[n]`, its setting, `bv.flip(n)` and the operators call the new
    kv_bits_ functions; a Bits an expression gives is held in a C
    temporary that frees it.
  - Bits of bools, `[bool]`s or text, `.append`, `.count`, `.u64s`,
    `.bin` and the rest were kc's "not yet", read since #456 but
    `.u64s`; `.value` is kelvinc's error.
- **C's types** (#453), as kelvinc's: `struct T`, `union T` and `enum T`
  wherever a type goes; `union T { ... }`, shown `<union T>`; `struct T;`
  of a C struct; a function declared with no body; and `...` after a
  function's parameters, C's variadic.
  - `as` binds looser than a prefix, as kelvinc's P17: `&b as T^` is
    `(&b) as T^`, which kc had read as `&(b as T^)`.
- **An IO's print** (#452), as kelvinc's: `f.print(...)`,
  `f.println(...)`, `f.flush()`, `IO.stdout` and its kin, never freed,
  and `.pretty` of any value print shows; `IO(fd, mode)`, and `.fd`,
  `.pid` and `.signal` each its own.
  - A method of a value kc cannot type is its error; it had been dropped
    unwritten.
- **`Array<T>`, `};` and enums with no name** (#451), as kelvinc's:
  `Array<T>` wherever a type goes; C's `;` after a struct, an enum, a
  global or a statement; `enum { LIMIT = 100 }`, its enumerators `i32`,
  and a fixed array counted by them.
  - An empty `[]` in `Array<Array<T>>([...])` had crashed kc.
  - An enum with no name of cases with values, or in a block, is kc's
    "not yet".
- **An IO's lines, `.write` and `.cstr` of a value** (#450), as
  kelvinc's: `for r in f.lines`, each a `Result<String, i64>`;
  `f.rewind()`; `f.write(x)` by what x is; `Bytes(&$"text")`, held; and
  `v.cstr` of a Result, an Optional, an enum with values or a struct.
  - `f.lines` had crashed kc, and `f.write("text")` had written nothing.
  - A value's `.cstr` is cut past KV_TEMPLATE_STR, as in a template.
- **`try`** (#449), as kelvinc's #76: `try r` is r's `ok` (`some`), or
  a return of its `err` (`none`), passed up as it is; `Result<T,
  E>.err(e)`, `Optional<T>.some(v)` and the rest are of the type written.
  - kelvinc's errors of `try`, in its words.
  - `IO(path)` opens to read; it had crashed kc.
  - Found: `for r in f.lines` crashes kc.
- **A cstr's `.count` and a number's text** (#447), as kelvinc's #21
  and #52: `s.count` is `strlen`; `x.dec`, `x.hex`, `x.oct`, `x.bin`,
  and a pointer's `p.hex`, are text in a buffer that lives until the
  block ends, declared before the statement as a template's storage.
  - Another type, and the text returned, are kelvinc's errors, in its
    words; the text kept by an outer variable is kc's, which kelvinc
    lets go.
  - Four more tests build with kc and print what kelvinc's builds print.
- **`nowhere`** (#446), kelvinc's renamed `nullptr`: `nullptr` is
  kelvinc's error, in its words, with its hint.
- **Template literals** (#445), as kelvinc's #39, #44 and #67:
  `` `a${x}b` ``, a cstr in storage that lives until the block ends, and
  `` $`a${x}b` ``, a String; a value shows as print shows it, `${xs}` and
  `${v.pretty}` too, and a String a call gives is held and freed.
  - kc declares the storage just before the statement that makes it,
    kelvinc at the top of the block.
  - A struct's text, and a long string literal, are cut past
    KV_TEMPLATE_STR, as a string value is; kelvinc gives them their own
    size.
  - A template returned, kept by an outer variable, in a global, or
    empty is kelvinc's error, in its words.
  - examples/fizzbuzz.k and tasks.k, and four more tests, build with kc
    and print what kelvinc's builds print.
- **`.m(a)`, lists and nested functions** (#444), as kelvinc's: `.m(a)`
  in a method is `self.m(a)`, a let's or a var's; `for n in head` walks
  a struct's list along `next`, each node a let, `next` read first; an
  anonymous function inside another has a C name of its own.
  - Another pointer in a `for` is kc's "not yet".
  - examples/linkedlist.k and sequences.k, and tests/run/var_method.k,
    build with kc and print what kelvinc's builds print.
- **`if let x = e`** (#442), as kelvinc's #74: an Optional's `some` or
  a Result's `ok`, bound to `x`, of a place or of a value a call gives,
  with `else` and `else if let`, beside `if let c(x) = e`.
  - Another type, and a missing `=`, are kelvinc's errors, in its words.
  - Found: tests/run/result_if_let.k and five more stop in kc before
    it, on `try`, `Result<T, E>.err(...)`, `Array<String>()`, a RegExp
    literal and `struct timespec;`.
- **An owner moved out** (#441), as kelvinc's: a variable given by
  value, to a function, a method, a case, a `T?`, a Result,
  `Iterator(...)`, `.reduce` or `.merge`, returned or awaited, is dead
  until `t = v` gives it anew; a use is kelvinc's error.
  - The moves of a call are made where it ends: `f(t, t)` built, as
    kelvinc's, until #500.
  - A move is kept by the path that made it (#605), as kelvinc's: an
    `if`'s else begins as the if did, a `switch`'s case as the switch
    did, or as the case before left it, fallen through; after them
    what any of them that goes on moved is moved; a block that ends
    in a `return` puts back what it found. gen.k's `moved_now`,
    `moved_back`, `moved_add` and `moved_into`, of the locals' flags.
    - It counted after a branch in the order written before, so
      `if c { return s }` and then `s` was kelvinc's error, falsely,
      in both.
  - A global moved in, and each element of a for or an `if let`'s
    value moved or returned, are kelvinc's errors, in its words.
  - Found: `{ $0 }` of `.map`, returning what the closure borrows, is
    kelvinc's error alone.
- **An owner copied by its name** (#440), as kelvinc's: `var s = t`,
  `let s = t` and `s = t` of an owner `t` are kelvinc's error, which
  says `t.copy()` or `:= &t`, where kc had copied it, freed twice.
  - String's `s += t` and `s += p.s` too, where kc had taken their
    bytes; `s += &t` and `s += t.copy()` are as they were.
  - An owner in `{...}`, `[...]`, a Dictionary's entries and `c ? a :
    b` is said in kelvinc's words too.
  - Found: kc tracks no move, so a use of `t` after `var s:String? = t`
    is kelvinc's error alone, which #441 refuses.
- **Bytes** (#439), as kelvinc's: an owner, `kv_bytes` in C, in a
  variable, a parameter, a result, an Array, a Dictionary, a struct and
  an Optional.
  - `Bytes()`, `Bytes(n)` of zeros, `Bytes(text)`, `Bytes(&b)`,
    `Bytes(&s)` of a String, `Bytes([0x3e, 32])` and `Bytes(p, n)`.
  - `.count`, `.capacity`, `.isEmpty`, `.cstr`; `b[i]`, checked and
    assignable; `for x in b`, each a `u8`.
  - `append`, `+=`, `insert`, `remove`, `clear`, `reserve` and
    `compact` in place; `.copy()`; `.string()`, a Result;
    `String(&b)`.
  - `==` and `!=`, and `<`, `<=`, `>`, `>=` by the bytes; printed as
    they are, and quoted in an Array.
  - kelvinc's errors, in its words: an owner a place would copy, a
    String where bytes go, argument counts, an unknown method.
  - Not yet: slices, `b + c`, `.at`, `.isUTF8`, `.escape()`,
    `.toBase64()` and RegExp, each kc's error.
  - Found: `var s = t` and `s = t` of an owner copy it, freed twice,
    where kelvinc's error says `t.copy()`, which #440 refuses; `&` of an
    owner an expression gives, `f(&mk())`, goes to C, which fails.
- **An Array's methods** (#438), as kelvinc's: `xs.append(v)`,
  `xs.insert(i, v)`, `xs.remove(i, n)`, `xs.clear()`, `xs.reserve(n)`
  and `xs.compact()`, in place, beside `pop` and `copy`.
  - An owner goes in as kelvinc's: a borrow, `&w`, copied; what an
    expression gives, moved; a place, `w`, kelvinc's error, which says
    `&w` or `w.copy()`. `xs += v` reads it the same way, where it had
    passed `&w` to C and `w` itself, freed twice.
  - Their argument counts, an element of another type and a `let`
    receiver are kelvinc's errors, in its words; kc names an Array
    `$[i64]`.
- **`x.isEmpty`** (#435), as kelvinc's #434: a String's, an Array's, a
  Dictionary's and a Set's `.count == 0`, a fixed array's, a cstr's by
  its first byte, a Range's by its bounds, one without an end never;
  an Iterator's, an iterator's, a Sequence's and a lazy one's `false`,
  its receiver still evaluated.
  - A struct's field of the name wins.
  - Of a number, a bool or a pointer it is kelvinc's error, in its
    words, and so is `xs.isEmpty()`; kc names an Array `$[i64]`.
  - Found: kc reads no `Bytes`, and writes it to C as it is, where C
    fails, which #439 reads; nor an Array's `.append(x)`, which it says
    is not known, which #438 reads.
- **A pointer into a temporary** (#433), as kelvinc's #245: the owner an
  expression gives, which a pointer points into, is held until the call
  or subscript around the pointer is done, `strlen($"abc".cstr)`,
  `println(String(42).cstr)`, `$"zz".cstr[0]`.
  - A call that gives a pointer passes it on to the one around it,
    as kelvinc's; so does one that gives what only C sees, which may be
    a pointer: `strlen(strchr($"xyz".cstr, 'y'))` is 2.
  - Where nothing is around it, `let p := $"x".cstr`, it is still the
    error that says to bind it first.
  - Kept an error: one in an arm of `?:`, or right of `&&`, `||` or
    `??`, which is not always evaluated.
- **Assembly** (#399), left out on purpose, as kelvinc's: `__asm__`,
  `__asm` and `asm(...)` are kelvinc's errors, in its words, naming
  `#inline C`, which kc passes through (#727).
- **`C.name`** (#417), as kelvinc's #416: where the program declares
  no `C`, a local, a global, a function, a struct or an enum, it is
  kelvinc's error, in its words: `as C` names no namespace, and a
  header's names come in bare.
- **Compound literals** (#418), as kelvinc's: `(T){a, b}` of a struct,
  `(Self){...}` in a method, a value anywhere.
  - `T` is a struct declared so far, a block's or a nested one's too;
    before `{` it is the type even where a variable or a function has
    its name, as in kelvinc.
  - `.name = v`, C's designator, in it and in a bare `{...}`; the members
    after it follow on, as in C.
  - A designator of no member, and one value too many, are kc's errors;
    `{` on the next line is kelvinc's, in its words.
  - An array's, `([i32])[1, 2, 3]`, is under Fixed arrays (#419).
  - Not yet: a path's, `(point.kind){...}`.
- **`if (1) name(x)`** (#402), as kelvinc's: declaration_shaped, a
  statement or an assignment `name(x)` of a name kc does not see and one
  argument a declarator could be, x, x^, x[i], is written after `if (1)`,
  so that C never reads a typedef there as a declaration.
- **Lazy map and filter** (#324), as kelvinc's #323: `s.lazy.map(f)` and
  `s.lazy.filter(f)` of a Sequence, f a function of the program or an
  anonymous one, give a lazy Sequence, whose structs and functions kc
  makes as kelvinc does, `_kv_lazyN` and `_kv_lazyN_it`.
  - Its own `map` and `filter` are lazy too, and chain.
  - A value that owns is given to f as a copy, which f owns, and freed.
  - `.lazy` alone or of an iterator, a filter that gives no `bool`, and
    printing one are kelvinc's errors, in its words.
- **C's names:** with a C header imported, a name kc does not know is
  C's, unchecked, as kelvinc has it: `strlen(s)`, `getenv(name)`,
  `nowhere`, a typedef as a type, `n:size_t`, and `:=` of a `cstr`.
- **Types:** every integer from `int8` to `uint128` (#472), `float64`, `float32`, `bool`,
  `cstr`, `String`, `IO`, `uchr`, a struct, `$[T]`, `T^`, main's
  `[cstr]`, and `Dictionary<K, V>` of `String` or integer keys (#211).
  - **`float64`** (#262): literals `1.5`, `2.5e-8`, and `nan`, `inf`
    and `infinity` in any case, where no variable has the name, as
    kelvinc's (#261); arithmetic, comparisons and `as` are C's; printed
    as kelvinc prints it, every digit with a point (#259).
  - **`float32`** (#263): C's `float`, of a literal, `let x:float32 =
    0.1`, or `as float32`, `nan as float32`; printed as kelvinc prints
    it, `0.100000001`.
- **`$[a, b]`** (#266), an Array of its elements: of their one type,
  as kelvinc's, or of the type written, `var fs:$[float64] = $[1, 2.5]`,
  each converted, text into a String, `{a, b}` into a struct.
  - Elements of more than one type are an error, as kelvinc's, and so
    is an owner a variable holds, which `=` would copy.
- **`Set<T>`** (#274) of integers or Strings, as kelvinc's: `${a, b}`,
  of the first element's type, a text's a String's; `${}` and `{a, b}`
  where the type is written.
  - `s.insert(x)` and `s += x`, `true` where it was new; `s += &t`, t's
    elements; `s.has(x)`; `s.remove(x)`, `true` where it was there;
    `s.count`; `s.copy()`.
  - `s.union(&t)`, `s.intersection(&t)`, `s.difference(&t)`, new Sets of
    a borrow of another of the same elements (#275).
  - `s | t`, `s & t` and `s ~ t`, the union, the intersection and what
    is in one alone, of two Sets in variables; `s |= t`, `s &= t` and
    `s ~= t` in place (#276).
  - `s.elements`, an Array of copies in the order added, which a
    variable then owns (#278).
  - `s.pretty`, its text indented, written in place where print shows
    it, else a new String; `s.typename`, `Set<i64>`; `s.reserve(n)` and
    `s.clear()`, in place, of a var (#336).
- **`|`, `&` and `~` of numbers** (#276), bitwise, `~` the XOR, C's `^`,
  between `&&` and `==` as C's; `|=`, `&=`, `~=`.
  - `for x in s`, in the order added, each a let the Set owns; printed
    as kelvinc prints it, `{3, 1, 4}`, `{}` where empty.
  - A let does not change, and `const Set<T>^` borrows one that reads.
- **`${k: v}`** (#267), a Dictionary of its entries, set in order, a
  later key's value winning: of the first entry's types, a text key a
  String's, as kelvinc's, or of the type written, each converted.
  - Keys or values of more than one type are kelvinc's errors, `every
    value of a Dictionary has one type: this one is f64, the first
    i64`; so is a value that owns, held by a variable.
  - A String key an expression gives is held while it is copied in.
  - An Array's or a Dictionary's name in C is its element's as kelvinc
    mangles it, `_kv_dict_String_Dictionary_String_i64`, so they nest.
- **`x:T`** (#264) converts as `x as T` does, kelvinc's annotation:
  `0.1:float32`, `'z':uint8`, `c ? 1:int64 : 0`.
  - The `:` is one where a type's word follows, `int64` to `uchr`, and
    no `(` or `<`; else it is `?:`'s or a `case`'s.
  - A struct's name or a C typedef's too, `p:point`, `n:size_t` (#265),
    but in the middle of `c ? a : b` and in a case's values, where a
    name after `:` is `?:`'s or the case's, as kelvinc reads it; in
    parentheses or a call's arguments there, it is an annotation again.
- **`+` of Strings** (#284), as kelvinc's: `s + t`, a new String,
  whose type a variable infers.
  - Either side a String, a cstr or a uchr, one a String, the left no
    uchr; other sides are kelvinc's error, in its words.
  - A String in a variable is copied, one an expression gives taken, so
    `a + b + c` frees what it made.
- **`==` and `!=` of Arrays and Dictionaries** (#288), as kelvinc's #247
  and #235: two of one type, each element in order, or each entry, by
  its `==`; an Array or a Dictionary of them too.
  - kelvinc's errors, in its words: two of different types; elements or
    values with no `==`, a Set or a struct.
  - An Optional (#343), a Result (#344) or another enum with values
    (#345) in them compares.
- **Fixed arrays** (#354), as kelvinc's #48 and #49, a local's alone:
  `[T](N)` of N elements, `[T]` of as many as its elements give.
  - `var a = [3, 1, 4]`, `let b:[int64](3) = [1, 2, 3]`, `let m =
    [[1, 2], [3, 4]]`, `var z = [uint8](4)` of zeros; C's `int64_t
    a[3] = {3, 1, 4}`, `{0}` where nothing gives the elements.
  - `a[i]`, read and assigned; `a.count`, `a.size`; `for x in a`, as
    kelvinc's #30, each element to its count, a zero ending it early.
  - kelvinc's errors, in its words: a let's element assigned, an array
    of owners; kc's where kelvinc leaves it to C: more elements than its
    count, an element of another type, `a = b`, `var p = a`, `[T]` with
    no elements.
  - `println(a)` is kc's error: kelvinc prints the array's address.
  - An Array of its elements, `Array(a)` and `Array<T>(a)` (#355); an
    Array of fixed arrays, `Array(m)` and `$[a, a]`, is kelvinc's error,
    `an Array of [i64](2) is not here yet: ...`.
  - A struct's member (#356), `struct tray { label: cstr; slots:
    [int64](3) }`: C's `int64_t slots[3]`, given `[a, b]` or `[T](n)` in
    `{...}`, read as a local's, `tr.slots[1]`, `tr.slots.count`; printed
    as kelvinc prints it, `{label: "eggs", slots: [6, 12, 18]}`.
    - Its count is written, `[T](N)`; its elements may own since #364:
      `names: [String](2)`, and an enum's case too, as kelvinc has them;
      each element freed and copied with it, one loop of its innermost
      elements, two counts too, where kelvinc's leaks the inner ones.
  - A parameter (#357), `xs:[const int64]` or `xs:[int64]`, as kelvinc's
    #49: a pointer in C, `const int64_t *xs`, whose count is passed beside
    it; `xs[i]` read, and assigned where it is `[T]`, the caller's.
    - Its argument is a fixed array of its elements: a local's, a member,
      another parameter's; to `[T]`, not a let's or a `[const T]`'s.
    - kelvinc's errors, in its words: `'.count' is a property of arrays,
      and this is i64^, a pointer: ...`; `'a' of 'sum' is a const i64^,
      and this is Array<i64>`; kc's where kelvinc leaves it to C or
      warns, as of a let's array to `[T]`.
    - `for x in xs` of one is kc's error: kelvinc's walks past its end.
  - Of const elements (#425), `[const T](N)`, and `const xs.type` of a
    fixed array, as kelvinc's #34 puts the const on its elements: C's
    `const int32_t a[3]`, a let's or a var's, as kelvinc has them.
    - Changing an element, or passing it to `[T]`, is kc's error, where
      kelvinc leaves it to C or warns.
  - Never a result (#358): `a function cannot return an array, as C
    cannot: return a struct that holds one, or take one as a parameter
    and fill it`, where kelvinc leaves it to C.
  - A global (#359), `var hits:[int64](3)`, `let weekdays:[cstr] =
    [...]`, as a local's: C's `int64_t hits[3] = {0}`, a let's elements
    const, `int64_t const primes[4]`; read and changed by any function.
  - An enum's case value (#360), `enum shape { dot; tri: [int64](3) }`,
    first kc's, and kelvinc's since #361, the same.
    - C's union member of a typedef, `typedef int64_t _kv_shape_tri_t[3]`;
      `shape.tri([3, 4, 5])` and `s.tri = [...]` copy the elements in.
    - `switch` and `if let` bind a copy, a local's array; `s.tri[i]`,
      `s.tri.count`, printed `tri([3, 4, 5])`, `==` element by element.
    - A case's value of a call's enum, `mk(4).tri[1]`, is read through
      a one-element array, as kelvinc's; one that owns is held and freed
      after, as kelvinc holds it.
  - Behind a pointer (#362), `[int64](4)^`, as kelvinc's P61: a local's
    by `:=`, a parameter, a member, a result; C's `__typeof__(int64_t[4])
    *q`, which goes wherever a C type does.
    - `q^[i]`, `q^.count`, `for x in q^`; `q.count` is an error,
      kelvinc's words; `q[i]` is the array `i` rows on, as kelvinc's
      (#726), where it was kc's own error.
    - Its count and elements are the argument's, and a let's array goes
      to it alone where it reads: kc's errors, where kelvinc's C warns;
      `const [int64](4)^` is kelvinc's error in its words.
  - Behind a pointer of no count (#363), `[int64]^`, as kelvinc reads it:
    C's `__typeof__(int64_t[]) *`, which any count's `&a` of its elements
    goes to, and which goes to a counted one, as C has it; `q^[i]`, its
    count passed beside it.
    - `q^.count` and `for x in q^` are kc's errors, where kelvinc's C fails
      or it says there is no length to walk.
  - A local's or a global's of owners is kelvinc's error in its words, `an
    array of owners is not here yet: a struct may hold them`.
  - A parameter's array of owners (#365), `ns:[String]` or `ns:[const
    String]`: its elements lent, the caller's, read, changed and assigned
    through it, as kelvinc's; a member's array, of a var where they change.
  - A part of an owner, a member, an element or `p^` that owns, is not
    copied by `let` or `=`, nor returned: kelvinc's errors in its words,
    where kc aliased it and freed it twice, as `let s = a[0]`, before #365.
  - A count C computes (#366), as kelvinc's P61, a local var's: `var line =
    [uint8](n)`, `var b:[int64](n + 1)`, C's `uint8_t line[n]; memset(line,
    0, sizeof line);`, zeroed where kelvinc leaves the latter unset.
    - `'z' is a let of a count computed at run time, which C cannot fill:
      write 'var z'`, kelvinc's; elements given, a global's, a member's, a
      count of text, kc's errors, where kelvinc leaves them to C.
    - `[T](n)` reads any type's name, a struct's too, `[pt](2)`.
  - Within another (#367): `var m = [[uint8](n)](2)` and `var g:[[int64](n)](3)`,
    C's `uint8_t m[2][n]`, zeroed as one, every count C computes an
    integer; kelvinc's C fails on the former, its `= {0}` of a variable
    length, and leaves the latter unset.
  - Never in an Optional or a Result (#368), as kelvinc refuses one by
    design, in its words: `an Optional holds a value, and an array is none:
    hold an Array, $[i64]`, `a Result holds ...`, of a local's, a member's,
    a parameter's, a result's or a global's type.
  - In an Array (#369), as kelvinc reads it: `[T]` in `$[...]` is an Array in
    turn, `$[[int64]]` an Array of Arrays, and a list among `$[...]`'s or
    `Array([...])`'s elements an Array, `$[[1, 2], [3]]`.
    - Of a count, `$[[int64](2)]`, kelvinc's `an Array grows, and has no
      count in its type: write $[[i64]], ...`; `Array<[T]>()` and a
      Dictionary's value, `an Array of [i64] is not here yet: an element is
      a value C returns`; a Set's, `a key of a Dictionary is an integer or
      a String, not [i64]`; `$[a]` of a fixed array, which kelvinc's prints
      as addresses, the Array's words.
  - A parameter of fixed arrays (#370), `m:[[int64](3)]`, as kelvinc's: a
    pointer to its rows in C, `__typeof__(int64_t[3]) *m`, `m[i][j]`, the
    rows' count written, its count passed beside it; of owners too, lent.
    - `[[T]]`, rows of no count, is kc's error, which C cannot index;
      `[const [T](N)]` kelvinc's `a qualifier of an array is its elements'`;
      rows of another count kc's error, where kelvinc's C warns.
  - A compound literal (#419), `([T](N))[a, b]` and `([T])[a, b]`, as
    kelvinc's #48: a let's or a var's value declares the array, `let q =
    ([int64])[1, 2, 3]`; elsewhere it is C's `(int64_t [3]){1, 2, 3}`,
    a value anywhere: an argument, `a[i]`, `.count`, `for x in`.
    - `[T]` counts its elements, and `[[T]]` its rows by the first, as
      kelvinc counts them.
    - Its elements are checked as a declaration's; one of another type
      where a type is written is kc's error, as are too many elements, no
      elements, and a count C computes, where kelvinc leaves them to C.
  - Not yet: `[[2] = 9]`, `let s:[uint8] = "hi"`, `p := a`.
- **Searching an Array** (#342), as kelvinc's #248: `xs.contains(x)`,
  a `bool`; `xs.firstIndex(x)` and `xs.lastIndex(x)`, the index of the
  first or the last equal to `x`, an `i64?`, or `none`.
  - `x` is compared by the elements' `==`; of a function,
    `xs.firstIndex { $0 > 2 }`, the elements it says true for, given a
    copy of one that owns.
  - `x` is looked at, not moved; one an expression gives is held and
    freed after, as is an Array an expression gives.
  - kelvinc's errors, in its words, as of a Dictionary's (#339): an
    Array's `firstKey` is `an Array has no '.firstKey': it is a
    Dictionary's; an Array's is '.firstIndex'`, a Dictionary's
    `firstIndex` the other way.
  - Optional elements compare by `==` since #343, `ns.contains(none)`,
    Result elements since #344, `rs.contains(err($"x"))`, and those of
    any enum with values since #345.
- **An Array, a Dictionary or a Set has no arithmetic** (#287), as
  kelvinc has it, in its words: `xs + 2`, `2 + xs`, `d < d2`, `s - t`,
  `an Array has no operator '+': compare its elements`, a Dictionary's
  entries; a Set's `|`, `&` and `~` are its own (#276).
- **A cstr neither joins nor steps** (#283), as kelvinc since #282, in
  its words: `"a" + "b"` and `x + y` of cstrs, `'+' joins Strings, and
  a cstr is not one`; `"a" + 1` and `x - y`, a cstr is text, not a
  cursor (#52).
- **Lets do not change** (#271), as kelvinc has it: assigning a let, `+=`
  to it, its member or element, `xs.pop()` or `d.remove(k)` of it, is
  kelvinc's error, word for word.
  - A let, `'x' is a let and cannot change; declare it with var`; a
    parameter, a let unless written `var n:T`, which kc takes now; a
    loop's element, an `if let`'s or a case's value; a range's count.
  - A change through a pointer, `p^ += 1`, is the pointee's, not the
    let's.
  - **`&x` of a let is a `const T^`** (#272), as kelvinc's, C's
    `const T *`: what it points to does not change, `p^ = 2` an error,
    and it goes where a `const T^` goes, not a `T^`.
    - Of an owner too, a String, an Array or a Dictionary, as kelvinc
      since #273; a function that reads one takes `const $[T]^`.
- **Statements:** `var` and `let`, with a type or one inferred (#214);
  `=`, `:=`, `+=` and the rest; `if`, `else if`, `else`; `while`;
  `for i in a..<b`; `for x in s` of a String or an Array, `for k, v in
  d` and `for k in d` of a Dictionary, in the order added (#269); `return`,
  `break`, `continue`.
  - **`=` and `:=`** (#233), as kelvinc has them: a reference, a `cstr`
    or a `T^`, takes `:=`, and a value `=`, in a declaration, a global's
    or an assignment; else kelvinc's error, as `'s' is a reference
    (cstr): assign it with ':=', not '='`.
  - An Array and a Dictionary are not checked, as kelvinc does not
    check them.
- **`switch`** (#210), as kelvinc has it (#63): `case a, b:` and
  `default:`; a case ends at the next, its own block, with a `break`
  where it does not jump; a switch on an enum names every enumerator or
  has `default:`, any other has `default:`.
- **A source is UTF-8** (#298), as kelvinc's #295: a BOM, a byte that
  is no UTF-8, and C's prefixes, `L"..."`, `u8'x'`, are kelvinc's errors,
  in its words, at the line.
  - kc reads a file's bytes with C's stdio first, `fopen` and `fgetc`,
    as IO's `.string` says only where the UTF-8 breaks (#406), not
    kelvinc's words at the line.
- **A String literal is every byte of it** (#299), as kelvinc's:
  `KV_STRING_LIT`, C's sizeof, so `$"\u{0}mid"` holds its NUL.
- **`\u` escapes in a literal** (#293), as kelvinc's #292: `\u{X}`,
  `\uXXXX` and `\UXXXXXXXX`, each the codepoint's UTF-8 bytes in C,
  a control character too; kelvinc's errors of a surrogate, one past
  10FFFF and a malformed escape, in its words.
- **Expressions:** numbers, characters, `"..."` and `$"..."`, `true`,
  `false`, calls, `.member`, `.method()`, `a[i]`, `&x`, `p^`, `x as T`,
  `{a, b}` of a struct, `$[]`, `${:}`,
  `! - * / % + - < <= > >= == != && ||`, and `c ? a : b` (#232).
  - `c ? a : b` binds the loosest and groups to the right; a `?` right
    after a value and before `.` or `[` is a chain's instead.
  - An empty `$[]`, `${:}` or `${}` is taken only where its type is
    written (#348), as kelvinc takes it: a declaration's value, an
    element of a list, a Dictionary's value, a struct's member.
    - Of the type's kind: `let d:Dictionary<String, i64> = $[]` is
      kelvinc's error, as are `${}` for `${:}` and the other way.
    - Elsewhere, kelvinc's error in its words, so nothing reaches C
      or is read as `none`: `doc.fields(${:})`, `f($[])`, `d = ${:}`,
      `return $[]`, `xs == $[]`, `let o:Dictionary<String, i64>? =
      ${:}`.
    - kelvinc's errors say to write `Dictionary<K, V>()` or
      `Array<T>()`, which kc reads since #349.
  - `Array<T>()` and `Dictionary<K, V>()` (#349), as kelvinc's #57 and
    #65: an empty one of the type written, anywhere a value goes.
    - `var xs = Array<int64>()` is an `Array<i64>`; an argument, a
      case's value, a return, a member, `xs == Array<int64>()`.
    - Without `()`, kelvinc's error: `Array<i64> is a type: make one
      with Array<i64>(), or write it after ':'`.
    - `Array<T>([a, b])`, `Array<T>(&a)` and `Array<T>(n)` (#350), as
      kelvinc's #57 and #58: the elements, as `$[a, b]` of T; a copy
      of the Array that `&a` lends, by its `_copy`; `n` zero elements,
      by its `_zeros`, `""` of a String.
      - kelvinc's errors, in its words: `Array<T>(a) would copy an
        owner: write a.copy(), or Array<T>(&a)`; `an element of
        Array<i64> is an i64, and this is text`, of `$[...]` of a type
        written too; more than one.
      - kc's own where kelvinc leaves it to C: `Array<i64>(n) takes a
        count, and this is text`; `Array<String>(&a) copies an
        Array<String>, and this lends Array<i64>`.
    - `Dictionary<K, V>({k: v})` and `Dictionary<K, V>(&d)` (#351), as
      kelvinc's #65: the entries, read as `${k: v}` of K and V, `${...}`
      or `{:}` too; a copy of the Dictionary that `&d` lends.
      - kelvinc's errors, in its words: `a key of Dictionary<String,
        i64> is text: a cstr, a template, or a String`, `is an integer,
        not String`, of `${...}` of a type written too; `Dictionary<K,
        V> takes nothing, the entries in {k: v, ...}, or a borrow of
        another, '&d'`; `an empty Dictionary is written ${:}`.
      - kc's own where kelvinc leaves it to C: `a value of
        Dictionary<String, i64> is an i64, and this is text`.
    - `Array([a, b])` (#352), as kelvinc's #58: T the elements' one
      type, as of `$[a, b]`: `Array([3, 1, 4])` an `Array<i64>`.
      - kelvinc's errors, in its words: `Array([]) has no element type:
        write Array<T>()`, `Array() has no element type: ...`,
        `Array(x) has no element type: ...`, and of elements of no one
        type, `none` among them, `write Array<T>([...])`.
    - `Array(&a)` (#353), as kelvinc's #58: a copy of the Array that
      `&a` lends, of its type, as `Array<T>(&a)` (#350); of what is no
      Array, kelvinc's `Array(x) has no element type: ...`.
    - `Array<T>(a)` and `Array(a)` of a fixed array (#355), as kelvinc's
      #57 and #58: an Array of its elements, by `_from`; of another
      element type kc's error, where kelvinc's C warns.
  - Its type is `a`'s, or `b`'s where `a` is a word, as `none`; each
    arm is read by the type that takes it, so `n % 2 == 0 ? n / 2 :
    none` is an `int64?`.
  - Of owners, as kelvinc's O12: two places are a place, read where
    they are and not copied by `=`; two values expressions give are a
    value; one of each is an error but where it is returned, which
    moves either out.
  - kc's own source chooses so in five places.
  - A `?` after a `?` in a string is written `\?`, as kelvinc writes
    it: Kelvin has no trigraphs (#220).
- **Of the prelude and IO:** `.count`, `.copy()`, `.cstr`, `.pop()`,
  `.uchr`, `.utf32`, `String(text)`, `String(n)` of a number or a
  `bool` (#212), `println`, `IO(path, mode)`,
  `.string` (a Result, #406), `.write(&s)`, `.close()`, `.error`, `.status`,
  `IO.exec(args, mode)`.
  - `String()` is an empty String (#414), as kelvinc's; kc stopped on
    it before.
  - `String(x)` of an owner is kelvinc's error in its words (#414), as
    kelvinc's #412, where C took it for text.
    - Of a place, `String(s)`: `String(x) would copy an owner: write
      x.copy(), ...`.
    - Of a String an expression gives, `String(name())` or
      `String($"lit")`: `String(x) of a String is one already: leave
      out String(...)`.
    - Of another owner, `String($[1, 2])`: what String takes, `and this
      is Array<i64>`; of two values, what it takes.
  - A String's `.escape()` and `.unescape()` (#300), new Strings, as
    kelvinc's, of runtime/string.k; with an argument, kelvinc's error,
    as kc has no RegExp.
- **Of a Dictionary** (#211): `d[k]!`, checked; `d[k] = v`, which sets
  the entry; `d.has(k)`, `d.get(k, default)`, `d.count`; `d.remove(k)`,
  which frees what the entry held and is `true` where it was there
  (#270).
  - `d.find(k)`, a `V^` to the value or `nowhere`, a `const V^` of a let;
    `d.pretty` and `d.typename`, as a Set's; `d.reserve(n)` and
    `d.clear()`, in place, of a var (#337).
  - `d.merge(&e)`, in place, and `d.merging(&e)`, a new Dictionary, as
    kelvinc's #236: e's entries added, each value copied; where d has
    the key, the function's value, `d.merge(&e) { a, b in ... }`, else
    e's; e by value moves in and is freed after (#338).
  - `d.contains(v)`, `d.firstKey(v)` and `d.lastKey(v)`, as kelvinc's
    #249: whether `v` is among the values, by their `==`, and the key
    of the first or the last in the order added, a `K?` of a copy, or
    `none` (#339).
    - Of a function, `d.contains { v in v > 4 }`, the values it says
      true for; `containsWithKey`, `firstKeyWithKey` and
      `lastKeyWithKey` take each key and its value, as #331's.
    - `v` is looked at, not moved; one an expression gives is held and
      freed after, as is a Dictionary an expression gives.
  - `d.keys` and `d.values` (#285), Arrays of copies in the order added,
    as a Set's `elements`: new values a variable then owns, of a
    Dictionary in a variable, a temporary, or through a borrow.
  - A String key an expression gives, `d.has($"a")`, is held for the
    call (#270), and for `d[k] = v`, `d[k] += v`, `d[k]!` and `d[k]`
    read whole (#314): the checked place outlives it, as `d` keeps a
    copy.
  - `d[k]` read whole is a `V?` (#219), as kelvinc's since #218: `some`
    of a copy of the entry's value, or `none` where the key is missing.
    - It goes where a `V?` goes: `let a = d[k]`, `d[k] ?? v`,
      `if let some(v) = d[k]`, an argument, a return.
    - Assigning, modifying or going into `d[k]` is the place, checked:
      `d[k] = v`, `d[k] += 1`, `d[k].m`, `d[k]!`.
    - kc makes the `V?` of each Dictionary's `V` as it reads the type,
      so that the enum is written before the code that uses it.
  - `x!` of an Optional is `x.some`.
  - An Optional where a value goes is an error that names `!` and `??`,
    as kelvinc's (#219).
  - `d[k]?.m` chains (#221).
- **Ownership:** a `String`, an `Array`, a `Dictionary`, an `IO` or an
  enum with an owning case is freed by C's `cleanup` attribute; `return
  x` of a local one moves it out; a global one is freed at exit by
  `_kv_free_globals`, as kelvinc frees them (#215).
  - One an expression gives, where it is only read, is held in a
    temporary and freed once the expression is done (#227), as
    kelvinc's of #187: `({ T _kv_tmpN = f(); use(_kv_tmpN); })`.
    - That is an argument a function does not take by value, as
      `println(String(n))`, a borrow of it, `&f()`, a member, an element
      or a method of it, either side of `==`, the source of `for x in`,
      and a statement that drops it.
    - A member or an element that owns is copied out of it, as kelvinc
      does; a pointer into it, as `String(n).cstr`, is an error that
      says to bind it.
    - One bound, assigned, appended, returned or given by value moves
      there instead.
  - A struct owns where a member does (#225), as `struct pet { name:
    String; tricks: $[String] }`: kc writes its `_kv_T_free`,
    `_kv_T_take` and `_kv_T_copy` as kelvinc does, so it is freed,
    moved out by `return`, held in an Array, and freed before `=` gives
    it a new value. A local owner in `{a, b}` is copied, `.copy()`.
  - An owner a function or a method takes by value moves in, and the
    function frees it (#226), as kelvinc's O5: the parameter is
    `_kv_x_in` in C, bound to a local `x` that is freed where the
    function ends, or moved out by `return x`.
    - A whole variable moves in by `_take`; one an expression gives, as
      `f($"x")`, goes in as it is; a member or an element is an error
      that says to pass a borrow or a copy.
  - `.copy()` copies any owner but an `IO`: a String, an Array, a
    Dictionary, a struct or an enum that owns (#226).
  - Each type's C comes once, after the types it holds by value: an
    Array's element before the Array, a struct's members before the
    struct, an enum's values before the enum (#225).
- **`async f(x)` and `await t`** (#313), as kelvinc's #312: the call on
  a thread of its own, a `Task<R>` of its result, `Task` of none.
  - The arguments pass as any call's, a value copied and an owner moved
    in by `_take`; a cstr or pointer parameter is kelvinc's error, in its
    words, and so are a method, a C function, a block, a global, and a
    Task dropped, printed, copied or of another type than written.
  - `await` of a variable, of an element, `await ts[i]`, or of a Task an
    expression gives; a Task is an owner, freed, so awaited, where its
    block ends, held in an Array, passed, returned and assigned anew.
  - Each call's environment, `struct _kv_f_fn_env`, and its thread's
    function come before the functions and after them, named as
    kelvinc names them; kc links `-lpthread`.
  - Not yet: kc tracks no moves, so a second `await t` ends the program
    where kelvinc refuses it, and `async` takes no function value.
- **Each statement is one line,** but inside `( )` and `[ ]`.

### Difficulties in the way of self-hosting kelvinc

What kc met, and what a Kelvin kelvinc would meet, so that the next
steps can take them on one at a time.

#### The size of the language

- **kelvinc is 17,700 lines of C** (parser.c alone 12,300), and kc's
  3,900 lines of Kelvin read a part of what kelvinc reads (#231).
- **Taken into the subset since #204:**
  - `switch` and enums (#210), and enums with values (#215);
  - `c ? a : b` (#232);
  - overloading (#234);
  - `Dictionary` (#211), and `d[k]` as an Optional (#219);
  - methods of `extend` and `let T.m` (#213);
  - type inference (#214);
  - Optional and Result (#217), `x!`, and chains (#221);
  - `#import <x.h> as C` (#207);
  - of ownership's rules (documents/ownership.md): a struct that owns
    (O7, #225), passing by value (O5, #226), temporaries (O11, #227),
    and `c ? a : b` of owners (O12, #232);
  - printing what kelvinc prints, `some(3)`, `{x: 1, y: 2}`, `[1, 2]`
    and `{"a": 1}` (#229, #230, #268).
- **Left out of the subset:**
  - the overloads of methods; and kelvinc's names of the functions of
    an imported Kelvin file, `f__i64` overloaded or not, so kc cannot
    link a module kelvinc builds of Kelvin;
  - comparing an Optional, `x == none` or `x == 3` (#79);
  - `Optional`'s `map` and the rest of its methods;
  - methods and attributes of a built-in type;
  - nested functions, and of function types (#428) arrays and
    collections of them, and `((T):R)^`;
  - `union`;
  - the bitwise operators but `|`, `&` and `~` (#276), `++` and `--`;
  - `--lib` and `.kh`; `#inline C` is passed through (#727);
  - and kelvinc's hundreds of messages.
- **There is no specification but kelvinc:** grammar.md is partial, and
  the 834 tests of tests/run.sh are the nearest thing. A Kelvin kelvinc
  would take passing them as its acceptance.

#### A bug found on the way

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
  - kelvinc does too since #205.

#### libc, and C of our own

libc is allowed, as it is to any C program; C of our own is not.

- **libc takes these off the list,** since kc reads `#import <x.h> as C`
  (#207):
  - The environment: `getenv` reads `KELVIN_HOME`, `CC` and `TMPDIR`,
    beside `-m` and `-cc`.
  - A temporary file: `$TMPDIR/kc-<pid>.c`, by `getpid`, which `remove`
    takes away once `cc` is done.
  - Not yet used: `mkdtemp`, which writes its template in place, where a
    String's `.cstr` is `const`; `exit`, where returning from main does.
- **A name that is C's unchecked hides a slip:** with a C header
  imported, a Kelvin function called before it is written is taken for
  C's, so the C compiler, not kelvinc, says it is undeclared. kc's
  gen.k met it, and declares `decl_named` first.
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

#### Writing a compiler in Kelvin

- **Methods could not change `self`** until var methods (#318, #320):
  - the parser's state is in globals;
  - the readers of examples/lambda.k are functions of a `reader^`;
  - kc's methods, since #213, are queries: `types[y].owns()`,
    `nodes[s].jumps()`, and `node.leaf(kind, t)`, a function of the type.
- **No recursive types:** the tree is an Array of nodes linked by
  index, as in examples/ski.k.
- **Declared before use:** mutual recursion needs prototypes first, as
  `let parse_expr():int64` and `let gen_expr(n:int64)`.
- **Inference stops at arithmetic:** `var j = n - 1` is an error.
  - Since #214 kc infers as kelvinc does: a literal, `int64`, `uint8` of
    a character, `bool`, `String` of `$"..."`; a comparison; a cast; and
    what it sees of a name, a call, a member or an element.
  - `"text"` is a `cstr` by `:=`; an empty `$[]`, `${:}`, `{...}` and
    what only C sees still need a type.
  - kc's own variables of a literal, 34 of them, say no type now. The
    rest keep theirs: one of arithmetic must, and the others are left
    as written.
  - kc's `.count` is an `int64`, where kelvinc's is a `size_t`: a
    variable inferred from one differs in its C type.
- **Characters:**
  - a character literal is C's `int`, and a `uchr` is a struct;
  - a String cannot be indexed, `s[i]` being an error;
  - so the source is held as `$[uint32]`, four bytes a character.
- **No switch on text:** a keyword is found by a chain of `tok_is`.
  - The kinds of tokens, nodes and types are enums since #210, `tkind`,
    `nkind` and `ykind`, and gen.k switches on them.
  - An enum must come before the struct that holds one, in kelvinc.
- **Text:**
  - `+=` appends text, a `uchr` or `&s`;
  - a number's text is `String(n)` since #212, where kc wrote the digits
    itself; `.cstr` and templates live in buffers of their block.
- **Errors:**
  - kc sets a global `failed` and moves the parser's cursor to the end,
    so that every loop stops;
  - `Result` would carry them, at the price of every parser; kc's
    `load` gives one since #217, read by `if let err(why) = load(path)`.
- **Lines:**
  - a statement ends with its line, so a long condition is one long line;
  - `as` is a keyword, so nothing is named `as`.
- **Speed:**
  - Since #211, a function, a global, a struct, an enum or an
    enumerator is found by its name in a `Dictionary`, where kc walked
    every declaration.
  - A local is still found by walking the scope, and a keyword by
    comparing codepoints.
  - What the Dictionaries give is that a name costs the same however
    many declarations there are: at kc's own size, 3,900 lines, a
    compile of kc by kc takes about 12 ms (#231), where 2,200 lines
    took 7 at #211.

#### The runtime is part of the language

- **The C must fit kelvin_prelude.h:**
  - kc writes `KV_ARRAY(...)`, `KV_STRING_APPEND`, `kv_io_*` and the
    `_kv_array_i64` names as kelvinc does;
  - GNU C's statement expressions and `cleanup` attribute;
  - written down since #208 in
    [documents/c-contract.md](../documents/c-contract.md), from
    kelvinc's output.
- **Modules:** a module built by kelvinc names its functions by their
  types. kc names an overload as kelvinc does since #234, but not yet
  every function of an imported file; `<IO>` works because its
  functions are C's.

### Next steps

Each of these is one change of its own:

1. Grow kc's subset, keeping the fixpoint, and rewrite kc in each new
   part as it comes, from the list of what is left out.
2. Run kc on the tests of tests/run.sh that fit the subset, to count how
   far it reads, and the programs kc builds under tests/asan.sh's
   counting allocator, which is done by hand so far.
