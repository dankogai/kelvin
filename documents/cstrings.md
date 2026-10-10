# C strings: `cstr`

A C string is a pointer to bytes that end at a NUL. Kelvin has no string
type yet (`String`, `toString()` and `fmt()` are shelved until it does,
#22), so text is C's, and this document says how Kelvin spells it, makes
it, reads it, walks it and prints it, and where it lives. It is more than
a zero-terminated `[u8]`: a string literal, a byte array, a `cstr` and
the text a property or a template makes are four different things in C,
and Kelvin keeps them apart.

## Four kinds of text

```kelvin
let s:cstr := "hello"        // a pointer to static text: const char * in C
let t:[u8] = "hello"         // a copy in an array of six bytes, NUL included
var buf = [u8](64)           // 64 zero bytes to write into
let n:i64 = 42
let d:cstr := n.cstr         // "42", in a buffer on this block's stack
let card:cstr := `${n} items` // a template's text, on the stack too
```

- **`cstr`** is immutable text (#52): in C a `const uint8_t *`, a
  pointer to bytes that never change through it, which Kelvin treats as
  text rather than as a pointer. It is a reference: assign it with
  `:=`, compare it with `nullptr` or `.isNull`, and its `.size` is a
  pointer's size, 8 on a 64-bit target. `s.count` is its length, the
  bytes before the NUL: `strlen(s)`, measured at the first use and kept
  for the rest of the scope in a `_kv_` variable, declared only where
  `.count` is used; after `s := t`, the next use measures again. `cstr
  const` is a constant pointer.
  - **It cannot be written through**: `s[0] = 'U'` and `s^ = 0` are
    errors. To change text, copy it into a byte array, `var t:[u8](n)`
    and `strcpy(t, s)`, or write through a `u8^`.
  - **It does not step**: `s++`, `s.next`, `s + 1` and `s += 1` are
    errors; walk it with `for c in s`, index it with `s[i]`, or take
    the rest of it with `&s[i]`, which is a `cstr` too.
  - **A `u8^` may still take it**, `var p:u8^ := s`, in a declaration,
    a `:=`, an initializer list or a call of a Kelvin function with a
    `u8^` parameter: kelvinc writes the cast. This is allowed, not
    encouraged, and writing through `p` into a literal is C's undefined
    behavior. A C function that takes `char *` needs `s as u8^`, since
    kelvinc cannot see its parameters. The other way, a `u8^` or
    `const u8^` into a `cstr`, needs nothing.
  - **Prefer `cstr`** to `u8^` for text: a parameter `s:cstr` says the
    function reads it, a `u8^` that it may write; `argv` is `[cstr]`.
  - A string literal, the text of a property (`n.cstr`, `n.hex`) and a
    template are `cstr`, so `let s := "hi"` infers it.
- **A string literal** is C's: a `char` array that lives for the whole
  program, which decays to a pointer. `let s:cstr := "hi"` points at
  it; writing through `s` is undefined, as in C. Adjacent literals join,
  and the escapes are C's.
- **A byte array**, `[u8](N)` or `[u8]` filled from a literal, is a
  value with a count: `let t:[u8] = "hi"` has `t.count` 3, the NUL
  included, and its bytes may change if it is a `var`. It is an array,
  so `t.size` is its bytes, `for c in t` stops at the first NUL or at
  its end, and passing it to a function makes a pointer, as C does. See
  [arrays.md](arrays.md).
- **The text of a property or a template** (`n.cstr`, `n.hex`, a
  template literal) is written into a buffer on the stack of the
  enclosing block, with nothing on the heap and nothing to free, and
  lives until the block ends. Keeping it longer, by returning it or
  assigning it to a variable of an outer block, is an error that says
  to copy it, as with `strdup`. See [properties.md](properties.md) and
  [printing.md](printing.md).

### `u8` and C's `char` mix freely *(provisional P13)*

C string literals are `char` arrays, and libc takes `char *`. Kelvin's `u8`
is `unsigned char`, which has the same size, representation and ABI. So
`let s:u8^ := "hi"` and passing a `u8^` to `strlen` just work. kelvinc
silences C's pointer-sign warnings about the mix, and emits `main`'s `argv`
as `char **`, because C requires that.

`argv` is `[cstr]` or `u8^^` in `main`, and kelvinc writes C's
`char **` for it. A C function with `char` parameters does not match a
Kelvin function type with `u8^` ones, since C's `char` and `unsigned
char` make incompatible function types: wrap it, as
[functions.md](functions.md) shows.

## Making text

- **`x.cstr`** is any value's text: `42`, `-7`, `true`, `0.10000000000000001`
  (lossless), a struct's `{x: 3, y: 4}`. Of a string it is the string
  itself. `n.dec`, `n.hex`, `n.oct` and `n.bin` are an integer's text
  with a prefix and, for a signed one, a sign; `p.hex` an address's.
  Each lives on the stack of the block.
- **A template literal**, `` `n = ${n}` ``, joins text and values as
  `print` shows them, on the stack too, with room for each value's
  longest text; a string value longer than 256 bytes is cut with `...`
  (#44).
- **A buffer you own**, `var line = [u8](256)`, takes C's own writers:
  `fgets(line, line.size, stdin)`, `snprintf(line, line.size, ...)`,
  `strcpy`. `line.size` is its bytes, as `sizeof line` is.
- **To keep text** past its block, copy it: `let kept:cstr := strdup(d)`,
  and `free` it as in C. Kelvin adds no heap use of its own.

## Reading numbers from text

A converter reads a number from text (#36): `i64("42")`, `f64("1.5")`,
`i32("755", 8)` with a base from 2 to 36, and the same as a property,
`"42".i64`, `s.f64`. The text may be a literal, a `cstr`, a `u8^` or
`i8^`, a byte array, the text of a property, or C's `char *`. They read
as `strtol` and `strtod` do: leading spaces and a sign, the longest
number, 0 for none, and the type's limits with `errno` set. See
[integers.md](integers.md) for the table.

## Walking and indexing

```kelvin
for c in s { ... }            // each byte of s, up to the NUL (#30)
for arg in argv { ... }       // each string, up to nullptr
s[0], s^                      // the first byte, a u8
var p := s; p := p.next       // a pointer stepped by one byte (#26)
```

`for c in s` gives each `u8` up to the first 0, and `for arg in argv`
each pointer up to `nullptr`. `c` is a `u8`, so `c == 'a'` compares
bytes and `c.cstr` is its number's text, not the character. A string
is evaluated once and does not move. See
[flow-controls.md](flow-controls.md).

## Comparing

`==` between two `cstr` compares the pointers, as in C. Compare text
with `strcmp(a, b) == 0`, and a string with `nullptr` by `s.isNull` or
`s == nullptr`; a literal is never null.

## Printing

`print` and `println` show a `u8^`, a `cstr` and a string literal as
their text, and `(null)` for a null pointer. A single `u8` prints as a
number, as every integer does: `println(s[0])` prints `104` for `h`,
and `println(s.hex)` its address. In a template, `${s}` is the text
and `${s.addr}` the address. See [printing.md](printing.md).

## `Bytes` and `String`: text on the heap

A `cstr` is C's text, where it is. `Bytes` (#54) is text, or any bytes,
on the heap, that grows; `String` (#55) is a `Bytes` that holds
well-formed UTF-8, counted and walked by codepoint. Both are owners:
freed when their block ends, moved by `return` and by passing, copied
only by `.copy()`, borrowed as a pointer. The rules are in
[ownership.md](ownership.md); this is the summary.

```kelvin
var s = $"héllo"                 // String("héllo"); String() is empty
s += ", world"                   // append text; also s.append(...)
s += t.copy()                    // a String's text; s += &t borrows it
println(s, " ", s.count)         // the text, and its codepoints: 12
for c in s { print(c.utf32, " ") }   // each codepoint, a uchr
var b = Bytes("raw")             // bytes, indexed: b[0] is a u8, checked
let p := s.cstr                  // a borrow of the text, NUL-ended, for C
var line = $`${s} has ${s.count} codepoints`   // a String built from a template (#67)
```

- **Making one:** `$"text"` or `String("text")`, `String(s)` of a
  `cstr` or a byte array, `String(&b)` or `b.string()` of a `Bytes`,
  all checked for UTF-8; `` $`a${x}b` `` from a template, with no bound
  on its length; `Bytes("text")`, `Bytes(n)` of n zero bytes, `Bytes(p,
  n)` of bytes and their count.
- **Methods:** `append` (also `+=`, of text, a borrow `&t`, a `uchr`,
  or a String an expression gives), `clear`, `reserve`, `compact`,
  `copy`; a `Bytes` also `insert`, `remove` and `string()`.
- **Properties:** `count` (codepoints of a String, bytes of a Bytes),
  `cstr` (a borrow of the text), `bytes` (a String's Bytes, read only),
  `capacity`, `at` and `isUTF8` of a Bytes, `size`, `typename`.
- **Walking:** `for c in s` gives each codepoint as a `uchr`, which
  prints as its character; `for b in bytes` each byte.
- **Slices** (#68): `s[lo..<hi]`, `s[lo...hi]`, `s[lo...]`, `s[..<hi]`
  and `s[...hi]` are new Strings of those codepoints, a Bytes's of
  those bytes; a range past the count ends the program.
- **Comparing:** `==` and `!=` compare two Strings, or two Bytes, by
  their bytes.
- **Not yet:** searching, `insert` and `remove` on a String, encodings
  other than UTF-8.

## What is not here yet

Slicing, searching and encodings other than UTF-8 are to come. A
`cstr` is still C's bytes, with C's rules: a NUL ends it, nothing checks
a bound, and one that points at freed or ended storage is as wrong as
in C.
