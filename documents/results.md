# Results: `Result<T, U>`

`Result<T, U>` is a value with an outcome (#75): an enum with values
(see [enums.md](enums.md)) with the cases `ok: T` and `err: U`, made
for each pair of types as it is written. It holds the value of either
case, owners included, and then owns it.

Where C returns an error code and hands the value back through a
pointer, or sets `errno`, a Kelvin function returns a `Result`, and the
caller cannot read the value without facing the case. `Optional<T>`, or
`T?`, is its special case: a Result whose `err` carries nothing, with
its cases named `none` and `some` (#72); it has its own document,
[optionals.md](optionals.md).

**Where it lives:** the prelude's rules, kelvinc's C. Each `Result<T, U>` is a struct kelvinc writes, as an enum with values is, and a wrong case ends the program through the prelude's `kv_case_fail`, in `libkelvin`, linked without an import.

<!-- fragment -->
```kelvin
let parse(s:cstr):Result<int64, String> {
    if s.count == 0 { return err($"empty") }   // err(e), a word
    return int64(s)                              // a T becomes ok(T) by itself
}
var r = parse("42")
var e = parse("")
println(r.is(ok), " ", r.ok, " ", e.err)       // true 42 empty
println(r ?? -1, " ", e ?? -1)                 // the ok value, or the default: 42 -1
println(r.cstr, " ", e.cstr)                   // ok(42) err("empty")
println(r == 42, " ", r == e, " ", r != ok(41))   // true false true: the same case and value (#79)
var twice = parse("21").map { int64($0 * 2) }    // ok(42), a Result<i64, String> (#80)
var checked = parse("0").flatMap(positive)     // err("zero"): positive gives a Result itself (#81)
if let v = r { println(v) } else { println(r.err) }   // binds the ok value (#74)
if let err(why) = e { println("failed: ", why) }   // binds the err, by the case's name (#78)
switch e {                                     // exhaustive, as an enum's
case ok: println(e.ok)
case err: println("failed: ", e.err)
}
e = 5                                          // ok(5): sets the case
e.err = $"later"                               // err(later)
e.ok += 1                                      // a place, checked: of err, the program ends
var q:Result<point, int32> = {1, 2}             // the T's initializer, wrapped; so is return {1, 2} (#77) as ok
var bad:Result<point, int32> = err(404)
var w = Result<int64, cstr>.ok(5)                // the cases by the type's name
var rs:$[Result<int64, String>] = $[1, err($"x"), ok(3)]   // elements, wrapped
```

- **The type** is `Result<T, U>`, `T` and `U` any value types but an
  array or a function: `Result<i64, String>`, `Result<point, i32>`,
  `Result<$[i64], cstr>`.
  - Either may own, and the Result then owns the value it holds: freed
    when its block ends, moved by `return` and by passing, copied by
    `.copy()`, as [ownership.md](ownership.md) says.
  - An array is no value, so hold an Array.
- **Making one:** a `T` where a `Result<T, U>` is expected becomes
  `ok(T)` by itself.
  - That is in a declaration, an assignment, a member, an element, an
    entry or a `return`.
  - `ok(v)` and `err(e)` are words there, read where no function or
    variable of that name is in sight, since Kelvin has no leading dot
    to mark a case.
  - An owner moves in, as a case's value does.
  - `Result<T, U>.ok(v)`, `Result<T, U>.err(e)` and `Result<T, U>(v)`
    spell them out, where nothing says which Result is meant.
- **Reading:** `r.ok` and `r.err` are the values, checked at run time.
  - Of the other case, the program ends with `case 'ok' of Result<i64,
    String> is not current: it is 'err'`.
  - Each is a place: `r.ok += 1`, `r.err += "!"`.
  - `r ?? y` is the `ok` value if that is the case, else `y`.
    - For a `T` that does not own, of a Result in a variable, a member
      or an element; for an owner, `if let` or `switch` on it.
- **Testing:** `r.is(ok)`, `r.is(err)`, `r.case` (0 for ok, 1 for err),
  and `switch r { case ok: ... case err: ... }`, exhaustive.
  - `case ok(v):` and `case err(e):` bind the value for the body (#119).
  - Of a Result that owns, `.is` and `.case` take a place, since one an
    expression gives would be lost with what it holds: bind it first,
    or `if let` on the call (#99).
- **`if let v = r { ... } else { ... }`** (#74) runs the block with `v`
  bound to the `ok` value when that is the case.
  - `v` is a let the Result still owns, as a loop's element is: borrow
    it, or copy it.
  - `r` may be a variable or a value a call gives, read once.
  - `else if let` chains, and the `else` block may read `r.err`.
- **`if let err(e) = r { ... }`** (#78) names the case: `e` is the
  `err` when that is the case.
  - `if let ok(v) = r` spells the form above out.
  - `if let ok(v) = r { ... } else if let err(e) = r { ... }` covers
    both.
  - The same works for any enum with values, `if let n(x) = j`; see
    [enums.md](enums.md).
- **`try r`** (#76) is the `ok` value when that is the case, and
  otherwise returns from the function with the `err`, passed up as it
  is.
  - `let n = try parse(s)`, `return try parse(a) + try parse(b)`, or
    `try f()` alone, which drops the value.
  - It is a prefix, as `-x` is, so `try f(x) + 1` is `(try f(x)) + 1`.
  - The function must return a `Result` whose `err` has the same type.
  - The value owns as its Result did.
    - `try` of a variable whose value owns is an error: `try` the call
      itself, `try r.copy()`, or `if let`.
    - Of a variable whose err owns, the err moves out of it.
  - See the example below.
- **`==` and `!=`** (#79) compare two Results of one type: the same
  case, and equal values.
  - A String's by its bytes, a nested Result's or Optional's by its own
    `==`, a `cstr`'s by its address, as Kelvin compares one.
  - A value, `ok(v)` or `err(e)` on the other side is wrapped, as where
    a Result is expected: `r == 42`, `r == err(2)`.
  - A value whose type has no `==`, a struct or an Array, has none here
    either.
  - One that owns, made on the spot (`err($"x")`), is not taken, since
    nothing would free it: bind it to a variable.
  - The other operators are not for Results.
- **`r.map(f)`** (#80) is a `Result<U, E>`: `ok(f(v))` when `r` is
  `ok(v)`, else the `err` carried over.
  - `f` takes the `T` and gives a `U`: a function by name, a function
    value, or an anonymous function, `r.map { i64($0 * 2) }` or
    `r.map { (v:i64):i64 in v * 2 }`, whose result kelvinc sees or
    which writes it.
  - **`r.mapErr(g)`** maps the `err` instead, to a `Result<T, F>`.
- **`r.flatMap(f)`** (#81) takes an `f` that gives a `Result<U, E>`
  itself, with the same `E`, and is that Result when `r` is `ok(v)`,
  else the `err` carried over: `parse(s).flatMap(positive)`.
  - Of a variable that owns, `map` and `flatMap` would move the value
    out, so map the call itself, `parse(s).map(f)`, or `r.copy()`.
  - Calls chain, `parse(s).map(f).flatMap(g)`.
- **Text:** `r.cstr` is `ok(42)` or `err("empty")`, the value's text
  inside; `${r}` the same.
- **In C**, each `Result<T, U>` is a struct `_kv_res_<T>_<U>` of a byte
  tag and a union of the two values, with the functions of an enum with
  values: `_at` (checked, a pointer), `_get`, `_set` and `_make` per
  case.
- **Not yet:** `==` of a struct value with its own `==`, and `try` of
  an `err` that must change type on the way up.

## From C: the value through a pointer, the error beside it

C returns an `int` and hands the value back through a pointer, as
`lstat(path, &buf)` does, though `buf = other` has copied a struct
since C89. A Kelvin wrapper returns both as one Result, and the caller
cannot take the value without facing the case:

```kelvin
#import <sys/stat.h> as C
#import <errno.h> as C
#import <string.h> as C
struct stat;                                 // the C struct, by its bare name
let statOf(path:cstr):Result<stat, int32> {    // the struct, or errno
    var buf:stat
    if lstat(path, &buf) != 0 { return err(errno) }
    return buf                               // a T becomes ok(T)
}
let sizeOf(path:cstr):Result<int64, int32> {     // an err passed up
    let st = try statOf(path)                // the struct, or return the err
    return st.st_size
}
if let st = statOf("/") { println((st.st_mode & S_IFMT) == S_IFDIR) }   // true
var s = sizeOf("/no/such")
if s.is(err) { println(strerror(s.err)) }    // No such file or directory
```

- **The error type** is what C gives: `i32` for `errno` and for a
  function's own code, a `String` when the reason is text,
  `` err($`not a number: ${s}`) ``, an enum of your own when the callers
  switch on it.
- **A pointer that may be null** with a reason beside it, as `fopen`
  with `errno`, is a `Result<FILE^, i32>`; one with no reason, as
  `getenv`, is a `cstr?` (see [optionals.md](optionals.md)).
  - For files, `IO(path, mode)` gives the IO straight instead, with the
    reason in `f.error`, passed up as `err(f.error)` (#109,
    [io.md](io.md)).
- **A number read from text** is `i64(s)`, which reads as `strtol`
  does and sets `errno` to `ERANGE` past the limits; check the digits
  first, and the Result's `err` says which.
- **A `?:`** takes the same wrapping in each arm (#116): `return
  s.count > 0 ? i64(s) : err("empty")`, or `c ? ok(v) : err(e)`.
- **Passing an err up** is `try f()` (#76): the value, or `return
  err(e)` written for you. By hand, it is `if r.is(err) { return
  err(r.err) }`, then `r.ok`.
- **A default for a `cstr?`** is written as it reads, `v ?? "unset"`.
  - kelvinc casts a string literal, or text of another spelling, to the
    value's type, since C's `?:` of a `const uint8_t *` and a `char *`
    is no text (clang made it an address, gcc refused; found by the
    example, fixed since).
- **`lstat` is POSIX**, and glibc hides it under `-std=c11`, which
  kelvinc uses, unless a feature macro is defined: kelvinc defines
  `_XOPEN_SOURCE 700` and `_DEFAULT_SOURCE` in the C it writes (#176),
  as its runtime does for itself, so the C headers a program imports
  show their POSIX functions on every platform.
  - [examples/results.k](../examples/results.k) does the same with ISO
    C's `timespec_get`, `fopen` and `getenv`, and runs with the tests.

## `T?`: the special case

`Optional<T>`, or `T?` for short, is a Result whose `err` carries
nothing: the cases are `none`, with no value, and `some: T`.

Everything above holds with `some` for `ok` and `none` for `err`:

- a `T` where a `T?` is expected becomes `some(T)`, and `none` is a
  word there;
- `x.some` is checked;
- `x ?? y`, `if let v = x`, `switch x { case some: ... case none: ... }`;
- `try x` passes `none` up;
- `Optional<T>.some(v)` and `Optional<T>.none` spell the cases out.

One maker builds both in kelvinc, so a change to one is a change to the
other. The details, and the examples, are in
[optionals.md](optionals.md).

```kelvin
var xs = $[5, 6, 7]
let find(xs:$[int64]^, v:int64):int64? {       // a result that may be absent
    for i in 0..<xs^.count { if xs^[i] == v { return i } }
    return none
}
if let k = find(&xs, 6) { println(k) } else { println("absent") }
```

## Properties and methods

| On | Property or method | Gives |
|---|---|---|
| `Result<T, U>` | `.ok`, `.err` | the values, checked; places |
| | `if let v = r { } else { }` | runs with `v` the `ok` value, when that is the case |
| | `try r` | the `ok` value, or returns the `err` from the function (#76) |
| | `if let err(e) = r { }`, `if let ok(v) = r { }` | runs with the case's value, when that is the case (#78) |
| | `.ok = v`, `.err = e`, `= v`, `= ok(v)`, `= err(e)` | sets the case |
| | `.is(ok)`, `.is(err)` | a `bool` |
| | `.case` | the tag, a `u8`: 0 for ok, 1 for err |
| | `r ?? y` | the `ok` value, or `y` |
| | `switch r { case ok: ... case err: ... }` | by the case |
| | `switch r { case ok(v): ... case err(e): ... }` | the same, with the value bound in each body (#119) |
| | `.cstr` | `ok(42)`, `err("empty")`: text inside is quoted (#123) |
| | `==`, `!=` | the same case and equal values; `r == 42`, `r == err(2)` (#79) |
| | `.map(f)`, `.map { ... }`, `.mapErr(g)` | a `Result<U, E>` of `f`'s result, or a `Result<T, F>` of `g`'s (#80) |
| | `.flatMap(f)` | `f`'s own `Result<U, E>`, or the `err` carried over (#81) |
| | `.copy()` | a copy, when the value owns |
| | `.size`, `.typename` | `sizeof`; `Result<i64, String>` |
| `T?` | `.some`, `.is(none)`, `= none`, and the rest | as a Result's, with `some` for `ok` and `none` for `err`: see [optionals.md](optionals.md#properties-and-methods) |

The general properties are in [properties.md](properties.md), the
ownership rules in [ownership.md](ownership.md).
