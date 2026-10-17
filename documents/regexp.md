# RegExp: `#import <RegExp>` and `$/.../`

`#import <RegExp>` (#157) brings in regular expressions, JS's with the
`u` flag, over Kelvin's Strings, codepoint by codepoint, with `\X` for
a grapheme cluster. `$/pattern/flags` is a literal, read where the
module is imported, and `RegExp.compile(pattern, flags)` the same from
text. It is a header and a library, `RegExp.kh` and `libkRegExp` in
`modules/`, on `UnicodeData`, which the import links by itself.

```kelvin
#import <RegExp>

let main():int32 {
    let re = $/(\d{4})-(?<month>\d\d)/g
    var s = $"2026-10-17 and 2027-01-02"
    println(re.test(&s), " ", re.search(&s))        // true 0
    var ms = s.match(&re)                           // every match, with the g flag
    for m in ms {
        var month = m["month"]
        println(m.text[0], " ", m.text[1], " ", month, " ", m.start)
    }
    var t = s.replace(&re, "$<month>/$1")           // 10/2026-17 and 01/2027-02
    let blanks = $/\s+/
    var words = t.split(&blanks)
    println(t, " ", words.count)
    return 0
}
```

**Where it lives:** `modules/RegExp.k`, written in Kelvin over
`libkRegExp`, runtime/regexp.c, the engine, with `libkUnicodeData`
under it for `\p{...}`, the case folding of the `i` flag and `\X`;
`make` builds the header and the library with `kelvinc --lib`. The
`$/.../` literal is kelvinc's: it becomes `RegExp.compile("...", "...")`,
so a file that has not imported `<RegExp>` cannot write one.

## The literal and the flags

- **`$/pattern/flags`** is a `RegExp`, an owner: bind it, `let re =
  $/a+/g`, and borrow it to the methods, `&re`.
  - The pattern ends at the first `/` that is not escaped, `\/`, and
    not in a class, `[/]`, on the same line; it is written into the
    program as it is, so `\d` is `\d`, with no doubling.
  - A `RegExp` an expression gives is bound before it is used, as every
    owner is: `s.replace(&$/x/, "y")` is an error, and so is
    `$/x/.test(&s)` ([ownership.md](ownership.md)).
  - kelvinc checks the pattern as it reads the literal (#163): `$/(a/`
    is an error at the `(`, with what is wrong, as `\p{Nope}` and a
    flag that is none are, before anything runs. The parser of the
    module, with the Unicode tables, is linked into kelvinc for it;
    `RegExp.compile(text, flags)` of text checks at run time, and a
    pattern that is not one ends the program then.
- **`RegExp(pattern, flags)`**, and `RegExp.compile(pattern, flags)`
  the same, take the pattern and the flags each as a `cstr` or a String
  borrowed, `RegExp(&p, &f)` (#162), and `""` for no flags; a pattern
  that is not one ends the program, saying what is wrong and where in
  it.
- **The flags** are JS's: `g` every match, `i` by simple case folding,
  `m` for `^` and `$` at line ends, `s` for `.` over line ends, `y`
  sticky, at the start alone, and `u` and `d`, accepted; `v` is not
  here yet.
  - `re.source`, `re.flags` and `re.groups` are the pattern, the flags
    and the count of groups; `re.global`, `re.ignoreCase`,
    `re.multiline`, `re.dotAll` and `re.sticky` the flags one by one.

## The syntax

JS's, as its `u` flag reads it, over codepoints: a `.` is one codepoint,
`é` as two codepoints is two, and an escape that JS rejects is an error.

| Written | Matches |
|---|---|
| `a`, `\n`, `\t`, `\0`, `\xHH`, `\uHHHH`, `\u{...}`, `\cX`, `\/` | a codepoint; `\uD83D\uDE00` is the pair joined |
| `.` | any codepoint but a line end, `\n`, `\r`, U+2028, U+2029; any at all with `s` |
| `[abc]`, `[a-z]`, `[^...]`, `[\d\p{L}]`, `[\b]` | a class, with ranges, escapes and properties; `[\b]` is a backspace |
| `\d`, `\w`, `\s`, `\D`, `\W`, `\S` | a digit, a word character, `[A-Za-z0-9_]`, a space as JS lists them, and not one |
| `\p{L}`, `\p{Lu}`, `\p{Letter}`, `\p{gc=Nd}` | a General_Category, by its short or long name, or a group, `L`, `M`, `N`, `P`, `S`, `Z`, `C` |
| `\p{Script=Greek}`, `\p{sc=Grek}`, `\p{scx=Hira}` | a Script, by its long or short name, or a Script_Extensions |
| `\p{Alphabetic}`, `\p{Emoji}`, `\p{White_Space}`, `\p{Alpha}` | a binary property, the ones JS has, by its name or its alias; `\P{...}` is not one |
| `\X` | a grapheme cluster, what a reader sees as one character (UAX #29): a family emoji, a flag, `é` as two codepoints |
| `x*`, `x+`, `x?`, `x{n}`, `x{n,}`, `x{n,m}` | repeated, greedy; with a `?` after, `x*?`, lazy |
| `(x)`, `(?<name>x)`, `(?:x)` | a group, numbered from 1 as its `(` comes, named, or not captured |
| `(?i:x)`, `(?-i:x)`, `(?ims-ims:x)` | the flags `i`, `m` and `s` on or off inside the group |
| `a|b` | either |
| `^`, `$`, `\b`, `\B` | the start and the end, of a line with `m`; a word boundary, and not one |
| `(?=x)`, `(?!x)`, `(?<=x)`, `(?<!x)` | lookahead and lookbehind, positive and negative; a lookbehind prefers the longest, as JS matches backward |
| `\1`, `\k<name>` | what a group matched, again; a group that took no part matches nothing |

- An iteration of `*`, `+` or `{n,}` that matches nothing ends the loop,
  and the groups inside a repeated group are reset each time, as JS
  has it: `(a*)*b` on `b` leaves group 1 unmatched.
- The `i` flag folds each codepoint by the simple case folding, one to
  one: `ß` matches `ß` and `ẞ`, not `ss`; `k` matches `K` and the Kelvin
  sign.
- A backtracking matcher: a pattern such as `(a*)*c` on a long run of
  `a` takes long, as it does in JS.
- A group is numbered up to 127, and a quantifier up to 100000 of a
  pattern that stays under a million words once unrolled.

## The methods

A `RegExp` has the methods, and a `String` has the same by the other
name: `s.match(&re)` is `re.match(&s)`.

| On a `RegExp` `re`, a `String` `s` | Gives |
|---|---|
| `re.test(&s)`, `s.test(&re)` | is there a match, a `bool` |
| `re.search(&s)`, `s.search(&re)` | the codepoint offset of the first match, or -1 |
| `re.exec(&s)` | the first match, a `Match?`: `if let m = re.exec(&s) { }` |
| `re.execFrom(&s, from)` | the first match at or after codepoint `from` |
| `re.match(&s)`, `s.match(&re)` | an `Array<Match>` of every match with `g`, else of the first alone, empty where there is none |
| `re.match(&s) { ... }`, `s.match(&re) { ... }` | the same matches, each given to the function as its `Match`: `s.match(&re) { println($0.text[1]) }` (#159) |
| `re.replace(&s, with)`, `s.replace(&re, with)` | `s` with each match (the first alone without `g`) replaced, a new String; `with` a `cstr`, or a String borrowed, `&with` (#161) |
| `re.replace(&s) { ... }`, `s.replace(&re) { ... }` | the same, each match replaced by what the function gives for its `Match`: `s.replace(&re) { $`${(f64($0.text[1]) - 32.0) * 5.0 / 9.0}C` }` (#158) |
| `re.split(&s)`, `s.split(&re)` | `s` cut at each match, an `Array<String>`, as JS's `split` cuts |
| `re.split(&s) { ... }`, `s.split(&re) { ... }` | the same pieces, each given to the function as a String: `s.split(&re) { println($0) }` (#160) |
| `s.escape(&re)`, `s.escape($/.../)` | `s` with each codepoint of each match as `\u{...}`, and a `\` as `\\`, a new String that `s.unescape()` reads back (#164); the prelude's `s.escape()` escapes what is not ASCII |
| `s.unescape(&re)`, `s.unescape($/.../)` | the escapes read back in what the pattern matches alone, each match as `s.unescape()` reads the whole (#165) |
| `b.escape(&re)`, `b.escape($/.../)` | a Bytes as text, a String: each byte the pattern matches as `\xHH`, and every byte that is not printable ASCII too (#168) |
| `b.test(&re)`, `b.search(&re)`, `b.match(&re)`, `b.split(&re)`, and `re.test(&b)`, ... | on a Bytes (#169), byte by byte: a `bool`, a byte offset or -1, an `Array<BytesMatch>`, an `Array<Bytes>`; `b.match(&re) { }` and `b.split(&re) { }` with a function of each |
| `Bytes.unescape(text, &re)`, `Bytes.unescape(&s, $/.../)` | the bytes of the text, the escapes read back where the pattern matches the text alone (#168) |

- **`with`** is a `cstr`, or a String borrowed, `s.replace(&re, &t)`,
  with JS's patterns: `$&` the match, `$1` to
  `$99` a group, `$<name>` a named one, `` $` `` the text before, `$'`
  the text after, `$$` a `$`; a group that took no part is `""`, and a
  `$` that is none of these stays.
- **A function** in place of `with` is `(Match):String`, an anonymous
  one with `$0` the Match, or a named one; it owns the Match it is
  given, and gives the String that replaces the match.
- **`s.match(&re) { ... }`** (#159) walks the matches without an Array:
  the function, `(Match):()`, is called with each, every match with
  `g` and the first alone without, and owns the Match it is given.
- **`s.split(&re) { ... }`** (#160) walks the pieces the same way: the
  function, `(String):()`, is called with each piece, and owns it.
- **`s.escape(&re)`** (#164) escapes what the pattern matches, every
  match whatever the flags, each codepoint as `\u{...}`:
  `s.escape($/\p{Emoji_Presentation}/)` leaves `café` and turns `😀`
  into `\u{1F600}`. A literal written in the call moves in and is
  freed there, as an owner given by value does; a backslash is `\\`
  anywhere, so that `s.unescape()` of the prelude reads the text back.
- **`s.unescape(&re)`** (#165) reads back the escapes in what the
  pattern matches alone: `e.unescape($/\\u\{1F[0-9A-F]+\}/g)` turns
  the emoji escapes back and leaves `\u{E9}` as it is.
- **A Bytes** (#168, #169) is matched byte by byte, each byte the
  codepoint of its value, so that `\xHH` and `[\x80-\xFF]` mean bytes
  and `\X` is one byte. `b.test(&re)`, `b.search(&re)`, `b.match(&re)`
  and `b.split(&re)` are a String's over bytes: a `BytesMatch` has
  `m.data[i]`, the bytes of group `i` in place, `m[i]` and `m["name"]`
  copies, `m.start`, `m.end`, `m.startOf(i)`, `m.endOf(i)` byte
  offsets, `m.has(i)`, `m.count` and `m.names[i]`; the pieces of
  `split` are Bytes. The escapes: `b.escape($/[\x80-\xFF]/g)` escapes the high bytes, and
  every byte that is not printable ASCII with them, since a String
  holds text. `Bytes.unescape(&s, &re)` reads the escapes back into
  bytes where the pattern matches the text, `Bytes.unescape(text)` of
  the prelude the whole.

```kelvin
let temp = $/(-?\d+(?:\.\d+)?)F\b/g
var s = $"water boils at 212F and freezes at 32F"
s.match(&temp) { println($0.text[1], " at ", $0.start) }     // 212 at 15, 32 at 35
let blanks = $/\s+/
s.split(&blanks) { println($0) }                             // water, boils, at, 212F, ... each on its line
var c = s.replace(&temp) { $`${(f64($0.text[1]) - 32.0) * 5.0 / 9.0}C` }
println(c)                                                   // water boils at 100C and freezes at 0C
```
- **An empty match** moves on by one codepoint, as JS does: `$/x*/g`
  replaced by `-` in `abc` gives `-a-b-c-`, and `$//` splits a String
  into its codepoints.
- With the `y` flag a match is sought at the start alone, or at `from`.

## A match

A `Match` holds the text of the whole match and of each group, their
codepoint offsets and the groups' names, and stands on its own: the
String it came from may change or go.

| On a `Match` `m` | Gives |
|---|---|
| `m.text[i]` | the text of group `i`, a String in place: `m.text[0]` the whole; `""` where the group took no part |
| `m[i]`, `m["name"]` | a copy of the text of group `i`, or of the named group: bind it, `var month = m["month"]` |
| `m.start`, `m.end` | the codepoint offsets of the match in the String, `s[m.start..<m.end]` |
| `m.startOf(i)`, `m.endOf(i)` | the same for group `i`, -1 where it took no part |
| `m.has(i)` | did group `i` take part? |
| `m.count` | the groups and the whole: `re.groups + 1` |
| `m.names[i]` | the name of group `i`, `""` where it has none |

- `m.text[i]` is a place, so `println(m.text[1])` prints it and
  `m.text[1] == other` compares it; `m[i]` gives a copy, an owner an
  expression gives, which is bound first.
