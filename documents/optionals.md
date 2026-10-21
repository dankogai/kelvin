# Optionals: `T?`

`Optional<T>`, or `T?` for short, is a value that may be absent (#72).
It is the special case of `Result<T, U>` (#75, see
[results.md](results.md)) whose `err` carries nothing: an enum with
values (see [enums.md](enums.md)) with the cases `none` and `some: T`,
made for each `T` as it is written.

It holds a `T` of any value type, owners included, and then owns it.
Everything a Result does, an Optional does with `some` for `ok` and
`none` for `err`; this document has the Optional's own spelling and
examples.

**Where it lives:** the prelude's rules, kelvinc's C. Each `T?` is a struct kelvinc writes, as an enum with values is, and a wrong case ends the program through the prelude's `kv_case_fail`, in `libkelvin`, linked without an import.

<!-- fragment -->
```swift
var a:int64? = 3                           // some(3): a T becomes a T? where one is expected
var b:int64? = none                        // none, a word that needs the type around it
println(a.is(some), " ", b.is(none))     // true true
println(a.some, " ", a!)                // 3 3; of none, the program ends with a message (#218)
println(a ?? 0, " ", b ?? -1)            // the value, or the default: 3 -1
var s:String? = $"kelvin"
println(s?.count, " ", s?.count ?? 0)    // some(6) 6: x?.m chains, none of none (#218)
println(a == 3, " ", b == none, " ", a != b)   // true true true (#79)
var d = a.map { $0 > 2 }                 // some(true), a bool? (#80)
var h = a.flatMap(half)                  // half's own i64?: none of an odd number (#81)
a = none                                 // sets the case
b = 9                                    // some(9)
b.some += 1                              // a place, checked
switch a {                               // exhaustive, as an enum's
case some: println(a.some)
case none: println("absent")
}
if let v = a { println(v) } else { println("absent") }   // binds the value when present (#74)
let find(xs:$[int64]^, v:int64):int64? {       // a result that may be absent
    for i in 0..<xs^.count { if xs^[i] == v { return i } }
    return none
}
var p:point? = {1, 2}                    // the T's initializer, wrapped; so is return {1, 2} (#77)
var r = Optional<int64>(4)                 // explicit: some(4); Optional<i64>() is none
var s = Optional<int64>.some(4)            // the cases by the type's name; Optional<i64>.none
```

- **The type** is `T?`, or `Optional<T>`, for any value type: `i64?`,
  `String?`, `point?`, `$[i64]?`, `i64^?`, `i64??`.
  - An array is no value, so `[i64](3)?` is an error (hold an Array).
  - `x as T?` is not written, since `?` would read as a condition
    there: write `Optional<T>`.
- **Making one:** a `T` where a `T?` is expected becomes `some(T)` by
  itself, in a declaration, an assignment, a member, an element, an
  entry, a `return`, or an argument of a function or a method (#222).
  - `none` there is the absent value, a word that needs the type around
    it (`var x = none` has no type).
  - The arms of a `?:` take this too (#116): `return c ? v : none`,
    `var x:i64? = c ? n : none`, and `c ? Optional<i64>(n) : none`,
    where the other arm gives the type.
  - An owner moves in, as a case's value does.
  - `Optional<T>(v)`, `Optional<T>()`, `Optional<T>.some(v)` and
    `Optional<T>.none` spell both out.
- **Reading:** `x.some` is the value, checked at run time: of `none`,
  the program ends with `case 'some' of i64? is not current: it is
  'none'`.
  - It is a place: `x.some += 1`, `x.some += "!"`.
  - **`x!`** (#218) is the same, postfix: `a!`, `d[k]!`, `f()!.name`.
    - It follows `x` with nothing between, as `x?.` does; `x != y` is
      the comparison.
- **Chaining:** **`x?.m`**, `x?.f(...)` and `x?[i]` (#218) are what
  follows, of `x`'s value, as an Optional, and `none` where `x` is
  `none`, Swift's way: `s?.count` is an `i64?`.
  - The rest of the postfix chain is inside: `p?.name.count` is the
    count of the name, or `none`.
  - What follows that is an Optional already is not wrapped again.
  - A member that owns is copied out of the value; `x` is read once.
  - `try x` is the other way, which returns `none` from the function.
  - `x ?? y` is the value if some, else `y`.
    - It groups right to left (#251): `a ?? b ?? 0` is `a ?? (b ??
      0)`, the first value of the chain, or 0.
    - `y` is of the value's type: `a ?? b` of two `i64?` is an error,
      `'??' of i64? falls back to an i64, and this is i64?`.
    - For a `T` that does not own, `x` is an Optional in a variable, a
      member or an element, or one an expression gives, held.
    - For a `T` that owns (#250), `s ?? $"none"`, `x` is read once.
      - Its value is a copy where `x` is a place, a variable, a member
        or an element; else it is taken out of `x`, as of `d[k]` or a
        call.
      - `y` is a copy where it is a place, else taken, and is made
        only where `x` has no value.
      - What `??` gives is an owner an expression gives: bound,
        `let s = o ?? fb`, or freed after the statement.
      - `y` of another type is an error, `'??' of String? falls back
        to a String, and this is a number`.
  - Of a `cstr?`, `u8^?` or `i8^?`, a `y` that is a string literal, or
    text of another spelling, is cast to the value's type, as a
    declaration would cast it.
- **Testing:** `x.is(some)`, `x.is(none)`, `x.case` (0 for none, 1 for
  some), `switch x { case some: ... case none: ... }`, exhaustive.
  - `case some(v):` binds the value for its body (#119).
  - Of an Optional that owns, `.is` and `.case` take a place: bind the
    value first, or `if let` on the call (#99).
- **`if let v = x { ... } else { ... }`** (#74) runs the block with `v`
  bound to the value when there is one: a let the Optional still owns,
  as a loop's element is (borrow it, or copy it).
  - `x` may be a variable or a value a call gives, read once;
    `else if let` chains.
  - `if let some(v) = x` spells the case out (#78); `none` carries
    nothing to bind, so test it with `.is(none)`.
- **`try x`** (#76) is the value when there is one, and otherwise
  returns `none` from the function, which must return an Optional:
  `let i = try find(&xs, v)`; see [results.md](results.md).
- **`==` and `!=`** (#79): `a == b` is true of two `none`, or of two
  values that are equal, a String's by its bytes; `x == none` and
  `x == 3` wrap the other side, as where a `T?` is expected.
  - A value whose type has no `==`, a struct, has none here either;
    an Array's or a Dictionary's compares its elements (#247).
  - An owner made on the spot (`x == $"hi"`) is held for the
    comparison and freed after (#187). See [results.md](results.md).
- **`x.map(f)`** (#80) is a `U?`: `some(f(v))` when `x` is `some(v)`;
  an Array has one too, `xs.map(f)` (#182), and both infer the result
  of `{ $0 * 2 }` from arithmetic of one number type,
  else `none`.
  - `f` takes the `T` and gives a `U`, a function by name, a function
    value, or an anonymous function, `x.map { $0 > 2 }` or
    `x.map { (v:i64):f64 in v / 2.0 }`, whose result kelvinc sees or
    which writes it.
  - **`x.flatMap(f)`** (#81) takes an `f` that gives a `U?` itself, and
    is that when `x` is `some(v)`, else `none`: `a.flatMap(half)`,
    where `half` gives `none` of an odd number.
  - Of a variable that owns, map the call itself, or `x.copy()`. See
    [results.md](results.md).
- **Text:** `x.cstr` is `some(3)` or `none`; `${x}` the same; text
  inside is quoted, `some("x")`, and `print(x)` and `x.pretty` show a
  value with brackets whole (#123, #124).
- **In C**, each `T?` is a struct `_kv_opt_<T>` of a byte tag and the
  value, with the functions of an enum with values, as a Result's
  `_kv_res_<T>_<U>` is.
- **An Optional where a value goes,** `let n:i64 = x` or `return x`
  of an `i64` function, is an error that names `!` and `??` (#218).
- **`some(v)` is a pattern alone,** as in `if let some(v) = x` and
  `case some(v):`.
  - Written as a value it is an error that says to give `v` itself,
    which becomes `some(v)` where a `T?` goes, or `Optional<T>(v)`
    (#224); so is `some(v)` where a Result goes.
  - A function or a variable of the program named `some` is called as
    any other.
- **Not yet:** a literal `none` where no type is around.

A C function that returns a pointer or null, with no reason beside it,
wraps as an Optional. `v ?? "unset"` takes a string literal as it is:
kelvinc casts it to the value's type, since C's `?:` of two kinds of
text is no text (see
[results.md](results.md#from-c-the-value-through-a-pointer-the-error-beside-it)):

```swift
let env(name:cstr):cstr? {                // char *getenv(const char *)
    let v:cstr := getenv(name)
    if v.isNull { return none }
    return v
}
var home = env("HOME")
println(home ?? "unset")
```

When the absence has a reason, return a `Result<T, U>` instead, with
the reason in `err`: [results.md](results.md).

## Properties and methods

| On | Property or method | Gives |
|---|---|---|
| `T?` | `.some` | the value, checked; a place |
| | `x!` | the same, postfix (#218) |
| | `x?.m`, `x?.f(...)`, `x?[i]` | what follows, of the value, an Optional; `none` of `none` (#218) |
| | `if let v = x { }`, `if let some(v) = x { }` | runs with `v` the value, when present |
| | `try x` | the value, or returns `none` from the function (#76) |
| | `.some = v`, `= v`, `= none` | sets the case |
| | `.is(some)`, `.is(none)` | a `bool` |
| | `.case` | the tag, a `u8`: 0 for none, 1 for some |
| | `x ?? y` | the value, or `y` |
| | `c ? v : none` | each arm wrapped where a `T?` is expected, or beside an arm that is one (#116) |
| | `switch x { case some: ... case none: ... }` | by the case |
| | `switch x { case some(v): ... }` | the same, with `v` the value in that body (#119) |
| | `.cstr` | `some(3)`, `none` |
| | `==`, `!=` | both `none`, or equal values; `x == none`, `x == 3` (#79) |
| | `.map(f)`, `.map { ... }` | a `U?` of `f`'s result, or `none` (#80) |
| | `.flatMap(f)` | `f`'s own `U?`, or `none` (#81) |
| | `.copy()` | a copy, when the value owns |
| | `.size`, `.typename` | `sizeof`; `i64?` |

A `Result<T, U>`'s are in [results.md](results.md#properties-and-methods).
