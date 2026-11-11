# cstr: C's text

`cstr` is C's text, where it is: bytes up to a NUL, which Kelvin reads as text and never writes through.

## Synopsis

```swift
let c:cstr := "hello"                 // a pointer to static text: const char * in C
let n:int64 = 42
let d:cstr := n.cstr                  // "42", in a buffer on this block's stack
let t:[uint8] = "hello"               // a copy in an array of six bytes, NUL included
println(c, " ", c.count, " ", d, " ", t.count, " ", c[0])   // hello 5 42 6 104
```

## Description

Text in Kelvin is C's, or Kelvin's own. C's is a pointer to bytes that
end at a NUL, and it is more than a zero-terminated `[u8]`: a string
literal, a byte array, a `cstr` and the text a property or a template
makes are four different things in C, which Kelvin keeps apart.

This document says how Kelvin spells each kind, makes it, reads it,
walks it, compares it and prints it. Kelvin's own text, `String`, is in
[strings.md](strings.md).

### How it differs from `String`

| | `cstr` | `String` ([strings.md](strings.md)) |
|---|---|---|
| What | a pointer to C's bytes, up to a NUL | UTF-8 on the heap, checked (#55) |
| Owned | no: it points at text that lives elsewhere | yes: freed when its block ends, moved, copied by `.copy()` |
| Changes | never through it (#52) | grows: `s += t`, `s.append(x)` |
| A NUL | ends it | is a character it may hold (#299) |
| Elements | bytes, `u8`, by `for c in s` and `s[i]` | graphemes, each a String (#522) |
| `.count` | its bytes, `strlen`, kept per scope | its graphemes, O(n) |
| `==` | the pointers, as in C | the text, by its bytes |
| Assigned | with `:=`, a reference | with `=`, a value |

- A literal is a `cstr`, and becomes a String where one is expected
  (#70): `var s:String = "x"`.
- `$"text"` is a String, `s.cstr` a borrow of a String's text for C.

### Four kinds of text

```swift
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
  - It is a reference: assign it with `:=`, compare it with `nowhere`
    or `.isNull`, and its `.size` is a pointer's size, 8 on a 64-bit
    target.
  - `s.count` is its length, the bytes before the NUL: `strlen(s)`.
    - It is measured at the first use and kept for the rest of the
      scope in a `_kv_` variable, declared only where `.count` is used;
      after `s := t`, the next use measures again.
  - `cstr const` is a constant pointer.
  - It has no `+` or `-`, a literal too (#282).
    - Only a `String` has `+`: `"a" + "b"` and `x + y` are errors;
      `$"a" + "b"` is the String `"ab"`, and so is `"a" + $"b"`.
    - It is text, not a cursor (#52): `"a" + 1`, `s + 2` and `x - y`
      are errors; take a `var p:u8^ := s` to step.
    - Adjacent literals are one, as in C: `"a" "b"` is `"ab"`.
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

#### `u8` and C's `char` mix freely *(provisional P13)*

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

### Making text

- **`x.cstr`** is any value's text: `42`, `-7`, `true`,
  `0.10000000000000001` (as `print` shows it, #259), a struct's
  `{x: 3, y: 4}`, its text members quoted, `{tag: "edge"}`.
  - Of a string it is the string itself.
  - `n.dec`, `n.hex`, `n.oct` and `n.bin` are an integer's text with a
    prefix and, for a signed one, a sign; `p.hex` an address's.
  - Each lives on the stack of the block.
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
  and `free` it as in C, or make a String of it, `String(d)`, which its
  block frees.

### Reading numbers from text

A converter reads a number from text (#36): `i64("42")`, `f64("1.5")`,
`i32("755", 8)` with a base from 2 to 36, and the same as a property,
`"42".i64`, `s.f64`.

- **The text** may be a literal, a `cstr`, a `u8^` or `i8^`, a byte
  array, the text of a property, or C's `char *`.
  - A `String` or a `Bytes` in a variable too, read through its text
    (#88): `i64(line)` of a line an IO gives.
  - One by reference too, `i64(&s)` or `i64(r)` of a `String^`, as
    `i64(s)` (#495).
- **They read** as `strtol` and `strtod` do: leading spaces and a sign,
  the longest number, 0 for none, and the type's limits with `errno`
  set.
- **Of a struct**, a converter is its attribute of that name (#512):
  `i64(b)` of a BigInt is `b.i64`, as `i64(s)` and `s.i64` of text are
  one; a struct without the attribute is an error in words.
- See [integers.md](integers.md) for the table.

### Walking and indexing

<!-- fragment -->
```swift
for c in s { ... }            // each byte of s, up to the NUL (#30)
for arg in argv { ... }       // each string, up to nowhere
s[0], s^                      // the first byte, a u8
var p := s; p := p.next       // a pointer stepped by one byte (#26)
```

- `for c in s` gives each `u8` up to the first 0, and `for arg in argv`
  each pointer up to `nowhere`.
- `c` is a `u8`, so `c == 'a'` compares bytes and `c.cstr` is its
  number's text, not the character.
- A string is evaluated once and does not move. See
  [flow-controls.md](flow-controls.md).

### Comparing

`==` between two `cstr` compares the pointers, as in C. Compare text
with `strcmp(a, b) == 0`, and a string with `nowhere` by `s.isNull` or
`s == nowhere`; a literal is never null.

- A String compares its text with a `cstr` by `==` (#522):
  `$"abc" == s`, [strings.md](strings.md).

### Printing

- `print` and `println` show a `u8^`, a `cstr` and a string literal as
  their text, and `nowhere` for a null pointer (#260).
- A single `u8` prints as a number, as every integer does:
  `println(s[0])` prints `104` for `h`, and `println(s.hex)` its
  address.
- In a template, `${s}` is the text and `${s.addr}` the address. See
  [printing.md](printing.md).

### What is not here

A `cstr` is C's bytes, with C's rules: a NUL ends it, nothing checks a
bound, and one that points at freed or ended storage is as wrong as in
C. A `String` is checked, and freed when its block ends.

## Where it lives

The core: C's text, with kelvinc's rules and nothing linked, but for the text of a property, which the prelude writes.

## Properties and methods

| On | Property or method | Gives |
|---|---|---|
| `cstr`, a literal | `.count` | `strlen`, measured once per scope (#52) |
| | `.isEmpty` | whether its first byte is its NUL, `.count == 0` without measuring, a `bool` (#434) |
| | `.cstr` | the text itself |
| | `.i64`, `.f64`, ... | a number read from the text; `i64(s, 16)` in a base |
| | `i64(s)`, `i64(&s)`, `f64(s)`, ... | the same, of a String by value or by reference (#88, #495) |
| | `.size`, `.typename`, `.addr`, `.hex`, `.isNull` | as a pointer's |
| | `for c in s`, `s[i]` | each byte; a byte, unchecked, as C has it |
| | `==`, `!=` | the pointers, as in C; with a String, the text (#522) |
| `"""text"""` | | a literal over lines, as written, no escapes (#115); the spellings of text are in [grammar.md](grammar.md#quoting-text) |
| a byte array `[u8]` | `.count`, `.size` | its bytes, the NUL included ([arrays.md](arrays.md)) |

The general properties are in [properties.md](properties.md).
