# JSON: `#import <JSON>`

`JSON` (#113) is a JSON value as an enum with values (see
[enums.md](enums.md)): a tagged union of a `null`, a `boolean`, a
`number`, a `string`, an `array` of JSON or an `object` of String to
JSON, and one more case, `error`, for a text that was not JSON.
`JSON.parse(text)` reads one from text and `JSON.stringify(&j, replacer,
space)` writes it back, as JS's do.

**Where it lives:** `modules/JSON.k`, brought in by `#import <JSON>` (#112), written in Kelvin: an enum with values, functions of the type (#111) in two `extend JSON { }` blocks (#130), the parsing and the writing, with `Self` for `JSON` (#140), and C's `snprintf` for the numbers. Nothing of it is in the prelude or the runtime. It is the example of a module written in Kelvin, and `kelvinc --lib modules/JSON.k` builds it into `JSON.kh` and `libkJSON.a` where a project wants that (#146).

```swift
#import <JSON>

var j = JSON.parse("""
    {"name": "kelvin", "tags": ["c", 11], "ok": true}
    """)                                      // """: the text as written (grammar.md)
if j.is(error) { println(j.error) }           // "a key in an object: unexpected end of text at 1"
println(j["name"].string, " ", j["tags"][1].number, " ", j["ok"].boolean)   // j["key"], j[i]: through the cases (#117)
j["tags"].array += JSON.number(12.0)          // grown, as any Array
j["new"] = JSON.string($"added")              // a member added, or replaced
var flat = JSON.stringify(&j)                 // {"name":"kelvin","tags":["c",11,12],"ok":true,"new":"added"}
var pretty = JSON.stringify(&j, "  ")         // one member or element a line, two spaces a level
var four = JSON.stringify(&j, 4)              // a number as the space: four spaces a level (#129)
var v = JSON.array($[JSON.number(1.0), JSON.null, JSON.boolean(false)])   // made by hand, by the cases
var text = $"[1, 2, 3]"
var a = JSON.parse(&text)                     // a String, borrowed
```

- **The type** is `enum JSON { null; boolean: bool; number: f64; string:
  String; array: Array<JSON>; object: Dictionary<String, JSON>; error:
  String }`.
  - A value is one case, read as `j.number`, `j.string`, `j.array[i]`,
    `j.object["key"]`, checked, and asked with `j.is(array)` or a
    `switch`; the case is `boolean`, since `bool` is a type's name.
  - An object keeps its members in the order they were added, as a
    Dictionary does, and a key that comes twice keeps the last value,
    as JS does.
  - A number is an `f64`, as JS's is.
  - A JSON owns what it holds, and is copied with `.copy()`, freed by
    its block, moved by `return` and by passing; see
    [enums.md](enums.md).
- **`null`** is the case `null`, carrying nothing: `JSON.null`,
  `j.is(null)`. It is not `nullptr`, which is a pointer.
- **`JSON.parse(text)`** takes a `cstr`, or a `String` borrowed, `&s`,
  and gives a `JSON` straight.
  - A text that is not JSON gives the case `error`, with a `String`
    that says what was expected and the byte offset:
    `error("',' or ']' in an array: unexpected '1' at 2")`.
  - So does a string that is not UTF-8, a lone surrogate in a `\u`
    escape, a control character in a string, and nesting deeper than
    512 levels.
  - `\uXXXX` escapes and surrogate pairs become the codepoint; the text
    around a value may have JSON's whitespace, and nothing else.
- **`JSON.stringify(&j)`** gives the text as a `String`, compact:
  `{"a":[1,2]}`.
  - **`JSON.stringify(&j, space)`** indents, as JS's does: `space` is
    text, a `cstr` or a borrowed `String`, written once per level after
    a newline, at most 10 characters, `""` for compact text.
    - Or a number (#129), that many spaces a level, from 0 to 10 as JS
      clamps it and as `v.pretty(n)` indents: `JSON.stringify(&j, 4)`;
      `0` is compact.
  - **`JSON.stringify(&j, replacer)`** and **`JSON.stringify(&j,
    replacer, space)`** call `replacer`, a function `(key:cstr,
    value:const JSON^):JSON?`, for the root with the key `""`, for each
    member with its key, and for each element with its index as text,
    and write what it gives.
    - `none` leaves a member out, writes `null` for an element, and
      gives no text at all for the root, as JS's `undefined` does.
    - The value is given to the replacer as a borrow, so it gives a new
      one, `v^.copy()` for the value as it is; an anonymous one is
      written `{ (key:cstr, v:const JSON^):JSON? in ... }` (#114).
  - JSON text in a program is quoted as it is with `"""..."""`, as any
    text is ([grammar.md](grammar.md#quoting-text)).
- **Numbers** are written as JS writes them: the shortest text that
  reads back as the same `f64`, `3` for a whole number, `1e+21` and
  `1e-7` past the limits JS uses for exponents, and `null` for NaN and
  the infinities.
- **Strings** escape `"`, `\`, the control characters as `\n`, `\t`,
  `\r`, `\b`, `\f` or `\u00XX`, and write every other codepoint as
  itself.
  - An `error` is written as its message, a string.
- **`j["key"]` and `j[i]`** (#117) index a JSON straight: text goes
  through the `object` case and an integer through the `array` case.
  - `j["tags"][1].number` reads a path, `j["n"] = JSON.number(4.0)`
    sets or adds a member and `j["tags"][0] = ...` an element, each
    checked as the case and the index are.
  - A JSON that is no object ends the program as `j.object` would, and
    so does a missing key or an index out of range.
  - `j["tags"].array += x` grows one, `j[1..<3]` slices the array.
  - This is the rule of [enums.md](enums.md) for any enum with values
    that holds a Dictionary or an Array.
- **Not yet:** numbers past an `f64`, and comments or trailing commas,
  which are not JSON.

## Functions

<!-- fragment -->
```swift
JSON.parse(text: cstr): JSON                       // a value, or error(message)
JSON.parse(text: const String^): JSON              // the same of a String, borrowed
JSON.stringify(j: const JSON^): String                              // compact
JSON.stringify(j: const JSON^, space: cstr): String                 // indented by space, at most 10 characters
JSON.stringify(j: const JSON^, space: const String^): String
JSON.stringify(j: const JSON^, space: int64): String                  // that many spaces a level, 0 to 10 (#129)
JSON.stringify(j: const JSON^, replacer: (cstr, const JSON^): JSON?): String
JSON.stringify(j: const JSON^, replacer: (cstr, const JSON^): JSON?, space: cstr): String
JSON.stringify(j: const JSON^, replacer: (cstr, const JSON^): JSON?, space: const String^): String
JSON.stringify(j: const JSON^, replacer: (cstr, const JSON^): JSON?, space: int64): String
```

## Properties and methods

| On | Property or method | Gives |
|---|---|---|
| `JSON` | `.null`, `.boolean`, `.number`, `.string`, `.array`, `.object`, `.error` | the case's value, checked; `JSON.null`, `JSON.number(1.5)`, ... make one |
| | `j["key"]`, `j[i]` | the member, the element, through the object or the array case, checked; a place (#117) |
| | `.is(array)`, `.case`, `switch j { case array: ... }` | which case it is; `case array(xs):` binds the value (#119) |
| | `.copy()` | a copy, deep |
| | `.cstr`, `${j}` | the case and its value, `number(1.5)`, as any enum's; `JSON.stringify(&j)` for JSON text |
| | `println(j)`, `j.pretty` | the whole tree as Kelvin's text, `object({"k": number(1)})`, indented by `.pretty` (#123, #124) |
| | `==`, `!=` | none: an Array in a case has no `==`; compare the text |
| | `.size`, `.typename` | `sizeof`; `JSON` |
