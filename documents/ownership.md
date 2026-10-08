# Ownership: `Bytes` and `String`

Kelvin used no heap of its own until #54. `Bytes` is the first type that
does: a growable array of `u8` that a variable *owns*, and that the
variable's block frees; `String` (#55) is a `Bytes` that holds UTF-8. The rules below are what kelvinc enforces, from
what it sees; a copy of the struct through C is C's business, and
harmless, since an owner is never copied implicitly. `Array`
and `Dictionary` are to follow the same rules.

## `Bytes`

```kelvin
var b = Bytes("hello, ")     // a copy of the text, on the heap
b += "Kelvin"                // append: text, a byte, a borrow, a Bytes
b.append('!')
println(b, " ", b.count, " ", b.capacity)   // hello, Kelvin! 14 16
let c = b.copy()             // a copy of the bytes; a let cannot change
b.insert(0, ">> ")
b.remove(0, 3)
println(b == c, " ", b[0], " ", c.cstr)     // true 104 hello, Kelvin!
var z = Bytes(4)             // four zero bytes
for x in b { print(x, " ") } // each byte, count of them, NULs included
```

- **Making one:** `Bytes()` is empty; `Bytes(n)` is n zero bytes;
  `Bytes("text")`, `Bytes(s)` of a `cstr` or a byte array copies the
  text up to its NUL; `Bytes(&b)` copies another; `Bytes(p, n)` copies
  n bytes at `p`. `var b:Bytes` without a value is empty.
- **In C** it is `struct kv_bytes { uint8_t *at; size_t count, cap; }`,
  with no hidden header, and `at[count]` is always a NUL that `count`
  does not count, so `b.cstr` is a borrow of its text in O(1), which
  every C function taking `const char *` accepts; the bytes themselves
  may hold NULs. An empty `Bytes` has nothing on the heap.
- **Properties:** `b.count` the bytes, `b.capacity` the room,
  `b.cstr` the text as a `cstr`, `b.at` the bytes as a `u8^` (a
  `const u8^` for a let), `b.size` C's `sizeof`, 24. `b.typename` is
  `Bytes`.
- **Methods:** `append(x)`, also `b += x`, where `x` is a byte, text (a
  literal, a `cstr`, a `[u8]`), a borrow `&other`, or a `Bytes` an
  expression gives (which is appended and freed); `insert(i, x)` of the
  same; `remove(i, n)`; `clear()`; `reserve(n)`; `compact()`, which
  gives back the room beyond the count; `copy()`.
- **`b[i]`** is checked: `i` at or past `b.count` ends the program with
  a message. `b.at[i]` is C's, unchecked. `b[i] = v` writes, for a var.
- **`==` and `!=`** compare the bytes of two `Bytes` in variables. No
  other operator takes one.
- **Printing:** `print(b)` and `${b}` show the bytes as text; in a
  template, a struct's text and `.cstr` it is cut as a string is (#44,
  P35); `print` writes every byte.
- **Growth** doubles the capacity from 16; out of memory ends the
  program with a message, as an index out of range does.

## `String`

