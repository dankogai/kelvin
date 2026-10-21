# Enums, and enums with values

An `enum` with bare names is C's: a set of integer constants, a type by
its bare name (#29). An `enum` whose cases carry values is a union that
knows its case (#61): Swift's enum with associated values, a tagged
union in C, with one byte for the tag.

**Where it lives:** the core. A plain enum is C's, with nothing linked. An enum with values is kelvinc's own C, a struct of a tag and a union with its functions, and a wrong case ends the program through the prelude's `kv_case_fail`, in `libkelvin`, linked without an import.

```swift
enum color { red, green, blue }          // C's enum: red is 0

enum json { null; b: bool; n: float64; s: String; a: Array<json> }

var j:json = {.n = 1.5}                  // a case by its name
j.s = String("text")                     // sets the case; what it held is freed
var k = json.a(Array([json.n(1.0), json.null]))   // T.case(value), T.case
println(j.cstr, " ", k.a.count, " ", j.is(s), " ", j.case)   // s("text") 2 true 3: text inside is quoted (#123)
switch k.a[0] {
case n: println(k.a[0].n)                // a case by its bare name; ends at the next (#63)
case s: println(k.a[0].s)
default: println("another")
}
println(j.n)                             // ends the program: case 'n' of json is not current: it is 's'
```

## C's enum

- **`enum color { red, green, blue }`**, with `= value` as C has it, is
  C's enum: `color` is a type, `red` an integer constant, and `c.cstr`
  its number.
- **An anonymous `enum { a, b }`** at the top level is a group of int
  constants, as in C. A `switch` on a Kelvin enum lists every
  enumerator, or has `default:` (#63).

## An enum with values: `enum T { none; some: i32 }`

- **Declaring:** a case is a name, with a value's type after `:` or
  none.
  - Cases are separated by `,`, `;` or a line break, up to 255 of them,
    since the tag is a byte.
  - A case has a name, not a number.
  - Without a tag, `enum{i:i32, f:f32}` goes where a type goes, one
    type per spelling, as `{x:f64, y:f64}` does (#59).
  - At the top level, `enum { red; rgb: {r: u8, g: u8, b: u8} }` with no
    tag (#120) is that type, and its cases are words of the program, as
    C's anonymous enum declares its enumerators: `red` is a value,
    `rgb({1, 2, 3})` makes one, and `var c = rgb({1, 2, 3})` infers the
    type, spelled `enum{red, rgb: {r: u8, g: u8, b: u8}}`.
    - A case named `ok`, `err`, `none` or `some`, or like a function or
      an enumerator, is an error that says so: those are words already.
    - The same spelling declared again gives the same type and words.
- **Making a value:** `{.n = 1.5}` or `{.none}` as an initializer, a
  `return` (#77) or a compound literal, `(json){.n = 1.5}`.
  - `json.n(1.5)` and `json.none` as an expression, with the value
    given by value, so an owner moves in (O5).
  - A case of a struct or array type takes its list,
    `shape.rect({3.0, 4.0})`.
  - A variable declared without a value is at the first case, zeroed.
- **Setting:** `v.n = 1.5` sets the case and its value, freeing what
  the value held if it owns.
  - `v.rect = {3.0, 4.0}` takes a list.
  - `=` does not copy an owner into a case, as it copies none (#54):
    `v.s = t.copy()`, or move with `json.s(t)`.
- **Reading:** `v.n` is the value of case `n`, checked at run time: if
  another case is current, the program ends with a message naming both.
  - It is a place: `v.rect.w += 1.0` and `v.s += "x"` change it.
  - A case with no value cannot be read.
- **Indexing** (#117): `v[k]` of an enum with values goes through its
  case that is a Dictionary when `k` is text, and its Array case when
  `k` is an integer.
  - `j["key"]` is `j.object["key"]` and `j[0]` is `j.array[0]`: a
    place, checked as the case and the index are.
  - An enum with no such case says so.
  - An enum with a subscript of its own, `let T[](i:I):R { ... }`
    (#136), is indexed through it instead; see
    [properties.md](properties.md#attributes-of-your-own-and-extend).
- **Testing:** `v.is(n)` is a bool; `v.case` is the tag, a `u8`, the
  case's index from 0.
  - `switch v { case n: ... case none: ... }` branches on the case by
    its bare name, each case ending at the next, and lists every case
    or has `default:` (#63, [flow-controls.md](flow-controls.md)).
- **Text:** `v.cstr` and `${v}` are the case's name and its value in
  parentheses, `n(1.5)`, `rect({w: 3.0, h: 4.0})`, or the name alone,
  `none`; `T.cstr()` (#53) replaces it.
- **Owners:** a case that owns makes the enum an owner under the rules
  of #54: freed by its block, moved by `return` and by passing, copied by
  `.copy()`, borrowed as a pointer, and an element of an `Array<T>`,
  which may be a case of the enum itself, as `json` above.
- **`.size`** is C's, `.typename` the name or the spelling.
- **`==` and `!=`** (#79) compare two of one type: the same case, and
  equal values, where every case's value has a `==` of its own (a
  number, a pointer, a `uchr`, a String, a Bytes, another enum with
  values).
  - One with a struct or an Array in a case has none, so define an
    operator, or compare `.case` and the cases.
  - `j == json.n(1.5)` makes the case on the spot; one that would own,
    `json.s($"x")`, is not taken, since nothing would free it: bind it
    to a variable.
- **In C**, `enum json` is `struct json { uint8_t tag; union { ... } u; }`
  with its cases' names.
  - Per case, `_kv_json_at_n` (checked, a pointer), `_kv_json_get_n`
    (checked, a value), `_kv_json_set_n` and `_kv_json_make_n`; a case
    with no value has `set` and `make` alone.
- **`Result<T, U>`** is one of these with the cases `ok: T` and
  `err: U`, made for each pair of types, and **`T?`**, an Optional, its
  special case with `none` and `some: T`: see [results.md](results.md)
  (#75) and [optionals.md](optionals.md) (#72).
- **`if let n(x) = j { ... } else { ... }`** (#78) runs the block with
  `x` bound to the case's value when that is `j`'s case: a let `j`
  still owns, as a loop's element is.
  - `j` may be a variable or a value a call gives, read once;
    `else if let` chains.
  - A case with no value has nothing to bind: test it with `.is(none)`.
  - This is how a Result's `if let err(e) = r` works; see
    [results.md](results.md).
- **`switch v { case n(x): ... }`** (#119) binds `x` to the case's value
  for that case's body, as `if let n(x) = v` does: a let `v` still owns.
  - A case that binds stands alone, and a case with no value binds
    nothing; see [flow-controls.md](flow-controls.md).
- **Methods and operators** (#121): an enum with values takes methods,
  `let maybe.orZero():i64 { ... }`, and operators,
  `let +(a:maybe, b:maybe):maybe { ... }`, as a struct does.
  - One with no tag names its receiver by its spelling:
    `let enum{nothing, just: i64}.orZero():i64 { ... }`, and an operator
    takes it by its spelling too.
  - `==` and `!=` are its own (#79) until the program writes them for
    it; any other operator is the program's, and an error that shows
    how to define one where none is written.
  - `x += y`, `x -= y` and the rest are `x = x + y` by that operator
    (#128), also for an enum that owns.
  - A function of the type, `static let T.name()`, needs a name to be
    called by, so one with no tag has none.
- **Not yet:** printing one with `print` or `println` by itself: show
  `v.cstr`, or use a template.

## A struct that owns

A struct, or an enum with values, that holds an owner is copied with
`.copy()` (#61), member by member, and may now be an element of an
`Array<T>`, which copies and frees its elements with it.

## Properties and methods

| On | Property or method | Gives |
|---|---|---|
| C's enum, an enumerator | `.cstr`, `.dec`, `.hex`, ... | as an integer's |
| | `.size`, `.typename` | as C's |
| an enum with values | `.case` | the tag, a `u8`, the case's index from 0 |
| | `.is(n)` | whether `n` is the current case, a `bool` |
| | `.n` | the value of case `n`, checked: another case ends the program |
| | `.n = x` | sets the case and its value, freeing what it held |
| | `v["key"]`, `v[i]` | the Dictionary case's entry, the Array case's element, checked (#117) |
| | `T.n(x)`, `T.none` | a value, by the type's name |
| | `n(x)`, `none` | the same of a top-level enum with no tag, whose cases are words (#120) |
| | `switch v { case n: ... }` | by the case, exhaustive (#63) |
| | `switch v { case n(x): ... }` | the same, with `x` the case's value in that body (#119) |
| | `.cstr` | `n(1.5)`, `none`, or `T.cstr()`'s text |
| | `.copy()` | a copy, when a case owns |
| | `let T.name()`, `let enum{...}.name()`, `let +(a:T, b:T)` | methods and operators, by the name or the spelling (#121) |
| | `.size`, `.typename` | `sizeof`; the name or spelling |
