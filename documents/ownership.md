# Ownership: `Bytes`, `String`, `Array<T>` and `Dictionary<K, V>`

Kelvin used no heap of its own until #54. `Bytes` is the first type that
does: a growable array of `u8` that a variable *owns*, and that the
variable's block frees; `String` (#55) is a `Bytes` that holds UTF-8;
`Array<T>` (#57) is a growable array of any value type; `Dictionary<K,
V>` (#65) is a hash map. The rules below are what kelvinc enforces, from
what it sees; a copy of the struct through C is C's business, and
harmless, since an owner is never copied implicitly. `Dictionary` (#65) follows the same rules.

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

- **Making one:** `String()` is empty; `String("text")`, or `$"text"`
  for short (#62), `String(s)` of a `cstr` or a byte array, and
  `String(&b)` of a `Bytes` copy and check the text; `b.string()` is the same as `String(&b)`, and
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

## `Array<T>`

`Array<T>` is a growable array of `T` on the heap, an owner under the
same rules (#57). `T` is any value type: a number, a `bool`, a `uchr`,
a pointer, a `cstr`, a struct that owns nothing, or an owner among
`Bytes`, `String` and `Array<U>`, which the Array then owns: freed with
it, copied by `copy()`, and never copied by `=`.

```kelvin
var xs = Array<i64>()            // empty; Array<i64>(n) is n zero elements
var va = Array([0, 1, 2, 3])     // the elements, T inferred from them; or Array<i64>([0, 1, 2, 3])
var vb = $[0, 1, 2, 3]            // the same, for short; $"text" is String("text")
var vc:$[[i64]] = $[[1, 0], [0, 1]]   // $[T] is the type Array<T>, $[[T]] Array<Array<T>>
var m = Array([[0], [1, 2]])     // a [...] among the elements is an Array in turn: an Array<Array<i64>>
for i in 0..<5 { xs += i * i }   // append: an element, &other (its elements), an Array an expression gives
xs.insert(0, 100)
xs.remove(1, 2)
let last = xs.pop()
println(xs.count, " ", xs[0], " ", xs.capacity)
let ys = Array(fixed)            // a copy of a fixed array, [i64](3); Array(&xs) a copy of an Array
for x in xs { ... }              // each element, a let
var rows = Array<Array<i64>>()   // Arrays of Arrays, of Strings, of Bytes
rows += Array<i64>(3)            // moved in
rows[0][1] = 5                   // xs[i] = v frees the element it replaces, if it owns
```

- **The type** is `Array<T>`, with the element type in angle brackets,
  or `$[T]` for short (#64): a variable's type, a parameter's
  (`xs:$[i64]` takes it, `xs:$[i64]^` borrows it), a result's, a
  struct member's. `Array<Array<i64>>` nests, and so does `$[[i64]]`,
  where a `[...]` inside is an Array in turn, as it is in `$[[1, 0],
  [0, 1]]`; a fixed array is never an element. `Array<T>` with no
  `(...)` after it is a type, not a value.
- **Making one:** `Array<T>()` is empty; `Array<T>(n)` is n zero
  elements (empty owners, for an Array of owners); `Array([a, b, c])`,
  or `$[a, b, c]` for short (#62), holds the elements written, with `T` inferred from them as a
  variable's type is (#47, #48), or given, `Array<T>([a, b, c])`; a
  `[...]` among the elements is an Array in turn, so `Array([[0], [1,
  2]])` is an `Array<Array<i64>>`, never a fixed array;
  `Array(a)` of a fixed array `[T](N)` copies its elements;
  `Array(&other)` copies another; `T` may be written before `(` in
  every form, and must be when nothing gives it: `Array()` and
  `Array(n)` are errors. `var xs:Array<T>` without a value is empty.
  An owner written among the elements is moved in (`Array([String("a")])`);
  a variable that owns is not copied there, as `=` does not copy it.
- **Properties:** `xs.count`, `xs.capacity`, `xs.at` the elements as a
  `T^` (`const T^` for a let), `xs.size` C's `sizeof`, 24,
  `xs.typename` `Array<T>`.
- **Methods:** `append(x)`, also `xs += x`, where `x` is an element, a
  borrow `&other` of the same `Array<T>` (its elements are appended, a
  copy each), or an `Array<T>` an expression gives (its elements are
  moved in); `insert(i, x)` of an element; `remove(i, n)`; `pop()`,
  the last element, moved out; `clear()`; `reserve(n)`; `compact()`;
  `copy()`.
- **`xs[i]`** is checked; `i` at or past `xs.count` ends the program
  with a message. It is a place: `xs[i] = v` writes, and frees the
  element it replaces if it owns; `let y = xs[i]` of an owner is an
  error (copy it, or borrow it); `xs.at[i]` is C's, unchecked.
  `xs[lo..<hi]` and friends are slices, copies (#68, [arrays.md](arrays.md)).
- **`for x in xs`** gives each element as a let: a copy of a plain
  value, and of an owner a view the Array still owns, which cannot be
  moved or returned, only borrowed (`&x`) or copied.
- **In C**, each `Array<T>` of a program is one struct `{at, count,
  cap}` and its functions, from a macro in the prelude, named by its
  element type (`_kv_array_i64`, `_kv_array_Array_i64`), emitted before
  the first top-level declaration that uses it: generics for one
  built-in type, not a language feature.
- **Not yet:** text (`print(xs)`, `${xs}` and `.cstr` are errors:
  show the elements), `==` (compare the elements), an element that is
  an array (`[T](N)`), sorting and searching. An element that is a
  struct that owns, or an enum with values, is copied and freed with
  the Array (#61).

## `Dictionary<K, V>`

`Dictionary<K, V>` is a hash map on the heap, an owner under the same
rules (#65): `K` an integer type or `String`, `V` any value an Array
holds. Its entries keep the order they were added in.

```kelvin
var ages = ${"ann": 31, "bob": 42}       // Dictionary<String, i64>; ${K: V} is the type
ages["cy"] = 7                           // adds, or replaces the value
ages["ann"] += 1                         // a place, checked: the key must be there
println(ages["bob"], " ", ages.count, " ", ages.has("dan"))
for k, v in ages { print(k, "=", v, " ") }   // ann=32 bob=42 cy=7
let p := ages.find("zed")                // a V^, or nullptr
if !p.isNull { println(p^) }
println(ages.get("zed", -1))             // a value, or the default
ages.remove("bob")                       // true if it was there
var words:${String: $[String]} = ${:}    // empty; a value may own
words["a"] = $[$"apple"]
```

- **The type** is `Dictionary<K, V>`, or `${K: V}` for short. `K` is an
  integer type, hashed as a number, or `String`: the Dictionary keeps a
  copy of the text, and is read with a `cstr`, a template or a String.
  A `cstr` key is an error that says so. `V` is any value an Array may
  hold, owners included, which the Dictionary then owns.
- **Making one:** `${k: v, ...}` holds the entries written, `K` and
  `V` inferred from the first as a variable's type is; `${:}` is empty
  where the type is known, as in `var d:${String: i64} = ${:}`;
  `Dictionary<K, V>()`, `Dictionary<K, V>({k: v, ...})`, and
  `Dictionary<K, V>(&other)`, a copy. A variable declared without a
  value is empty.
- **`d[k]`** reads the value, and ends the program with a message if
  the key is not there, as `xs[i]` does out of range; it is a place, so
  `d[k] += 1` and `d[k] += "x"` change it. `d[k] = v` adds the entry or
  replaces its value, freeing what it held if it owns; `=` does not copy
  an owner in, as it copies none (#54): `d[k] = s.copy()`.
- **Methods:** `has(k)`; `find(k)`, a `V^` to the value or `nullptr`
  (`const V^` for a let); `get(k, default)`, the value or the default,
  for a `V` that does not own; `remove(k)`, true if it was there;
  `clear()`; `reserve(n)`; `copy()`. **Properties:** `count`, `size`,
  `typename`.
- **`for k, v in d`** walks the entries in the order they were added,
  `k` and `v` lets that the Dictionary owns, as an Array's elements are
  in `for x in xs`; `for k in d` walks the keys.
- **In C**, each `Dictionary<K, V>` is one struct and its functions from
  the prelude's `KV_DICT`, named `_kv_dict_<K>_<V>`: an entries array
  in order, a chain per bucket, twice as many buckets as entries, the
  keys' hashes kept; growth doubles from 16 and compacts removed
  entries.
- **Not yet:** text (`print(d)` and `${d}` are errors: show the
  entries), `==`, keys of other types, `keys` and `values` as Arrays,
  and `d[k, default]`.

## `Set<T>`

`Set<T>`, or `${T}`, is a hash set on the heap (#71): a Dictionary with
no values, under the same rules, keyed as a Dictionary is (an integer
type or `String`). `${3, 1, 4}` makes one, `s += x` and `s.insert(x)`
add, `s.has(x)` tests, `s.remove(x)` removes, `s.union(&t)`,
`s.intersection(&t)` and `s.difference(&t)` make new ones,
`s.elements` is an Array of copies, and `for x in s` walks it in the
order added. See [sets.md](sets.md).

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

A struct, or an enum with values (#61), that holds an owner is an owner
under the same rules, copied with `.copy()`, and may be an element of an
`Array<T>`.

Not yet: a fixed array of owners as a variable (`[Bytes](4)`; an
`Array<Bytes>` grows), `insert` and `remove` on a `String`, slices that
borrow rather than copy, and sharing one owner from two places, which
would be an explicit type of its own if it is ever needed.