A `String` is a sequence of Unicode codepoints, kept as UTF-8 in a
`Bytes` with its count of codepoints, and an owner under the same rules
(#55). Malformed text is refused: where a `String` is made or appended
from bytes that are not well-formed UTF-8 (overlong forms, surrogates,
anything past U+10FFFF), the program ends with a message.

```kelvin
var s = String("héllo, κόσμε")  // text, checked
s += " 🌍"                      // text, a codepoint, &other, or a String an expression gives
s.append(0x1F600)
println(s, " ", s.count, " ", s.bytes^.count)   // héllo, κόσμε 🌍😀 15 27
for c in s { if c > 127 { ... } }                // each codepoint, a uchr
let t = s.copy()
println(s == t, " ", t.cstr)
let u = b.string()               // a Bytes, checked; b.isUTF8 asks first
```

- **Making one:** `String()` is empty; `String("text")`, `String(s)`
  of a `cstr` or a byte array, and `String(&b)` of a `Bytes` copy and
  check the text; `b.string()` is the same as `String(&b)`, and
  `b.isUTF8` says whether it would pass.
- **Properties:** `s.count` the codepoints, kept with the text, so it
  costs nothing; `s.bytes` a read-only borrow of the bytes, a
  `const Bytes^`, with `s.bytes^.count` the bytes and `s.bytes^[i]` a
  byte; `s.cstr` the text; `s.size` 32.
- **Methods:** `append(x)`, also `s += x`, where `x` is text, a
  `uchr` or a codepoint as a number (a surrogate or a number past
  U+10FFFF ends the program), a borrow `&other`, or a `String` an
  expression gives; `clear()`, `reserve(n)`, `compact()`, `copy()`.
  There is no `insert` or `remove` yet, and no `s[i]`: a position in a
  `String` is a walk, so write `for c in s`, or index the bytes.
- **`==` and `!=`** compare two `String`s in variables, by their bytes.
- A `Bytes` takes a `String` through `s.bytes`; a `String` takes a
  `Bytes` through `b.string()` or, up to a NUL, `b.cstr`; a borrow of
  the other kind is an error that says so.
- **`uchr`** is a codepoint on the stack (#56), a value type of four
  bytes: `for c in s` gives one, `uchr("é")` is the first codepoint of
  text, `n.uchr` and `uchr(n)` make one of a number, U+FFFD, the
  replacement character, where it is none. `print(c)`, `${c}` and
  `c.cstr` show it as its UTF-8; `c.utf32`, or `c.codepoint`, is the
  number, a `u32`, as `u32(c)` and `i64(c)` are. It compares with `==`,
  `<` and the rest, with a `uchr` or a number (`c == 'a'`), and has no
  arithmetic: `c.utf32 + 1`. `s += c` appends it.

## The rules

| | Rule |
|---|------|
| **O1** | **A `Bytes` owns its heap**, and so does a struct that holds one. |
| **O2** | **A variable owns it, and its block frees it.** When the block ends, by its `}`, a `return`, a `break` or a `goto` out of it, the owner is freed: C's `cleanup` attribute, which gcc and clang have, and which rejects a `goto` into the block past the owner. A global owner lives for the program. A `let` owner cannot change. |
| **O3** | **An owner is never copied by `=`.** `var c = b` and `c = b` are errors with two hints: `b.copy()` for a copy of the bytes, `:= &b` for a borrow. The same holds for a member of a struct, in an initializer list too. |
| **O4** | **`return b` moves.** The caller owns it; the callee's variable is empty when it is freed. A `Bytes` a function gives is bound (`let b = f()`), assigned (`b = f()`), returned, passed, or dropped as a statement, which frees it at once; used otherwise (`f().count`) it is an error that says to bind it. |
| **O5** | **Passing by value moves.** `take(b)` with `let take(d:Bytes)` hands the heap to `d`, which the callee's block frees; afterwards `b` is dead for the rest of its block, and using it is an error, until `b = Bytes()` or another value is assigned. kelvinc tracks this without flow analysis: a move anywhere in a block, also inside an `if`, kills the name for what follows in the enclosing block. A global owner does not move. A member, `take(v.b)`, does not move alone: pass a borrow or a copy. |
| **O6** | **A borrow is a pointer**, `let r := &b`, a `Bytes^`, with the rules text has (#39, #44): a borrow of a local owner may not be returned, or assigned to a variable of an outer block. Through a borrow of a var, the methods that change it work: `r^.append("x")`. A function reads an owner through `d:Bytes^` and takes it through `d:Bytes`. |
| **O7** | **A struct that holds an owner owns it.** `struct msg { body: Bytes }` gets a derived `_kv_msg_free`, as it gets a derived `.cstr`; a local of that type is freed at its block's end, and O3 to O5 apply to it. An array member of owners is freed too. A union may not hold an owner, and an array of owners as a variable waits for its own change. |
| **O8** | **C sees pointers, not owners.** Passing a `Bytes` by value to a function kelvinc cannot see (a C function) is an error: pass `b.at` and `b.count`, or `b.cstr`. `print` and `println` take one. |
| **O9** | **Failure aborts.** Out of memory, and an index out of range, end the program with a message. |
| **O10** | **The C stays small.** `--emit-c` shows ordinary C: `__attribute__((cleanup(kv_bytes_free))) kv_bytes b = ...`, `kv_bytes_take(&b)` where it moves, `kv_bytes_assign(&b, v)` where it takes a value, and a `_kv_T_free` for a struct that owns. |

```kelvin
let greeting(name:cstr):Bytes {      // the caller owns the result
    var b = Bytes("hello, ")
    b += name
    return b                         // moves out
}
let total(data:Bytes):i64 {          // data moves in, and is freed here
    var n = 0
    for x in data { n += i64(x) }
    return n
}
let longest(a:Bytes^, b:Bytes^):Bytes^ { a^.count >= b^.count ? a : b }   // borrows
```

Not yet: an array of owners as a variable, `Array` and `Dictionary`,
`insert` and `remove` on a `String`, and sharing one owner from two
places, which would be an explicit type of its own if it is ever
needed.
