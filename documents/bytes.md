# Bytes: any bytes, on the heap

`Bytes` (#54) is any bytes, on the heap, growing: text, or what is not
text, a file's content, a packet, a hash. It is an owner: freed when
its block ends, moved by `return` and by passing, copied only by
`.copy()`, borrowed as a pointer, `&b`. A `String` is a `Bytes` that
holds well-formed UTF-8, counted by codepoint: text is in
[strings.md](strings.md), and the ownership rules in
[ownership.md](ownership.md). The two look alike and are kept apart:
a Bytes is indexed by byte, unchecked for text, and a String walked
by codepoint, text always.

```swift
var b = Bytes("raw")                  // the bytes of the text
var z = Bytes([0, 1, 255, 'A'])       // the bytes written out (#172)
var n = Bytes(16)                     // 16 zero bytes
b += 0                                // a byte appended; also b.append(0)
b += Bytes([0xFF, 0xFE])              // bytes an expression gives
var e = b.escape()
println(b[0], " ", b.count, " ", e)   // 114 6 raw\x00\xFF\xFE
for x in b { print(x, " ") }          // each byte, a u8
println()
var t = Bytes("héllo")
var s = t.string()                    // a String, checked for UTF-8; String(&t) too; b has 0xFF, no text
println(s, " ", s.count, " ", t.count)   // héllo 5 6
```

**Where it lives:** the prelude's, `libkelvin`, linked without an
import; what a RegExp does with a Bytes is `#import <RegExp>`
([regexp.md](regexp.md)).

## Making one

- **`Bytes()`** is empty; **`Bytes(n)`** is n zero bytes; **`Bytes("text")`**
  or of any `cstr` is the bytes of the text, without its NUL;
  **`Bytes(p, n)`** is n bytes from a pointer; **`Bytes(&b)`** or
  **`b.copy()`** a copy.
  - **`Bytes(&s)`** of a String is a copy of its bytes (#291), the
    String left as it was; `Bytes(s)` is an error that says so.
- **`Bytes([...])`** (#172) is the bytes written out, each a character
  constant or a number 0 to 255, or any `u8` value: `Bytes([0x89,
  'P', 'N', 'G'])`; a number out of that range is an error, and
  `Bytes([])` is empty.
- **`Bytes.fromBase64(text)`** (#155) decodes base64, of a `cstr` or of
  a String borrowed, `&s`: either alphabet, standard or URL-safe, with
  or without the `=` padding, blanks skipped; a letter that is neither
  ends the program.
- **`Bytes.unescape(text)`** (#167) reads the escapes of text, a `cstr`
  or a String borrowed, back into bytes: `\xHH` a byte, `\u{...}` and
  `\uHHHH` the UTF-8 of the codepoint, `\n`, `\r`, `\t`, `\0`, `\\`,
  `\"` and `\'` theirs, what is none as written; `b.escape()` read
  back.
- **`s.bytes`** of a String is its Bytes, a read-only borrow, not a
  new one.

## Reading and changing

- **`b[i]`** is a byte, a `u8`, checked against the count, and
  assignable; `b.at` is the bytes as a `u8^`, a borrow, unchecked;
  `b.cstr` a borrow of the bytes NUL-ended, for C.
- **`b.count`** is the bytes held, `b.capacity` the room, `b.isUTF8`
  whether it would pass as a String.
- **`b[lo..<hi]`**, `b[lo...hi]`, `b[lo...]`, `b[..<hi]` and
  `b[...hi]` (#68) are new Bytes of those bytes; a range past the count
  ends the program; `b[r]` slices by a Range value (#377).
- **`for x in b`** gives each byte.
- **`b.append(x)`**, also `b += x`, takes text, a byte, `&other`, or a
  Bytes an expression gives; `b.insert(i, x)` the same at i,
  `b.remove(i, n)` n bytes at i; `b.clear()`, `b.reserve(n)` and
  `b.compact()` as their names say, in place.
- **`==`** and `!=` compare two Bytes by their bytes, and `<`, `<=`,
  `>` and `>=` order them by their bytes, a shorter one first (#185).
- **`b + c`** (#188) is a new Bytes of the two: `b` a Bytes or text, `c`
  a Bytes, text or a byte, one a Bytes, `a + b + "cd" + 0x7F`. A Bytes
  in a variable is copied and stays; one an expression gives is taken,
  so that a chain frees what it made. A String and a Bytes are not
  joined: `Bytes(&s)` is the bytes of a String. `b += c` still appends
  in place.

## Text out of bytes

- **`b.string()`**, or `String(&b)`, is a new String of the bytes,
  checked: bytes that are not UTF-8 end the program.
- **`b.toBase64()`** (#155) gives the base64 text as a String, standard
  and padded; the words `url` and `nopad`, in either order, pick the
  URL-safe alphabet, `-` and `_` for `+` and `/`, and no `=` at the
  end: `b.toBase64(url, nopad)`.
- **`b.escape()`** (#166) gives the bytes as text, a String: each byte
  that is not printable ASCII as `\xHH`, and a backslash as `\\`;
  `Bytes.unescape(&e)` reads it back, and `e.unescape()` of a String
  where the bytes were text.
- **`println(b)`** prints the bytes as they are.

## With a RegExp

With `#import <RegExp>` ([regexp.md](regexp.md)) a Bytes has
`b.test(&re)`, `b.search(&re)`, `b.match(&re)`, `b.split(&re)`,
`b.replace(&re, &with)`, `b.escape(&re)` and `Bytes.unescape(text,
&re)` (#168, #169, #170), each as a String's; a `BytesMatch` holds
bytes with byte offsets. Write the `b` flag, `$/[\x80-\xff]/b`, to
match byte by byte (#171): without it the bytes are read as UTF-8 as
far as they are.

## Properties and methods

| On a `Bytes` | Gives |
|---|---|
| `.count`, `.capacity` | the bytes held, and the room |
| `b[i]` | a byte, checked; assignable |
| `.at` | the bytes, a `u8^` borrow, unchecked |
| `.cstr` | a borrow of the bytes, NUL-ended |
| `.isUTF8` | whether it would pass as a String |
| `.append(x)`, `+=` | text, a byte, `&other`, or a Bytes an expression gives |
| `.insert(i, x)`, `.remove(i, n)`, `.clear()`, `.reserve(n)`, `.compact()` | changes, in place |
| `.copy()`, `.string()` | a new Bytes; a new String, checked |
| `b[lo..<hi]` | a slice, a new Bytes (#68) |
| `b[r]` | a slice by a Range value, a new Bytes (#377) |
| `.toBase64()`, `.toBase64(url)`, `.toBase64(nopad)`, `.toBase64(url, nopad)` | the base64 text, a String (#155) |
| `.escape()` | the bytes as text, a String: each that is not printable ASCII as `\xHH`, a `\` as `\\` (#166); with `<RegExp>`, `.escape(&re)` what `re` matches too (#168) |
| `Bytes([...])` | the bytes written out (#172) |
| `Bytes(&s)` | a copy of a String's bytes (#291) |
| `Bytes.fromBase64(text)`, `Bytes.fromBase64(&s)` | the bytes of base64 text, either alphabet, padded or not (#155) |
| `Bytes.unescape(text)`, `Bytes.unescape(&s)` | the bytes the escapes stand for (#167); with `<RegExp>`, `Bytes.unescape(text, &re)` where `re` matches alone (#168) |
| `.test(&re)`, `.search(&re)`, `.match(&re)`, `.split(&re)`, `.replace(&re, &with)` | with `#import <RegExp>` (#169, #170): [regexp.md](regexp.md) |
| `b + c` | a new Bytes of the two, a Bytes, text or a byte on the right (#188) |
| `==`, `!=`, `<`, `<=`, `>`, `>=` | by the bytes (#185) |
| `.size`, `.typename` | as any value's |

The ownership rules are in [ownership.md](ownership.md), the general
properties in [properties.md](properties.md).
