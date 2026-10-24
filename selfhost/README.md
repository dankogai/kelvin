# Self-hosting Kelvin: experimental

**Can Kelvin compile itself?** For a subset, yes. `kc` is a compiler
written in Kelvin alone. It reads the subset it is written in, writes C
as kelvinc does, and hands that C to `cc`. Built in stages, as gcc
bootstraps itself, it reaches a fixpoint (#204).

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
- **In CI** (#228): the `selfhost` jobs run `bootstrap.sh` and
  `sanitize.sh` with gcc and clang on Ubuntu, and clang on macOS.

## Goals

Agreed in #279.

- **What kc need not do:** read C's source, `#import <foo.h> as C` and
  `#inline C { ... }`.
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

## Files

| File | What it is |
|---|---|
| [kc.k](kc.k) | the driver: options, reading files and their imports, writing the C, running `cc` |
| [lex.k](lex.k) | the tokens |
| [parse.k](parse.k) | the tree and the types |
| [gen.k](gen.k) | the C |
| [sample.k](sample.k) | a program of the subset, built by both compilers, which must print the same |
| [bootstrap.sh](bootstrap.sh) | the stages and their checks |
| [sanitize.sh](sanitize.sh) | kc built with ASan and UBSan, which must write the same C (#228) |

## The stages

```sh
selfhost/bootstrap.sh
selfhost/sanitize.sh
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
- Everything goes into `build/selfhost/`; nothing is removed.

## Using kc

```sh
build/selfhost/stage3 [-c | --emit-c] program.k [-o path] [-m modules] [-cc compiler]
```

- The options are kelvinc's (#281).
  - `-c` makes an object, `program.o` or the `-o` path, which
    `kelvinc -o program program.o` links.
  - `--emit-c` writes the C, to the `-o` path or stdout, and stops.
  - Else kc builds the program, `a.out` or the `-o` path.
- The C is a temporary file, `$TMPDIR/kc-<pid>.c`, or in `/tmp`, removed
  once `cc` is done (#207).
- `-m` names the directory of `kelvin_prelude.h` and the libraries.
  - Without it: `$KELVIN_HOME/modules`, as kelvinc reads `KELVIN_HOME`,
    else `modules`, from the top of the repository.
- `-cc` names the C compiler; without it, `$CC`, else `cc`.

## The subset

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
    - `j < j`: kelvinc's error, and an operator of its own (#121) is
      not kc's yet.
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
  - `x ?? d` of an Optional that owns (#340), as kelvinc's #250:
    `d.lastKey(v) ?? $"none"`, `w[k] ?? "none"`.
    - x's value is a copy where x is a place, else taken from it.
    - d is a copy where it is a place, else taken, and is made only
      where x is none.
    - d of another type is kelvinc's error in its words, of any `??`:
      `'??' of String? falls back to a String? or a String, and this
      is a number`.
    - kc reads `??` left to right, and `x ?? d` of a `T?` d is not
      kc's yet, so `a ?? b ?? 0` is kelvinc's alone (#251, #252).
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
  - kc reads one as the function of `.lazy.map` and `.lazy.filter` alone:
    elsewhere it is kc's error, as kc has no function values.
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
  `nullptr`, a typedef as a type, `n:size_t`, and `:=` of a `cstr`.
- **Types:** `int64`, `int32`, `uint8`, `uint32`, `float64`, `float32`, `bool`,
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
    - Its count is written, `[T](N)`; its elements own nothing, where
      kelvinc's may: not yet kc's.
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
  - Never a result (#358): `a function cannot return an array, as C
    cannot: return a struct that holds one, or take one as a parameter
    and fill it`, where kelvinc leaves it to C.
  - A global (#359), `var hits:[int64](3)`, `let weekdays:[cstr] =
    [...]`, as a local's: C's `int64_t hits[3] = {0}`, a let's elements
    const, `int64_t const primes[4]`; read and changed by any function.
  - Not yet: a case's value, a pointer to one, one in another type, a
    parameter of owners or of fixed arrays; a count C computes, as
    `[uint8](n)`;
    `([T])[a, b]`, `[[2] = 9]`, `let s:[uint8] = "hi"`, `p := a`.
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
    as IO's `.string` would end kc in words of its own.
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
  `.string`, `.write(&s)`, `.close()`, `.error`, `.status`,
  `IO.exec(args, mode)`.
  - A String's `.escape()` and `.unescape()` (#300), new Strings, as
    kelvinc's, of runtime/string.k; with an argument, kelvinc's error,
    as kc has no RegExp.
- **Of a Dictionary** (#211): `d[k]!`, checked; `d[k] = v`, which sets
  the entry; `d.has(k)`, `d.get(k, default)`, `d.count`; `d.remove(k)`,
  which frees what the entry held and is `true` where it was there
  (#270).
  - `d.find(k)`, a `V^` to the value or `nullptr`, a `const V^` of a let;
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
    where kelvinc refuses it, and kc has no function values to start.
- **Each statement is one line,** but inside `( )` and `[ ]`.

## Difficulties in the way of self-hosting kelvinc

What kc met, and what a Kelvin kelvinc would meet, so that the next
steps can take them on one at a time.

### The size of the language

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
  - `try`, `Optional`'s `map` and the rest of its methods;
  - attributes, subscripts and operators of `extend`;
  - anonymous and nested functions, and function types;
  - templates, `"""` and `$/.../` with its check;
  - `union` and `typealias`;
  - integers but `int64`, `int32`, `uint8` and `uint32`;
  - the bitwise operators but `|`, `&` and `~` (#276), `++` and `--`;
  - `#inline C`, `--lib` and `.kh`;
  - `#line`;
  - and kelvinc's hundreds of messages.
- **There is no specification but kelvinc:** grammar.md is partial, and
  the 834 tests of tests/run.sh are the nearest thing. A Kelvin kelvinc
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
  - kelvinc does too since #205.

### libc, and C of our own

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

### Writing a compiler in Kelvin

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

### The runtime is part of the language

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

## Next steps

Each of these is one change of its own:

1. Grow kc's subset, keeping the fixpoint, and rewrite kc in each new
   part as it comes, from the list of what is left out.
2. Run kc on the tests of tests/run.sh that fit the subset, to count how
   far it reads, and the programs kc builds under tests/asan.sh's
   counting allocator, which is done by hand so far.
