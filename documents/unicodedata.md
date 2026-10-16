# UnicodeData: `#import <UnicodeData>`

`#import <UnicodeData>` (#156) brings in the Unicode Character Database
for Strings and codepoints, after Python's `unicodedata`: what the
prelude's `String`, which walks codepoints, leaves out. It is a header
and a library, `UnicodeData.kh` and `libkUnicodeData` in `modules/`,
which the import links by itself.

```kelvin
#import <UnicodeData>

let main():int32 {
    var s = $"e\u0301 ﬁ 👨‍👩‍👧"
    var c = s.normalize(nfc)                 // é as one codepoint: one fewer
    var gs = s.graphemes                     // é, a space, ﬁ, a space, the family
    for g in gs { println(g) }
    var up = s.upper()
    var name = uchr("é").name
    println(gs.count, " ", c.count, " ", up, " ", name, " ", uchr("é").category)
    return 0
}
```

**Where it lives:** `modules/UnicodeData.k`, written in Kelvin over
`libkUnicodeData`: runtime/unicode_data.c on the tables that
tools/gen_unicode.py makes from the database's files in tools/ucd/,
Unicode 18.0.0; `make` builds the tables, and `kelvinc --lib` the
header and the library.

## A String: `normalize`, `graphemes`, the case

- **`s.normalize(form)`** is the String normalized, a new String, by
  `nfc`, `nfd`, `nfkc` or `nfkd`, the four words of `enum NormalForm`,
  as UAX #15 defines them.
  - `nfc` composes: `e` and a combining acute become `é`, one
    codepoint; `nfd` decomposes it; `nfkc` and `nfkd` also fold the
    compatibility forms, `ﬁ` to `fi`, `㌀` to `アパート`.
  - Hangul is composed and decomposed arithmetically, and marks are
    put in canonical order; the database's own NormalizationTest.txt
    passes whole.
- **`s.graphemes`** is an `Array<String>` of the grapheme clusters,
  what a reader sees as one character (UAX #29): `é` written as two
  codepoints is one, as are a Hangul syllable written as jamo, a
  family emoji with its joiners, a flag of two regional indicators and
  an Indic conjunct.
  - Each is a String of its own: bound, `var gs = s.graphemes`, `for g
    in gs { }` walks them and `gs.count` counts them, where `s.count`
    counts codepoints; the database's GraphemeBreakTest.txt passes
    whole. The Array an expression gives is bound first, as every owner
    is ([ownership.md](ownership.md)).
- **`s.upper()`, `s.lower()` and `s.fold()`** map each codepoint by the
  simple case mappings, one codepoint to one, a new String: `ß` stays
  `ß` and `ﬁ` stays `ﬁ`, since their upper case is longer.
  - `fold` is the case folding: `s.fold() == t.fold()` compares two
    texts whatever their case.

## A codepoint: `name`, `category` and the rest

| On a `uchr` | Gives |
|---|---|
| `.name` | its name, a String: `LATIN SMALL LETTER E WITH ACUTE`; Hangul syllables and the CJK, Tangut, Nushu and Khitan ideographs by their rules; `""` where there is none |
| `.category` | the general category, a `cstr`: `Lu`, `Ll`, `Nd`, `Zs`, `So`, ... |
| `.isLetter`, `.isMark`, `.isNumber`, `.isPunctuation`, `.isSymbol`, `.isSpace` | the category's first letter, L, M, N, P, S or Z |
| `.combining` | the canonical combining class, an `int64`: 0 for a starter, 230 for an acute |
| `.upper`, `.lower`, `.fold` | the simple case mapping, a `uchr`; itself where there is none |
| `.decomposition` | the canonical decomposition, a String: `é` gives `e` and the acute; `""` where there is none |
| `.compatibility` | the decomposition with the compatibility mappings: `ﬁ` gives `fi` |

- The prelude's `uchr` has `.utf32`, its number, which these look up.

## Notes

- A method of the program on a String that an expression gives, as
  `$"Straße".fold()`, is an error, as the prelude's `.count` of one
  is: the String, a borrow to the method, would never be freed; bind
  it first.
- The tables are built from tools/ucd/ by `make`, which needs python3
  once; to move to a newer Unicode, replace the files there and run
  `make`. The database is Unicode, Inc.'s, under the Unicode License v3,
  tools/ucd/LICENSE.txt.
- Not here yet: the full case mappings that change the length,
  `ß` to `SS`, and the properties of UAX #44 beyond the category, which
  `<RegExp>` will bring for `\p{...}`.
