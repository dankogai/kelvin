# UnicodeData: the Unicode Character Database, of the prelude

The Unicode Character Database for Strings and codepoints: normalization, graphemes, the case, names and categories.

## Synopsis

```swift
let main():int32 {
    var s = $"e\u0301 ﬁ 👨‍👩‍👧"
    var c = s.normalize(nfc)                 // é as one codepoint: one fewer
    var gs = s.graphemes                     // é, a space, ﬁ, a space, the family
    for g in gs { println(g) }
    var up = s.upper()
    var e = $"é".codepoints[0]               // 0xE9, a u32
    println(gs.count, " ", c.count, " ", up, " ", e.name, " ", e.category)
    return 0
}
```

## Description

`UnicodeData` (#156) is the Unicode Character Database for Strings and
codepoints, after Python's `unicodedata`.

- **It is the prelude's** (#520): every program has it, as it has
  `String`, with no import.
  - `#import <UnicodeData>`, as programs before #520 write it, is still
    read, and adds nothing.
  - Its `nfc`, `nfd`, `nfkc` and `nfkd` are words of every program, and
    `grapheme(...)`, `String.fromCodepoints(...)` and `CodepointError`
    (#526) are names of it.
- It is a header, `UnicodeData.kh` in `modules/`, whose code libkelvin
  holds (#504), as the prelude's `RegExp` uses it; a program links its
  tables only where it uses them.

### A String: `normalize`, `graphemes`, the case

- **`s.normalize(form)`** is the String normalized, a new String, by
  `nfc`, `nfd`, `nfkc` or `nfkd`, the four words of `enum NormalForm`,
  as UAX #15 defines them.
  - `nfc` composes: `e` and a combining acute become `é`, one
    codepoint; `nfd` decomposes it; `nfkc` and `nfkd` also fold the
    compatibility forms, `ﬁ` to `fi`, `㌀` to `アパート`.
  - Hangul is composed and decomposed arithmetically, and marks are
    put in canonical order; the database's own NormalizationTest.txt
    passes whole.
- **`s.graphemes`** is an `Array<String>` of the grapheme clusters, the
  elements of a String since #522, which `for c in s` walks with no
  Array made; it stays, as an Array of them,
  what a reader sees as one character (UAX #29): `é` written as two
  codepoints is one, as are a Hangul syllable written as jamo, a
  family emoji with its joiners, a flag of two regional indicators and
  an Indic conjunct.
  - Each is a String of its own: bound, `var gs = s.graphemes`, `for g
    in gs { }` walks them and `gs.count` counts them, where `s.count`
    counts codepoints; the database's GraphemeBreakTest.txt passes
    whole. An Array an expression gives is held until the expression is
    done, `s.graphemes.count`, `for g in s.graphemes { }` (#187).
- **`s.codepoints`** (#521) is the String's codepoints, an
  `Array<u32>` (#527), which `for c in s.codepoints` walks in place,
  each a `u32`: [strings.md](strings.md).
  - `s.codepoints[0]` is the first codepoint of text, with the
    properties below.
- **`s.upper()`, `s.lower()` and `s.fold()`** map each codepoint by the
  simple case mappings, one codepoint to one, a new String: `ß` stays
  `ß` and `ﬁ` stays `ﬁ`, since their upper case is longer.
  - `fold` is the case folding: `s.fold() == t.fold()` compares two
    texts whatever their case.

### Codepoints into a String: `grapheme` and `String.fromCodepoints`

<!-- fragment -->
```swift
String.fromCodepoints(0x48, 0x69)        // ok("Hi"), every codepoint
grapheme(0x65, 0x301, 0x41)              // ok("e\u0301"), the first grapheme alone
grapheme(0x1F1EF, 0x1F1F5)               // ok("🇯🇵"), two regional indicators, one grapheme
grapheme(0xD800)                         // err(CodepointError.surrogate(55296))
var cs:$[u32] = $[0x63, 0x327]
String.fromCodepoints(cs)                // of an Array<u32> too
```

- **`String.fromCodepoints(c0, c1, ...)`** (#526) is a String of the
  codepoints, all of them, in a `Result<String, CodepointError>`.
- **`grapheme(c0, c1, ...)`** is the first grapheme of them alone, a
  String in the same Result.
  - The codepoints after it are checked, and then dropped.
  - Any one codepoint is a grapheme (UAX #29), so only none at all is
    too few.
- **Their arguments** are any number of integers, a `u8` or a
  character too, or one `Array<u32>`.
  - kelvinc and kc read the integers, as they read `println`'s, into an
    array of them; a float, a bool and text are errors.
  - The codepoints are kept as given: `0x65, 0x301` is `e` and a
    combining acute, not `é` made one; `.normalize(nfc)` composes it.
- **The error** is an enum with values, `CodepointError`, of the first
  argument that makes no codepoint:

| Case | When |
|---|---|
| `empty` | there are no codepoints at all |
| `surrogate(u32)` | one is a surrogate, U+D800 to U+DFFF, which UTF-8 never holds |
| `outOfRange(i64)` | one is past U+10FFFF, or below 0 |

### A codepoint: `name`, `category` and the rest

A codepoint is a `u32` (#527), as `s.codepoints` gives it, and these are its properties, of `extend u32`:

<!-- fragment -->
```swift
let e = $"é".codepoints[0]               // 0xE9
e.name                                   // LATIN SMALL LETTER E WITH ACUTE
(0x4E2D as u32).name                     // CJK UNIFIED IDEOGRAPH-4E2D
var s = $""
s += e.upper                             // É: a String's += takes a codepoint
```

| On a `u32` | Gives |
|---|---|
| `.name` | its name, a String: `LATIN SMALL LETTER E WITH ACUTE`; Hangul syllables and the CJK, Tangut, Nushu and Khitan ideographs by their rules; `""` where there is none |
| `.category` | the general category, a `cstr`: `Lu`, `Ll`, `Nd`, `Zs`, `So`, ... |
| `.isLetter`, `.isMark`, `.isNumber`, `.isPunctuation`, `.isSymbol`, `.isSpace` | the category's first letter, L, M, N, P, S or Z |
| `.combining` | the canonical combining class, an `int64`: 0 for a starter, 230 for an acute |
| `.upper`, `.lower`, `.fold` | the simple case mapping, a `u32`; itself where there is none |
| `.decomposition` | the canonical decomposition, a String: `é` gives `e` and the acute; `""` where there is none |
| `.compatibility` | the decomposition with the compatibility mappings: `ﬁ` gives `fi` |
| `.script` | the Script, a `cstr` by its long name: `Latin`, `Han`, `Common`, `Unknown` (#157) |
| `.hasProperty("Alphabetic")` | a binary property by its name or its alias, the ones JS's `\p{...}` has: `White_Space`, `Emoji`, `Alpha`; false for a name there is none of (#157) |

- Only a `u32` has them: an integer of another type, a literal too, is
  converted first, `(0xE9 as u32).name`, `(c as u32).isLetter`.
- A surrogate has no name, `""`, and the category `Cs`; a number past
  U+10FFFF none, `""` and `Cn`, and its case is itself.

### Notes

- A method on a String that an expression gives, as
  `$"Straße".fold()`, holds the String until the expression is done,
  then frees it (#187), as the prelude's `.count` of one does.
- The tables are built from tools/ucd/ by `make`, which needs python3
  once; to move to a newer Unicode, replace the files there and run
  `make`. The database is Unicode, Inc.'s, under the Unicode License v3,
  tools/ucd/LICENSE.txt.
- The tables of the scripts, the script extensions and the binary
  properties (#157) serve `<RegExp>`'s `\p{...}` too:
  [regexp.md](regexp.md).
- Not here yet: the full case mappings that change the length, `ß` to
  `SS`.

## Where it lives

`modules/UnicodeData.k`, written in Kelvin over runtime/unicode_data.c,
on the tables that tools/gen_unicode.py makes from the database's files
in tools/ucd/, Unicode 18.0.0.

- `make` builds the tables, and `kelvinc --prelude` (#504) the header
  and the object, which libkelvin holds with the tables' and
  runtime/unicode_data.c's; libkUnicodeData is no more.
- kelvinc and kc bring the header into every program (#520), but into
  UnicodeData.k's own build; a module's header made by `--lib` or
  `--prelude` does not write that import.
- A program links the tables only where it uses them, from the static
  libkelvin.a.
