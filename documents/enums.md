# Enums, and enums with values

An `enum` with bare names is C's: a set of integer constants, a type by
its bare name (#29). An `enum` whose cases carry values is a union that
knows its case (#61): Swift's enum with associated values, a tagged
union in C, with one byte for the tag.

```kelvin
enum color { red, green, blue }          // C's enum: red is 0

enum json { null; b: bool; n: f64; s: String; a: Array<json> }

var j:json = {.n = 1.5}                  // a case by its name
j.s = String("text")                     // sets the case; what it held is freed
var k = json.a(Array([json.n(1.0), json.null]))   // T.case(value), T.case
println(j.cstr, " ", k.a.count, " ", j.is(s), " ", j.case)   // s(text) 2 true 3
switch (k.a[0]) {
case n: println(k.a[0].n)                // a case by its bare name
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
  constants, as in C.

## An enum with values: `enum T { none; some: i32 }`

- **Declaring:** a case is a name, with a value's type after `:` or
  none; cases are separated by `,`, `;` or a line break, up to 255 of
  them, since the tag is a byte. A case has a name, not a number.
  Without a tag, `enum{i:i32, f:f32}` goes where a type goes, one type
  per spelling, as `{x:f64, y:f64}` does (#59).
- **Making a value:** `{.n = 1.5}` or `{.none}` as an initializer or a
  compound literal, `(json){.n = 1.5}`; `json.n(1.5)` and `json.none`
  as an expression, with the value given by value, so an owner moves in
  (O5); a case of a struct or array type takes its list, `shape.rect({3.0,
  4.0})`. A variable declared without a value is at the first case, zeroed.
- **Setting:** `v.n = 1.5` sets the case and its value, freeing what the
  value held if it owns; `v.rect = {3.0, 4.0}` takes a list; `=` does
  not copy an owner into a case, as it copies none (#54): `v.s =
  t.copy()`, or move with `json.s(t)`.
- **Reading:** `v.n` is the value of case `n`, checked at run time: if
  another case is current, the program ends with a message naming both.
  It is a place: `v.rect.w += 1.0` and `v.s += "x"` change it. A case
  with no value cannot be read.
- **Testing:** `v.is(n)` is a bool; `v.case` is the tag, a `u8`, the
  case's index from 0; `switch (v) { case n: ... case none: ... }`
  branches on the case by its bare name, with C's `switch` otherwise
  (`break`, `default`).
- **Text:** `v.cstr` and `${v}` are the case's name and its value in
  parentheses, `n(1.5)`, `rect({w: 3, h: 4})`, or the name alone,
  `none`; `T.cstr()` (#53) replaces it.
- **Owners:** a case that owns makes the enum an owner under the rules
  of #54: freed by its block, moved by `return` and by passing, copied by
  `.copy()`, borrowed as a pointer, and an element of an `Array<T>`,
  which may be a case of the enum itself, as `json` above.
- **`.size`** is C's, `.typename` the name or the spelling; `==` is not
  defined: define an operator, or compare `.case` and the cases.
- **In C**, `enum json` is `struct json { uint8_t tag; union { ... } u; }`
  with its cases' names, and per case `_kv_json_at_n` (checked, a
  pointer), `_kv_json_get_n` (checked, a value), `_kv_json_set_n` and
  `_kv_json_make_n`; a case with no value has `set` and `make` alone.
- **Not yet:** binding a case's value in a `case` label (Swift's `case
  .n(let x)`), and an anonymous `enum` with values at the top level.

## A struct that owns

A struct, or an enum with values, that holds an owner is copied with
`.copy()` (#61), member by member, and may now be an element of an
`Array<T>`, which copies and frees its elements with it.
