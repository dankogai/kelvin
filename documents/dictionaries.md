# Dictionaries: `Dictionary<K, V>`

`Dictionary<K, V>`, or `${K: V}` for short, is a hash map on the heap
(#65): an owner, freed when its block ends, moved by `return` and by
passing, copied only by `.copy()`, borrowed as a pointer. The rules are
in [ownership.md](ownership.md); this is the summary.

**Where it lives:** the prelude. A Dictionary's C comes from `kelvin_prelude.h`, instantiated for each `K` and `V`, with hashing and the rest in `libkelvin`, linked without an import.

```swift
var ages = ${"ann": 31, "bob": 42}       // Dictionary<String, i64>
ages["cy"] = 7                           // adds, or replaces the value
ages["ann"] += 1                         // a place, checked: a missing key ends the program
println(ages["bob"], " ", ages["dan"])   // some(42) none: d[k] read whole is an Optional (#218)
println(ages["bob"]!, " ", ages["dan"] ?? 0, " ", ages.count, " ", ages.has("dan"))   // 42 0 3 false
for k, v in ages { print(k, "=", v, " ") }   // in the order added: ann=32 bob=42 cy=7
for k in ages { }                        // the keys
let p := ages.find("zed")                // a V^, or nullptr
if !p.isNull { println(p^) }
println(ages.get("zed", -1))             // the value, or a default
ages.remove("bob")                       // true if it was there
var names = ages.keys                    // an Array<String>, copies, in order
var counts = ages.values                 // an Array<i64>
var words:${String: $[String]} = ${:}    // empty; a value may own
words["a"] = $[$"apple"]
println(words["a"]?.count, " ", words["b"]?.count)   // some(1) none: x?.m chains (#218)
```

- **Keys** are an integer type, hashed as a number, or `String`.
  - The Dictionary keeps a copy of the text, and is read with a
    `cstr`, a template, or a String.
  - A `cstr` key type is an error that says so.
- **Values** are anything an Array holds, owners included, which the
  Dictionary then owns.
- **Making one:** `${k: v, ...}` with `K` and `V` inferred from the
  first entry.
  - `${:}` where the type is written; `Dictionary<K, V>()`; a
    declaration without a value is empty.
  - `Dictionary<K, V>({k: v, ...})`; `Dictionary<K, V>(&other)` a copy.
- **`d[k]` read whole is an Optional** (#218): `some` of a copy of the
  value, or `none` where the key is missing.
  - `d[k]!` is the value, or the end of the program; `d[k] ?? v` gives a
    default; `if let some(v) = d[k]` binds it. See
    [optionals.md](optionals.md).
  - `d[k]?.m`, `d[k]?.f(...)` and `d[k]?[i]` chain: `none` where the
    key is missing, else an Optional of what follows.
  - Going into it is a place, checked, as before: `d[k] = v`,
    `d[k] += 1`, `d[k].m`, `d[k][i]`, `&d[k]`, and `d[k]!`.
  - Where an Optional goes where a value should, kelvinc says so, and
    names `!` and `??`.
- **`d[k] = v`** adds the entry or replaces its value, freeing what it
  held if it owns.
  - `=` does not copy an owner in: `d[k] = s.copy()`.
  - The key may be a String an expression gives, `d[$"a"] = 1` or
    `d[name()] = v`: it is held while the entry is set (#209).
- **Methods:** `has(k)`; `find(k)`, a `V^` or `nullptr` (`const V^` for
  a let).
  - `get(k, default)`, for a `V` that does not own.
  - `remove(k)`; `clear()`; `reserve(n)`; `copy()`.
- **Properties:** `count`; `size`, `typename`.
  - `keys` and `values` (#66), Arrays of copies in the order added,
    which a variable then owns.
- **Walking:** `for k, v in d` gives each entry's key and value as lets
  the Dictionary owns, in the order added; `for k in d` the keys.
- **Text:** `print(d)` shows `{"ann": 31, "bob": 42}`, in the order
  added, and `d.pretty` the same indented, a line for each entry (#123,
  #124); String keys and values are quoted; `${d}` in a template is the
  same text (#125).
- **`d0 == d1`** (#235): the same entries, in any order, each value
  by its own `==`; `!=` the opposite.
  - The two are of one key type and one value type; others are an
    error.
  - The values compare: numbers, `bool`, text, a `uchr`, an Optional,
    a Result or an enum with values whose values compare, a pointer,
    and a Dictionary whose values compare. A struct or an Array has no
    `==`, so a Dictionary of them is an error.
  - One an expression gives is held while compared (#187).
- **`d.merge(&e)`** changes `d` in place, and **`d.merging(&e)`**
  gives a new Dictionary (#236): `e`'s entries are added, copied.
  - Where a key is in both, a function, trailing or after a comma,
    gives the value kept: `d.merge(&e) { old, new in old + new }`,
    `d.merging(&e, add)`.
    - It is called with `d`'s value and a copy of `e`'s, which it owns
      both of, and its result is stored.
    - Without one, `e`'s value wins.
  - `e` by value, `d.merge(e)`, moves in and is freed after (O5); one
    an expression gives is freed after too.
  - `merge` changes `d`, so `d` is a variable; a let or one an
    expression gives is an error that says to write `merging`.
- **`d0 ?? d1`** fills in, and **`d0 !! d1`** overrides (#237), as in
  swiftalk: a new Dictionary of `d0`'s entries and `d1`'s, where a key
  in both keeps `d0`'s value (`??`) or takes `d1`'s (`!!`).
  - So `(d0 !! d1) == (d1 ?? d0)`.
  - `d0 ??= d1` and `d0 !!= d1` do the same to `d0` in place, a
    variable.
  - The two are of one key type and one value type. A place is
    copied, and one an expression gives is taken and freed.
  - `!!` binds as `??` does, looser than `||` and tighter than `?:`;
    `!!x` before a value is still two `!`s.
- **`d.map`, `d.filter` and `d.reduce`** (#238) take a function of the
  values alone, as an Array's do of its elements, so a Dictionary is a
  sparse Array:
  - `d.map { v in v * 2 }` is a new Dictionary of the same keys and the
    function's values, of any type it gives;
  - `d.filter { v in v > 10 }` keeps the entries whose value it says
    true for, a new Dictionary;
  - `d.reduce(0) { acc, v in acc + v }` folds the values, in the order
    added.
  - A value that owns is given as a copy, which the function owns; a
    Dictionary an expression gives is freed after.
  - Not yet: versions whose function takes the key too.
- **Not yet:** keys of other types, `d[k, default]`.

## Properties and methods

| On | Property or method | Gives |
|---|---|---|
| `Dictionary<K, V>`, `${K: V}` | `.count` | the entries held |
| | `d[k]` | read whole, an Optional: `some` of a copy of the value, `none` where the key is missing (#218) |
| | `d[k]!` | the value, checked: a missing key ends the program; a place (#218) |
| | `d[k]?.m`, `d[k]?.f(...)`, `d[k]?[i]` | what follows, of the value, an Optional; `none` where the key is missing (#218) |
| | `d[k] += x`, `d[k].m`, `d[k][i]`, `&d[k]` | the entry, a place, checked: a missing key ends the program |
| | `d[k] = v` | adds the entry, or replaces the value, freeing what it held |
| | `.has(k)` | whether the key is there, a `bool` |
| | `.find(k)` | a `V^` to the value, or `nullptr`; `const V^` for a let |
| | `.get(k, default)` | the value, or the default; for a `V` that does not own |
| | `.remove(k)` | removes the entry; `true` if it was there |
| | `.clear()`, `.reserve(n)` | changes, in place |
| | `.copy()` | a new Dictionary, keys and values copied |
| | `.keys`, `.values` | Arrays of copies, in the order added (#66) |
| | `for k, v in d`, `for k in d` | each entry, or each key, in the order added |
| | `print(d)`, `d.pretty` | `{"ann": 31}`; the same indented, a String elsewhere (#123, #124) |
| | `.size`, `.typename` | `sizeof`; `Dictionary<String, i64>` |
| | `d0 == d1`, `d0 != d1` | the same entries, each value by its `==`, a `bool` (#235) |
| | `.merge(&e)`, `.merge(&e) { a, b in ... }` | `e`'s entries added in place; where a key is in both, the function's value, else `e`'s (#236) |
| | `.merging(&e)`, `.merging(&e, f)` | the same, a new Dictionary (#236) |
| | `d0 ?? d1`, `d0 !! d1` | a new Dictionary of both, a shared key's value `d0`'s or `d1`'s (#237) |
| | `d0 ??= d1`, `d0 !!= d1` | the same, in place (#237) |
| | `.map { v in ... }` | a new Dictionary of the same keys, each value the function's (#238) |
| | `.filter { v in ... }` | a new Dictionary of the entries whose value the function says true for (#238) |
| | `.reduce(init) { acc, v in ... }` | the values folded, in the order added (#238) |

No `.cstr`, no `+=`: `print` shows a Dictionary, and `.pretty`
is its text, indented (#123, #124). The general properties are in
[properties.md](properties.md), the ownership rules in
[ownership.md](ownership.md).
