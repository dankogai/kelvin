# String: Kelvin's text on the heap

`String` is Kelvin's own text: UTF-8 on the heap, checked, growing, freed when its block ends, its elements its graphemes.

## Synopsis

```swift
var s = $"héllo"                      // String("héllo"); String() is empty
s += ", world"                        // append text; also s.append(...)
println(s, " ", s.count, " ", s[1], " ", s[0..<5])   // héllo, world 12 é héllo
```

## Description

`String` (#55) is text that is well-formed UTF-8, on the heap, growing,
and freed when its block ends. Its elements are its graphemes (#522),
what a reader sees as one character, each a String: it is counted,
walked, indexed and sliced by them. `uchr` (#56) is a single codepoint,
and `s.codepoints` (#521) the codepoints of a String. `Bytes` (#54),
any bytes on the heap, looks the same and is another thing, indexed by
byte and not text: [bytes.md](bytes.md).

This document says how a String is made, read, walked, compared and
printed; the ownership rules of `String` and `Bytes` are in
[ownership.md](ownership.md). `toString()` and `fmt()` stay shelved
(#22): `.cstr`, a template literal and `` $`...` `` do their work.

- What the Unicode Character Database adds, `s.normalize(nfc)`,
  `s.graphemes`, the case mappings and a codepoint's name and category,
  is the prelude's `UnicodeData` (#156, #520), in every program:
  [unicodedata.md](unicodedata.md).
- Regular expressions, JS's, with the `$/.../` literal, are the
  prelude's `RegExp` (#157, #504): [regexp.md](regexp.md).

### How it differs from `cstr`

| | `String` | `cstr` ([cstr.md](cstr.md)) |
|---|---|---|
| What | UTF-8 on the heap, checked (#55) | a pointer to C's bytes, up to a NUL |
| Owned | yes: freed when its block ends, moved, copied by `.copy()` | no: it points at text that lives elsewhere |
| Changes | grows: `s += t`, `s.append(x)` | never through it (#52) |
| A NUL | is a character it may hold (#299) | ends it |
| Elements | graphemes, each a String (#522) | bytes, `u8`, by `for c in s` and `s[i]` |
| `.count` | its graphemes, O(n) | its bytes, `strlen`, kept per scope |
| `==` | the text, by its bytes | the pointers, as in C |
| Assigned | with `=`, a value | with `:=`, a reference |

- A literal is a `cstr`, and becomes a String where one is expected
  (#70): `var s:String = "x"`; `$"text"` is one always.
- `s.cstr` lends a String's text to C, NUL-ended; `String(c)` copies a
  `cstr` into a String.

### A String

It is an owner: freed when its block ends, moved by `return` and by
passing, copied only by `.copy()`, borrowed as a pointer. The rules are
in [ownership.md](ownership.md); this is the summary.

<!-- fragment -->
```swift
var s = $"héllo"                 // String("héllo"); String() is empty
s += ", world"                   // append text; also s.append(...)
s += t.copy()                    // a String's text; s += &t borrows it
println(s, " ", s.count)         // the text, and its graphemes: 12
for c in s { print(c, "|") }     // each grapheme, a String
for c in s.codepoints { print(c.utf32, " ") }   // each codepoint, a uchr
let p := s.cstr                  // a borrow of the text, NUL-ended, for C
var line = $`${s} has ${s.count} graphemes`    // a String built from a template (#67)
```

- **A NUL** (#299): a String holds one, which a `cstr` cannot.
  - `$"\x00mid"` is four graphemes, a literal made a String every
    byte of it, `$"\u{0}mid"` too.
  - `s.escape()` writes a NUL as `\u{0}`, which `unescape()` and a
    literal read back, as they do `print`'s `\u0000`.
  - A `cstr` stops at its first NUL, as C's does: `$"p" + "\u{0}q"` is
    `"p"`, and `.cstr` of a String with one is cut there.
- **Making one:** `$"text"` or `String("text")`, `String(s)` of a
  `cstr` or a byte array, `String(&b)` of a `Bytes`, all checked for
  UTF-8: text that is not ends the program.
  - `String(n)` of a number or a bool is its text as `print` shows it:
    `String(42)`, `String(2.5 * 2.0)` (#158).
  - `String(x)` of an owner, a variable or what an expression gives
    alike, is an error in Kelvin's words, not C's (#412).
    - Of a String, `String(f())` is one already; a variable's copy is
      `s.copy()`.
    - Of a Bytes, write `String(&b)`, or `b.string()` for a Result.
    - Of another owner, `String($[1, 2])`, the message names what
      `String` takes.
  - `b.string()` of a `Bytes` (#405) is a `Result<String, i64>`
    instead: the String, or `err(at)`, the offset of the first byte
    where the UTF-8 breaks, to handle: [bytes.md](bytes.md).
  - Where a String is expected, a string literal becomes one by itself
    (#70): `var s:String = "x"`, `s = "y"`, a member, an element or an
    entry written as `"text"`.
  - `` $`a${x}b` `` from a template, with no bound on its length.
  - **Of codepoints** (#526): `String.fromCodepoints(0x48, 0x69)` is
    `ok("Hi")`, and `grapheme(0x65, 0x301)` `ok("e\u0301")`, the first
    grapheme alone, a `Result<String, CodepointError>`.
    - Of any number of integers, or of one `Array<u32>`.
    - The codepoints are kept as given, not normalized: `0x65, 0x301`
      is two codepoints of one grapheme.
    - None at all, a surrogate, and a number past U+10FFFF or below 0
      are an `err`: [unicodedata.md](unicodedata.md#codepoints-into-a-string-grapheme-and-stringfromcodepoints).
  - A `Bytes` is made its own ways, `Bytes("text")`, `Bytes([...])`,
    `Bytes.fromBase64(text)`: [bytes.md](bytes.md).
- **Methods:** `append` (also `+=`, of text, a borrow `&t`, a `uchr`,
  or a String an expression gives), `clear`, `reserve`, `compact`,
  `copy`, `escape` and `unescape`.
- **Graphemes** (#522): a String's elements are its grapheme clusters,
  what a reader sees as one character (UAX #29), each a String.
  - `é` written as `e` and a combining acute is one, as are a family
    emoji with its joiners, a flag and a CR LF.
  - `s.count`, `s[i]`, the slices, `s.find`, `s.prefix` and `for c in s`
    count them; each walks the String from its start, so `s[i]` and
    `s.count` are O(n), not O(1).
  - `s.codepoints` (#521) is the codepoints, and `s.bytes^` the bytes.
- **`s[i]`** (#522) is grapheme `i`, a new String, `i` an integer; past
  the end ends the program: `kelvin: index 5 is out of range: the String
  has 5 graphemes`.
- **`s + t`** (#183) is a new String of the two, either side a String,
  text or a `uchr`, one a String: `s + "!"`, `"x" + s`, `s + t + u`.
  - A String in a variable is copied and stays; one an expression gives
    is taken, so that a chain frees what it made.
  - `s += t` still appends in place, and a number is shown with a
    template, `` $`${n}` ``.
- **Searching** (#177): `s.find(text)` is the grapheme index of the
  first `text` in `s` (#522), or -1, found by its bytes: the index of
  the grapheme it starts in, `é`'s of its acute.
  - `s.has(text)`, `s.starts(text)` and `s.ends(text)` are whether it
    is there, at the start, at the end.
  - The text is a `cstr` or a String borrowed, `s.find(&t)`.
- **`s.trim()`** is a new String without the blanks at either end,
  the spaces, tabs and line ends JS's `\s` lists, U+3000 among them.
- **`s.prefix(n)`** and **`s.prefix { ... }`** (#372) are a new String
  of the first `n` graphemes, or of those before the first the
  function says false for: `s.prefix { $0 != ' ' }`.
  - The function takes each grapheme, a String, lent (#522).
  - `n` past the count gives the whole text; 0 or less, none.
- **Properties:** `count` (the graphemes, #522), `cstr` (a borrow of the
  text), `bytes` (its Bytes, read only), `size`, `typename`.
  - `.cstr` of a String an expression gives lives until the call or
    expression around it is done, up to the statement (#245):
    `strlen($"abc".cstr)`, `fopen(path().cstr, "r")`. Kept past the
    statement, `let p := $"x".cstr`, it would dangle, so that is an
    error that says to bind the String first.
  - A call whose result only C sees may give a pointer into it, so it
    lives for the call around that too (#437):
    `strlen(strchr($"xyz".cstr, 'y'))` is 2.
  - In an arm of `?:`, or right of `&&`, `||` or `??`, which is not
    always evaluated, it is held there alone: `c ? f().cstr : "no"` as
    an argument is the same error (#437).
- **Walking:** `for c in s` gives each grapheme (#522), a String the
  loop holds and frees, `c` a let; `for x in s.bytes^` each byte.
  - A type written walks codepoints: `for c:uchr in s` gives each as a
    `uchr`, which prints as its character, and `for n:u32 in s` each
    one's number (#480).
  - **`s.codepoints`** (#521) is its codepoints, an `Array<uchr>`.
    - `for c in s.codepoints` walks the String in place, with no Array
      made: the walk to write where codepoints are meant, as `for c in
      s` walks graphemes (#522).
    - Of a borrow, `s^.codepoints`, and of a String an expression
      gives, `f().codepoints`, which is held for the loop.
  - A `[uchr](N)` or a `uchr^` is walked up to `uchr(0)` (#480).
- **Slices** (#68): `s[lo..<hi]`, `s[lo...hi]`, `s[lo...]`, `s[..<hi]`
  and `s[...hi]` are new Strings of those graphemes (#522); a range past
  the count ends the program.
  - `s[r]` slices by a Range value as well (#377).
- **Comparing:** `==` and `!=` compare two Strings by their bytes.
  - A String compares with text, a `cstr` or a literal, a `uchr` or a
    character, on either side (#522): `c == " "`, `c != ' '`, `s == u`
    where `s` is that one codepoint.
  - `<`, `<=`, `>` and `>=` order two Strings by their bytes, codepoint
    order for UTF-8, `"Zed" < "ann"` (#185).
  - A Bytes compares the same way.
- **Printing:** `print` shows a String's text; inside a value, an
  Array's element or a member, it is quoted, `"x"`, so that it pastes
  back ([printing.md](printing.md)).

### What is not here yet

`insert` and `remove` on a String, and encodings other than UTF-8, are
to come.

## Where it lives

The prelude's, `libkelvin`, linked without an import: `String` and `uchr` (#55, #56), with the graphemes' functions of runtime/unicode.c and UnicodeData's (#520, #522).

## Properties and methods

| On | Property or method | Gives |
|---|---|---|
| `String` | `.count` | the graphemes, found by walking it, O(n) (#522) |
| | `.isEmpty` | whether it holds no text, `.count == 0`, a `bool` (#434) |
| | `.bytes` | its Bytes, a read-only borrow ([bytes.md](bytes.md)) |
| | `.cstr` | a borrow of the text |
| | `.append(x)`, `+=` | text, a `uchr`, `&other`, or a String an expression gives |
| | `.clear()`, `.reserve(n)`, `.compact()`, `.copy()` | changes in place; a new String |
| | `s + t` | a new String of the two, a String, text or a `uchr` on either side (#183) |
| | `.find(text)`, `.find(&t)` | the grapheme index of the first `text`, or -1 (#177, #522) |
| | `.has(text)`, `.starts(text)`, `.ends(text)` | whether `text` is there, at the start, at the end; `&t` too |
| | `.trim()` | a new String without the blanks at either end |
| | `.escape()` | the text with each codepoint beyond ASCII as `\u{...}`, a NUL as `\u{0}` (#299), and a `\` as `\\`, a new String (#164); with the prelude's `RegExp` (#504), `.escape(&re)` escapes what `re` matches instead |
| | `.unescape()` | the escapes read back: `\u{...}`, `\uHHHH` (a surrogate pair joined), `\xHH`, `\n`, `\r`, `\t`, `\0`, `\\`, `\"`, `\'`; what is none stays as written; with the prelude's `RegExp` (#504), `.unescape(&re)` reads back what `re` matches alone (#165) |
| | `for c in s` | each grapheme, a String (#522) |
| | `for c:uchr in s`, `for n:u32 in s` | each codepoint, a `uchr`, or its number (#480) |
| | `s[i]` | grapheme `i`, a new String, O(n) (#522) |
| | `.codepoints` | its codepoints, an `Array<uchr>`; `for c in s.codepoints` walks them in place (#521) |
| | `s[lo..<hi]` | a slice by grapheme, a new String (#68, #522) |
| | `s[r]` | a slice by a Range value, a new String (#377) |
| | `.prefix(n)`, `.prefix { ... }` | a new String of the first `n` graphemes, or of those before the first `f` says false for, `f` of each, a String (#372, #522) |
| | `String.fromCodepoints(c0, c1, ...)` | a `Result<String, CodepointError>` of the codepoints, integers or one `Array<u32>` (#526): [unicodedata.md](unicodedata.md) |
| | `grapheme(c0, c1, ...)` | the same of the first grapheme alone, the rest checked and dropped (#526) |
| | `.normalize(nfc)`, `.graphemes`, `.upper()`, `.lower()`, `.fold()` | the prelude's `UnicodeData` (#156, #520): [unicodedata.md](unicodedata.md) |
| | `.test(&re)`, `.search(&re)`, `.match(&re)`, `.replace(&re, with)`, `.split(&re)` | with the prelude's `RegExp` (#157, #504), `re` a `$/.../`: [regexp.md](regexp.md) |
| | `==`, `!=` | by the bytes, with a String, text, a `uchr` or a character (#522) |
| | `<`, `<=`, `>`, `>=` | by the bytes, codepoint order (#185) |
| | `i64(s)`, `f64(s)`, ... | a number read from its text (#88): [cstr.md](cstr.md#reading-numbers-from-text) |
| `uchr` | `uchr(x)` | of an integer, or the first codepoint of text, a String or a Bytes, `uchr(s)` or `uchr(&s)`; U+FFFD where none (#56, #494) |
| | `.utf32`, `.codepoint` | the number, a `u32` (#56) |
| | `.cstr` | the character as UTF-8 text |
| | inside a value | `uchr("x")`, quoted, so that it pastes back; U+0000 `uchr(0)` (#479) |
| | `<`, `==` and the rest | with a `uchr` or a number |
| | `for c in a` | of a `[uchr](N)` or a `uchr^`, each up to `uchr(0)` (#480) |
| all | `.size`, `.typename` | as any value's |

The ownership rules are in [ownership.md](ownership.md), the general
properties in [properties.md](properties.md).
