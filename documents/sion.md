# SION: `#import <SION>`

`SION` (#152) is a SION value, Swift Interchangeable Object Notation,
as Dan Kogai's https://dankogai.github.io/SION/ has it: JSON with more.
It is an enum with values (see [enums.md](enums.md)): `nil`, a
`boolean`, an `integer` and a `number` (SION's Int and Double) apart, a
`string`, `data` (a binary blob), a `date` (seconds since 1970), an `ext`
(a MessagePack extension), an `array`, a `dictionary` keyed by any
value, and one more case, `error`, for a text that was not SION.
`SION.parse(text)` reads one from text and `SION.stringify(&s, space)`
writes it back; [msgpack.md](msgpack.md) packs one into MessagePack.

**Where it lives:** `modules/SION.k`, brought in by `#import <SION>` (#112), written in Kelvin: an enum with values, functions of the type (#111) in `extend SION { }` blocks (#130) with `Self` for `SION` (#140), and subscripts (#136) for `s["key"]` and `s[i]`. Nothing of it is in the prelude or the runtime; `kelvinc --lib modules/SION.k` builds it into a library where a project wants that (#146).

```kelvin
#import <SION>

var s = SION.parse("""
    [ "name": "kelvin", "tags": ["c", 11], "pi": 0x1.921fb54442d18p+1,   // a comment
      "data": .Data("a2VsdmluCg=="), "when": .Date(0x1p+30), 0: nil ]      // any value is a key
    """)
if s.is(error) { println(s.error) }           // "',' or ']' in an array: unexpected '2' at 3"
var name = s["name"]                          // a copy of the value under "name": bound, as any owner is
var tags = s["tags"]
var second = tags[1]
println(name.string, " ", second.integer, " ", tags.count)   // kelvin 11 2
s["new"] = SION.string($"added")              // a member added, or replaced
var flat = SION.stringify(&s)                 // ["name":"kelvin","tags":["c",11],...]
var pretty = SION.stringify(&s, 2)            // one entry a line, two spaces a level
var back = SION.parse(&flat)                  // a String, borrowed
println(SION.same(&s, &back))                 // true
```

- **The type** is `enum SION { nil; boolean: bool; integer: i64; number:
  f64; string: String; data: Bytes; date: f64; ext: Bytes; array:
  Array<SION>; dictionary: Array<SION>; error: String }`.
  - A value is one case, read as `s.integer`, `s.string`, `s.array[i]`,
    checked, and asked with `s.is(array)` or a `switch`.
  - A dictionary is an Array of its keys and values in turn, `[k0, v0,
    k1, v1, ...]`, in the order they were added, since a key may be any
    value; `s.count` is the count of its entries, and `SION.find(&d,
    &key)` the index of a key's value, or -1.
  - A SION owns what it holds, and is copied with `.copy()`, freed by
    its block, moved by `return` and by passing; see
    [enums.md](enums.md).
- **`SION.parse(text)`** takes a `cstr`, or a `String` borrowed, `&s`,
  and gives a `SION` straight: the value, or the case `error` with a
  `String` that says what was expected and the byte offset.
  - **The text** is SION's: `nil`, `true`, `false`; an integer in
    decimal, `0x2a`, `0o52` or `0b101010`, with a sign; a double with a
    point or an exponent, `42.0`, `4.2e1`, as a hex float, `0x1.5p5`,
    or `nan`, `inf`, `infinity` and their negatives, in any case of
    letters; a string in double quotes with JSON's escapes and Swift's
    `\0` and `\u{1F600}`; `.Data("base64")` and `.Ext("base64")`;
    `.Date(seconds)`, a number; `[a, b]` an array, `[k: v, k: v]` a
    dictionary, `[]` and `[:]` empty, a trailing comma allowed; and
    comments from `//` to the end of the line.
  - A string that is not UTF-8, a lone surrogate, and nesting deeper
    than 512 levels are errors too.
- **`SION.stringify(&s)`** gives the text as a `String`, compact:
  `["a":[1,2.5]]`.
  - **`SION.stringify(&s, space)`** indents, as JSON.stringify does:
    `space` is text, a `cstr` or a borrowed `String`, or a number of
    spaces, 0 to 10, one entry a line with ` : ` between a key and its
    value.
  - A double is written as C's `%a`, the hex float that reads back
    exactly, `0x1.8p+0` for 1.5, and `nan`, `inf` and `-inf`; an
    integer in decimal; a date as `.Date(%a)`; data and an ext in
    base64; a string as Swift quotes it, `\n`, `\t`, `\0`, `\u{1}`.
- **`s["key"]` and `s[i]`** (#136) give a copy of the value under a
  string or an integer key of a dictionary, or of an array's element,
  and `nil` where there is none, so `tags[1]` of a copy reads on.
  - A copy that an expression gives is bound before its case, an
    attribute or a method is read, as any owner is: `var name =
    s["name"]`, then `name.string`; `s["name"].string` is an error that
    says so, since the copy would be lost.
  - `s["key"] = v` and `s[i] = v` replace the value, add an entry at
    the end of a dictionary, or set an array's element; out of range,
    nothing changes.
- **`SION.same(&a, &b)`** compares two values member by member, since an
  Array in a case has no `==`.

## Functions

<!-- fragment -->
```kelvin
SION.parse(text: cstr): SION                      // a value, or error(message)
SION.parse(text: const String^): SION             // the same of a String, borrowed
SION.stringify(s: const SION^): String                              // compact
SION.stringify(s: const SION^, space: cstr): String                 // indented by space, at most 10 characters
SION.stringify(s: const SION^, space: const String^): String
SION.stringify(s: const SION^, space: i64): String                  // that many spaces a level, 0 to 10
SION.same(a: const SION^, b: const SION^): bool
SION.find(d: const SION^, key: const SION^): i64                    // the index of key's value in a dictionary, or -1
```

## Properties and methods

| On | Property or method | Gives |
|---|---|---|
| `SION` | `.nil`, `.boolean`, `.integer`, `.number`, `.string`, `.data`, `.date`, `.ext`, `.array`, `.dictionary`, `.error` | the case's value, checked; `SION.nil`, `SION.integer(42)`, ... make one |
| | `s["key"]`, `s[i]` | a copy of the value by a string or an integer key, or of an element, bound before it is read; `nil` where none; set with `=` (#136) |
| | `.count` | an array's elements or a dictionary's entries, else 0 |
| | `.is(array)`, `.case`, `switch s { case array: ... }` | which case it is; `case array(xs):` binds the value (#119) |
| | `.copy()` | a copy, deep |
| | `.cstr`, `${s}`, `println(s)` | the case and its value, `integer(42)`, as any enum's; `SION.stringify(&s)` for SION text |
| | `.size`, `.typename` | `sizeof`; `SION` |
