# Strings: `cstr` and `String`

Text in Kelvin is C's, or Kelvin's own. C's is a pointer to bytes that
end at a NUL, and it is more than a zero-terminated `[u8]`: a string
literal, a byte array, a `cstr` and the text a property or a template
makes are four different things in C, which Kelvin keeps apart.

Kelvin's own is `String` (#55), text that is well-formed UTF-8, counted
and walked by codepoint, on the heap, growing, and freed when its block
ends, with `uchr` (#56) a single codepoint. `Bytes` (#54), any bytes on
the heap, looks the same and is another thing, indexed by byte and not
text: [bytes.md](bytes.md).

This document says how Kelvin spells each kind, makes it, reads it,
walks it, compares it and prints it, and where it lives; the ownership
rules of `String` and `Bytes` are in [ownership.md](ownership.md).
`toString()` and `fmt()` stay shelved (#22): `.cstr`, a template literal
and `` $`...` `` do their work. What the Unicode Character Database
adds, `s.normalize(nfc)`, `s.graphemes`, the case mappings and a
codepoint's name and category, is a module, `#import <UnicodeData>`
(#156): [unicodedata.md](unicodedata.md); regular expressions, JS's,
with the `$/.../` literal, are `#import <RegExp>` (#157):
[regexp.md](regexp.md).

**Where it lives:** `cstr` is the core: C's text, with kelvinc's rules and nothing linked, but for the text of a property, which the prelude writes. `String` and `uchr` are the prelude's, `libkelvin`, linked without an import.

## Four kinds of text

```kelvin
let s:cstr := "hello"        // a pointer to static text: const char * in C
let t:[uint8] = "hello"         // a copy in an array of six bytes, NUL included
var buf = [uint8](64)           // 64 zero bytes to write into
let n:int64 = 42
let d:cstr := n.cstr         // "42", in a buffer on this block's stack
let card:cstr := `${n} items` // a template's text, on the stack too
```

- **`cstr`** is immutable text (#52): in C a `const uint8_t *`, a
  pointer to bytes that never change through it, which Kelvin treats as
  text rather than as a pointer.
  - It is a reference: assign it with `:=`, compare it with `nullptr`
    or `.isNull`, and its `.size` is a pointer's size, 8 on a 64-bit
    target.
  - `s.count` is its length, the bytes before the NUL: `strlen(s)`.
    - It is measured at the first use and kept for the rest of the
      scope in a `_kv_` variable, declared only where `.count` is used;
      after `s := t`, the next use measures again.
  - `cstr const` is a constant pointer.
  - **It cannot be written through**: `s[0] = 'U'` and `s^ = 0` are
    errors.
    - To change text, copy it into a byte array, `var t:[u8](n)` and
      `strcpy(t, s)`, or write through a `u8^`.
  - **It does not step**: `s++`, `s.next`, `s + 1` and `s += 1` are
    errors.
    - Walk it with `for c in s`, index it with `s[i]`, or take the rest
      of it with `&s[i]`, which is a `cstr` too.
  - **A `u8^` may still take it**, `var p:u8^ := s`, in a declaration,
    a `:=`, an initializer list or a call of a Kelvin function with a
    `u8^` parameter: kelvinc writes the cast.
    - This is allowed, not encouraged, and writing through `p` into a
      literal is C's undefined behavior.
    - A C function that takes `char *` needs `s as u8^`, since kelvinc
      cannot see its parameters.
    - The other way, a `u8^` or `const u8^` into a `cstr`, needs
      nothing.
  - **Prefer `cstr`** to `u8^` for text: a parameter `s:cstr` says the
    function reads it, a `u8^` that it may write; `argv` is `[cstr]`.
  - A string literal, the text of a property (`n.cstr`, `n.hex`) and a
    template are `cstr`, so `let s := "hi"` infers it.
- **A string literal** is C's: a `char` array that lives for the whole
  program, which decays to a pointer.
  - `let s:cstr := "hi"` points at it; writing through `s` is
    undefined, as in C.
  - Adjacent literals join, and the escapes are C's.
  - `"""` on its own lines (#115, #118) is the same over any number of
    lines, with the text exactly as written, no escapes and no
    `${...}`.
  - Every way of quoting text, these, the template and the `$` forms
    that make a `String`, is in
    [grammar.md](grammar.md#quoting-text).
- **A byte array**, `[u8](N)` or `[u8]` filled from a literal, is a
  value with a count.
  - `let t:[u8] = "hi"` has `t.count` 3, the NUL included, and its
    bytes may change if it is a `var`.
  - It is an array, so `t.size` is its bytes, `for c in t` stops at the
    first NUL or at its end, and passing it to a function makes a
    pointer, as C does. See [arrays.md](arrays.md).
- **The text of a property or a template** (`n.cstr`, `n.hex`, a
  template literal) is written into a buffer on the stack of the
  enclosing block, with nothing on the heap and nothing to free, and
  lives until the block ends.
  - Keeping it longer, by returning it or assigning it to a variable
    of an outer block, is an error that says to copy it, as with
    `strdup`.
  - See [properties.md](properties.md) and [printing.md](printing.md).

### `u8` and C's `char` mix freely *(provisional P13)*

C string literals are `char` arrays, and libc takes `char *`. Kelvin's `u8`
is `unsigned char`, which has the same size, representation and ABI.

So `let s:u8^ := "hi"` and passing a `u8^` to `strlen` just work. kelvinc
silences C's pointer-sign warnings about the mix, and emits `main`'s `argv`
as `char **`, because C requires that.

`argv` is `[cstr]` or `u8^^` in `main`, and kelvinc writes C's
`char **` for it. A C function with `char` parameters does not match a
Kelvin function type with `u8^` ones, since C's `char` and `unsigned
char` make incompatible function types: wrap it, as
[functions.md](functions.md) shows.

## Making text

- **`x.cstr`** is any value's text: `42`, `-7`, `true`, `0.10000000000000001`
  (lossless), a struct's `{x: 3, y: 4}`.
  - Of a string it is the string itself.
  - `n.dec`, `n.hex`, `n.oct` and `n.bin` are an integer's text with a
    prefix and, for a signed one, a sign; `p.hex` an address's.
  - Each lives on the stack of the block.
- **`String(n)`** of a number or a bool is its text as `print` shows
  it, a String on the heap: `String(42)`, `String(2.5 * 2.0)` (#158).
- **A template literal**, `` `n = ${n}` ``, joins text and values as
  `print` shows them, on the stack too, with room for each value's
  longest text.
  - A string value longer than 256 bytes is cut with `...` (#44).
  - Its escapes, and the other ways to quote text, are in
    [grammar.md](grammar.md#quoting-text).
- **A buffer you own**, `var line = [u8](256)`, takes C's own writers:
  `fgets(line, line.size, stdin)`, `snprintf(line, line.size, ...)`,
  `strcpy`. `line.size` is its bytes, as `sizeof line` is.
- **To keep text** past its block, copy it: `let kept:cstr := strdup(d)`,
  and `free` it as in C. Kelvin adds no heap use of its own.

## Reading numbers from text

A converter reads a number from text (#36): `i64("42")`, `f64("1.5")`,
`i32("755", 8)` with a base from 2 to 36, and the same as a property,
`"42".i64`, `s.f64`.

- **The text** may be a literal, a `cstr`, a `u8^` or `i8^`, a byte
  array, the text of a property, or C's `char *`.
  - A `String` or a `Bytes` in a variable too, read through its text
    (#88): `i64(line)` of a line an IO gives.
- **They read** as `strtol` and `strtod` do: leading spaces and a sign,
  the longest number, 0 for none, and the type's limits with `errno`
  set.
- See [integers.md](integers.md) for the table.

## Walking and indexing

<!-- fragment -->
```kelvin
for c in s { ... }            // each byte of s, up to the NUL (#30)
for arg in argv { ... }       // each string, up to nullptr
s[0], s^                      // the first byte, a u8
var p := s; p := p.next       // a pointer stepped by one byte (#26)
```

- `for c in s` gives each `u8` up to the first 0, and `for arg in argv`
  each pointer up to `nullptr`.
- `c` is a `u8`, so `c == 'a'` compares bytes and `c.cstr` is its
  number's text, not the character.
- A string is evaluated once and does not move. See
  [flow-controls.md](flow-controls.md).

## Comparing

`==` between two `cstr` compares the pointers, as in C. Compare text
with `strcmp(a, b) == 0`, and a string with `nullptr` by `s.isNull` or
`s == nullptr`; a literal is never null.

## Printing

- `print` and `println` show a `u8^`, a `cstr` and a string literal as
  their text, and `(null)` for a null pointer.
- A single `u8` prints as a number, as every integer does:
  `println(s[0])` prints `104` for `h`, and `println(s.hex)` its
  address.
- In a template, `${s}` is the text and `${s.addr}` the address. See
  [printing.md](printing.md).

## `String`: text on the heap

A `cstr` is C's text, where it is. `String` (#55) is text on the heap,
that grows: a `Bytes` ([bytes.md](bytes.md)) that holds well-formed
UTF-8, counted and walked by codepoint.

It is an owner: freed when its block ends, moved by `return` and by
passing, copied only by `.copy()`, borrowed as a pointer. The rules are
in [ownership.md](ownership.md); this is the summary.

<!-- fragment -->
```kelvin
var s = $"héllo"                 // String("héllo"); String() is empty
s += ", world"                   // append text; also s.append(...)
s += t.copy()                    // a String's text; s += &t borrows it
println(s, " ", s.count)         // the text, and its codepoints: 12
for c in s { print(c.utf32, " ") }   // each codepoint, a uchr
let p := s.cstr                  // a borrow of the text, NUL-ended, for C
var line = $`${s} has ${s.count} codepoints`   // a String built from a template (#67)
```

- **Making one:** `$"text"` or `String("text")`, `String(s)` of a
  `cstr` or a byte array, `String(&b)` or `b.string()` of a `Bytes`,
  all checked for UTF-8.
  - Where a String is expected, a string literal becomes one by itself
    (#70): `var s:String = "x"`, `s = "y"`, a member, an element or an
    entry written as `"text"`.
  - `` $`a${x}b` `` from a template, with no bound on its length.
  - A `Bytes` is made its own ways, `Bytes("text")`, `Bytes([...])`,
    `Bytes.fromBase64(text)`: [bytes.md](bytes.md).
- **Methods:** `append` (also `+=`, of text, a borrow `&t`, a `uchr`,
  or a String an expression gives), `clear`, `reserve`, `compact`,
  `copy`, `escape` and `unescape`.
- **`s + t`** (#183) is a new String of the two, either side a String,
  text or a `uchr`, one a String: `s + "!"`, `"x" + s`, `s + t + u`. A
  String in a variable is copied and stays; one an expression gives is
  taken, so that a chain frees what it made. `s += t` still appends in
  place, and a number is shown with a template, `` $`${n}` ``.
- **Searching** (#177): `s.find(text)` is the codepoint index of the
  first `text` in `s`, or -1; `s.has(text)`, `s.starts(text)` and
  `s.ends(text)` are whether it is there, at the start, at the end;
  the text a `cstr` or a String borrowed, `s.find(&t)`.
- **`s.trim()`** is a new String without the blanks at either end,
  the spaces, tabs and line ends JS's `\s` lists, U+3000 among them.
- **Properties:** `count` (the codepoints), `cstr` (a borrow of the
  text), `bytes` (its Bytes, read only), `size`, `typename`.
- **Walking:** `for c in s` gives each codepoint as a `uchr`, which
  prints as its character; `for x in s.bytes^` each byte.
- **Slices** (#68): `s[lo..<hi]`, `s[lo...hi]`, `s[lo...]`, `s[..<hi]`
  and `s[...hi]` are new Strings of those codepoints; a range past the
  count ends the program.
- **Comparing:** `==` and `!=` compare two Strings by their bytes.
- **Not yet:** `insert` and `remove` on a String, encodings other than
  UTF-8.

## What is not here yet

`insert` and `remove` on a String, and encodings other than UTF-8, are
to come.

- A `cstr` is C's bytes, with C's rules: a NUL ends it, nothing checks
  a bound, and one that points at freed or ended storage is as wrong as
  in C.
- A `String` is checked, and freed when its block ends.

## Properties and methods

| On | Property or method | Gives |
|---|---|---|
| `cstr`, a literal | `.count` | `strlen`, measured once per scope (#52) |
| `"""text"""` | | a literal over lines, as written, no escapes (#115); the spellings of text are in [grammar.md](grammar.md#quoting-text) |
| | `.cstr` | the text itself |
| | `.i64`, `.f64`, ... | a number read from the text; `i64(s, 16)` in a base |
| | `.size`, `.typename`, `.addr`, `.hex`, `.isNull` | as a pointer's |
| | `for c in s`, `s[i]` | each byte; a byte, unchecked, as C has it |
| `String` | `.count` | the codepoints, kept with the text |
| | `.bytes` | its Bytes, a read-only borrow ([bytes.md](bytes.md)) |
| | `.cstr` | a borrow of the text |
| | `.append(x)`, `+=` | text, a `uchr`, `&other`, or a String an expression gives |
| | `.clear()`, `.reserve(n)`, `.compact()`, `.copy()` | changes in place; a new String |
| | `s + t` | a new String of the two, a String, text or a `uchr` on either side (#183) |
| | `.find(text)`, `.find(&t)` | the codepoint index of the first `text`, or -1 (#177) |
| | `.has(text)`, `.starts(text)`, `.ends(text)` | whether `text` is there, at the start, at the end; `&t` too |
| | `.trim()` | a new String without the blanks at either end |
| | `.escape()` | the text with each codepoint beyond ASCII as `\u{...}`, and a `\` as `\\`, a new String (#164); with `#import <RegExp>`, `.escape(&re)` escapes what `re` matches instead |
| | `.unescape()` | the escapes read back: `\u{...}`, `\uHHHH` (a surrogate pair joined), `\xHH`, `\n`, `\r`, `\t`, `\0`, `\\`, `\"`, `\'`; what is none stays as written; with `#import <RegExp>`, `.unescape(&re)` reads back what `re` matches alone (#165) |
| | `for c in s` | each codepoint, a `uchr` |
| | `s[lo..<hi]` | a slice by codepoint, a new String (#68); `s[i]` is an error |
| | `.normalize(nfc)`, `.graphemes`, `.upper()`, `.lower()`, `.fold()` | with `#import <UnicodeData>` (#156): [unicodedata.md](unicodedata.md) |
| | `.test(&re)`, `.search(&re)`, `.match(&re)`, `.replace(&re, with)`, `.split(&re)` | with `#import <RegExp>` (#157), `re` a `$/.../`: [regexp.md](regexp.md) |
| | `==`, `!=` | by the bytes |
| `uchr` | `.utf32`, `.codepoint` | the number, a `u32` (#56) |
| | `.cstr` | the character as UTF-8 text |
| | `<`, `==` and the rest | with a `uchr` or a number |
| all | `.size`, `.typename` | as any value's |

The ownership rules are in [ownership.md](ownership.md), the general
properties in [properties.md](properties.md).
