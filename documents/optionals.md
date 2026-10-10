# Optionals and Results: `T?` and `Result<T, U>`

`Optional<T>`, or `T?` for short, is a value that may be absent (#72):
an enum with values (see [enums.md](enums.md)) with the cases `none`
and `some: T`, made for each `T` as it is written. It holds a `T` of
any value type, owners included, and then owns it. `Result<T, U>`
(#75) is the same with a reason for the absence: the cases `ok: T` and
`err: U`; an Optional is a Result whose `err` carries nothing.

```kelvin
var a:i64? = 3                           // some(3): a T becomes a T? where one is expected
var b:i64? = none                        // none, a word that needs the type around it
println(a.is(some), " ", b.is(none))     // true true
println(a.some)                          // 3; of none, the program ends with a message
println(a ?? 0, " ", b ?? -1)            // the value, or the default: 3 -1
a = none                                 // sets the case
b = 9                                    // some(9)
b.some += 1                              // a place, checked
switch a {                               // exhaustive, as an enum's
case some: println(a.some)
case none: println("absent")
}
if let v = a { println(v) } else { println("absent") }   // binds the value when present (#74)
let find(xs:$[i64]^, v:i64):i64? {       // a result that may be absent
    for i in 0..<xs^.count { if xs^[i] == v { return i } }
    return none
}
var p:point? = {1, 2}                    // the T's initializer, wrapped
var r = Optional<i64>(4)                 // explicit: some(4); Optional<i64>() is none
```

- **The type** is `T?`, or `Optional<T>`, for any value type: `i64?`,
  `String?`, `point?`, `$[i64]?`, `i64^?`, `i64??`. An array is no
  value, so `[i64](3)?` is an error (hold an Array). `x as T?` is not
  written, since `?` would read as a condition there: write
  `Optional<T>`.
- **Making one:** a `T` where a `T?` is expected becomes `some(T)` by
  itself, in a declaration, an assignment, a member, an element, an
  entry or a `return`; `none` there is the absent value, a word that
  needs the type around it (`var x = none` has no type). An owner moves
  in, as a case's value does. `Optional<T>(v)` and `Optional<T>()`
  spell both out.
- **Reading:** `x.some` is the value, checked at run time: of `none`,
  the program ends with `case 'some' of i64? is not current: it is
  'none'`. It is a place: `x.some += 1`, `x.some += "!"`. `x ?? y` is
  the value if some, else `y`, for a `T` that does not own, of an
  Optional in a variable, a member or an element; for an owner, switch
  on it.
- **Testing:** `x.is(some)`, `x.is(none)`, `x.case` (0 for none, 1 for
  some), `switch x { case some: ... case none: ... }`, exhaustive.
- **`if let v = x { ... } else { ... }`** (#74) runs the block with `v`
  bound to the value when there is one: a let the Optional still owns,
  as a loop's element is (borrow it, or copy it). `x` may be a variable
  or a value a call gives, read once; `else if let` chains.
- **Text:** `x.cstr` is `some(3)` or `none`; `${x}` the same.
- **In C**, each `T?` is a struct `_kv_opt_<T>` of a byte tag and the
  value, with the functions of an enum with values.
- **Not yet:** `x!`, `==` with `none`, a literal `none` where no type is
  around, and `??` of an owner.

## `Result<T, U>`

```kelvin
let parse(s:cstr):Result<i64, String> {
    if s.count == 0 { return err($"empty") }   // err(e), a word, as none is
    return i64(s)                              // a T becomes ok(T)
}
var r = parse("42")
println(r.is(ok), " ", r.ok, " ", r ?? -1)     // true 42 42
if let v = r { println(v) } else { println(r.err) }
switch r {
case ok: println(r.ok)
case err: println("failed: ", r.err)
}
var q:Result<point, i32> = {1, 2}             // the T's initializer, wrapped as ok
var e = Result<i64, String>.err($"explicit")  // the cases by the type's name
```

- **The type** is `Result<T, U>`, `T` and `U` any value types but an
  array or a function; `U` may own, as `T` may.
- **Making one:** a `T` where a `Result<T, U>` is expected becomes
  `ok(T)` by itself; `ok(v)` and `err(e)` are words there, as `none` is
  for an Optional, read where no function of that name is in sight;
  `Result<T, U>.ok(v)`, `Result<T, U>.err(e)` and `Result<T, U>(v)`
  spell them out, and `Optional<T>.some(v)` and `Optional<T>.none` do
  the same for an Optional.
- **Reading:** `r.ok` and `r.err` are the values, checked; `r ?? y` is
  the `ok` value or `y`; `if let v = r` binds the `ok` value; `switch r
  { case ok: ... case err: ... }` is exhaustive; `r.is(ok)`, `r.case`.
- **Text:** `ok(42)`, `err(empty)`.
- **Not yet:** `try` or `?` to pass an `err` up, `if let` of the error,
  mapping.

## Properties and methods

| On | Property or method | Gives |
|---|---|---|
| `T?` | `.some` | the value, checked; a place |
| | `if let v = x { }` | runs with `v` the value, when present |
| | `.some = v`, `= v`, `= none` | sets the case |
| | `.is(some)`, `.is(none)` | a `bool` |
| | `.case` | the tag, a `u8` |
| | `x ?? y` | the value, or `y` |
| | `switch x { case some: ... case none: ... }` | by the case |
| | `.cstr` | `some(3)`, `none` |
| | `.copy()` | a copy, when the value owns |
| | `.size`, `.typename` | `sizeof`; `i64?` |
| `Result<T, U>` | `.ok`, `.err` | the values, checked; places |
| | `.is(ok)`, `.is(err)`, `.case`, `r ?? y`, `if let v = r`, `switch r` | as an Optional's, on `ok` |
| | `.cstr` | `ok(42)`, `err(empty)` |
