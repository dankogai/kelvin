# JSON: `#import <JSON>`

`JSON` (#113) is a JSON value as an enum with values (see
[enums.md](enums.md)): a tagged union of a `null`, a `boolean`, a
`number`, a `string`, an `array` of JSON or an `object` of String to
JSON, and one more case, `error`, for a text that was not JSON.
`JSON.parse(text)` reads one from text and `JSON.stringify(&j, replacer,
space)` writes it back, as JS's do.

**Where it lives:** `modules/JSON.k`, brought in by `#import <JSON>` (#112), written in Kelvin: an enum with values, functions of the type (#111) and C's `snprintf` for the numbers. Nothing of it is in the prelude or the runtime.

```kelvin
#import <JSON>

var j = JSON.parse("{\"name\": \"kelvin\", \"tags\": [\"c\", 11], \"ok\": true}")
if j.is(error) { println(j.error) }           // "a key in an object: unexpected end of text at 1"
println(j.object["name"].string, " ", j.object["tags"].array[1].number, " ", j.object["ok"].boolean)
j.object["tags"].array += JSON.number(12.0)   // grown, as any Array
j.object["new"] = JSON.string($"added")       // a member added, or replaced
var flat = JSON.stringify(&j)                 // {"name":"kelvin","tags":["c",11,12],"ok":true,"new":"added"}
var pretty = JSON.stringify(&j, "  ")         // one member or element a line, two spaces a level
var v = JSON.array($[JSON.number(1.0), JSON.null, JSON.boolean(false)])   // made by hand, by the cases
var text = $"[1, 2, 3]"
var a = JSON.parse(&text)                     // a String, borrowed
```

- **The type** is `enum JSON { null; boolean: bool; number: f64; string:
  String; array: Array<JSON>; object: Dictionary<String, JSON>; error:
  String }`: a value is one case, read as `j.number`, `j.string`,
  `j.array[i]`, `j.object["key"]`, checked, and asked with `j.is(array)`
  or a `switch`; the case is `boolean`, since `bool` is a type's name.
  An object keeps its members in the order they were added, as a
  Dictionary does, and a key that comes twice keeps the last value, as
  JS does. A number is an `f64`, as JS's is. A JSON owns what it
  holds, and is copied with `.copy()`, freed by its block, moved by
  `return` and by passing; see [enums.md](enums.md).
- **`null`** is the case `null`, carrying nothing: `JSON.null`,
  `j.is(null)`. It is not `nullptr`, which is a pointer.
- **`JSON.parse(text)`** takes a `cstr`, or a `String` borrowed, `&s`,
  and gives a `JSON` straight. A text that is not JSON gives the case
  `error`, with a `String` that says what was expected and the byte
  offset: `error("',' or ']' in an array: unexpected '1' at 2")`; so
  does a string that is not UTF-8, a lone surrogate in a `\u` escape, a
  control character in a string, and nesting deeper than 512 levels.
  `\uXXXX` escapes and surrogate pairs become the codepoint; the text
  around a value may have JSON's whitespace, and nothing else.
- **`JSON.stringify(&j)`** gives the text as a `String`, compact:
  `{"a":[1,2]}`. **`JSON.stringify(&j, space)`** indents, as JS's does:
  `space` is text, a `cstr` or a borrowed `String`, written once per
  level after a newline, at most 10 characters, `""` for compact text.
  **`JSON.stringify(&j, replacer)`** and **`JSON.stringify(&j, replacer,
  space)`** call `replacer`, a function `(key:cstr, value:const
  JSON^):JSON?`, for the root with the key `""`, for each member with
  its key, and for each element with its index as text, and write what
  it gives: `none` leaves a member out, writes `null` for an element,
  and gives no text at all for the root, as JS's `undefined` does. The
  value is given to the replacer as a borrow, so it gives a new one,
  `v^.copy()` for the value as it is.
- **Numbers** are written as JS writes them: the shortest text that
  reads back as the same `f64`, `3` for a whole number, `1e+21` and
  `1e-7` past the limits JS uses for exponents, and `null` for NaN and
  the infinities. **Strings** escape `"`, `\`, the control characters as
  `\n`, `\t`, `\r`, `\b`, `\f` or `\u00XX`, and write every other
  codepoint as itself. An `error` is written as its message, a string.
- **Not yet:** `j["key"]` and `j[i]` straight on a JSON, a `switch` that
  binds the case's value, numbers past an `f64`, and comments or
  trailing commas, which are not JSON.

## Functions

```kelvin
JSON.parse(text: cstr): JSON                       // a value, or error(message)
JSON.parse(text: const String^): JSON              // the same of a String, borrowed
JSON.stringify(j: const JSON^): String                              // compact
JSON.stringify(j: const JSON^, space: cstr): String                 // indented by space, at most 10 characters
JSON.stringify(j: const JSON^, space: const String^): String
JSON.stringify(j: const JSON^, replacer: (cstr, const JSON^): JSON?): String
JSON.stringify(j: const JSON^, replacer: (cstr, const JSON^): JSON?, space: cstr): String
JSON.stringify(j: const JSON^, replacer: (cstr, const JSON^): JSON?, space: const String^): String
```

## Properties and methods

| On | Property or method | Gives |
|---|---|---|
| `JSON` | `.null`, `.boolean`, `.number`, `.string`, `.array`, `.object`, `.error` | the case's value, checked; `JSON.null`, `JSON.number(1.5)`, ... make one |
| | `.is(array)`, `.case`, `switch j { case array: ... }` | which case it is |
| | `.copy()` | a copy, deep |
| | `.cstr`, `${j}` | the case and its value, `number(1.5)`, as any enum's; `JSON.stringify(&j)` for JSON text |
| | `==`, `!=` | none: an Array in a case has no `==`; compare the text |
| | `.size`, `.typename` | `sizeof`; `JSON` |
