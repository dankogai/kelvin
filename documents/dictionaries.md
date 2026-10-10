# Dictionaries: `Dictionary<K, V>`

`Dictionary<K, V>`, or `${K: V}` for short, is a hash map on the heap
(#65): an owner, freed when its block ends, moved by `return` and by
passing, copied only by `.copy()`, borrowed as a pointer. The rules are
in [ownership.md](ownership.md); this is the summary.

```kelvin
var ages = ${"ann": 31, "bob": 42}       // Dictionary<String, i64>
ages["cy"] = 7                           // adds, or replaces the value
ages["ann"] += 1                         // a place, checked: a missing key ends the program
println(ages["bob"], " ", ages.count, " ", ages.has("dan"))
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
```

- **Keys** are an integer type, hashed as a number, or `String`: the
  Dictionary keeps a copy of the text, and is read with a `cstr`, a
  template, or a String. A `cstr` key type is an error that says so.
- **Values** are anything an Array holds, owners included, which the
  Dictionary then owns.
- **Making one:** `${k: v, ...}` with `K` and `V` inferred from the
  first entry; `${:}` where the type is written; `Dictionary<K, V>()`,
  `Dictionary<K, V>({k: v, ...})`, `Dictionary<K, V>(&other)` a copy; a
  declaration without a value is empty.
- **`d[k]`** reads the value, checked, and is a place; `d[k] = v` adds
  the entry or replaces its value, freeing what it held if it owns; `=`
  does not copy an owner in: `d[k] = s.copy()`.
- **Methods:** `has(k)`; `find(k)`, a `V^` or `nullptr` (`const V^` for
  a let); `get(k, default)`, for a `V` that does not own; `remove(k)`;
  `clear()`; `reserve(n)`; `copy()`. **Properties:** `count`; `keys`
  and `values` (#66), Arrays of copies in the order added, which a
  variable then owns; `size`, `typename`.
- **Walking:** `for k, v in d` gives each entry's key and value as lets
  the Dictionary owns, in the order added; `for k in d` the keys.
- **Not yet:** text (`print(d)` is an error: show the entries), `==`,
  keys of other types, `d[k, default]`.

## Properties and methods

| On | Property or method | Gives |
|---|---|---|
| `Dictionary<K, V>`, `${K: V}` | `.count` | the entries held |
| | `d[k]` | the value, checked: a missing key ends the program; a place |
| | `d[k] = v` | adds the entry, or replaces the value, freeing what it held |
| | `.has(k)` | whether the key is there, a `bool` |
| | `.find(k)` | a `V^` to the value, or `nullptr`; `const V^` for a let |
| | `.get(k, default)` | the value, or the default; for a `V` that does not own |
| | `.remove(k)` | removes the entry; `true` if it was there |
| | `.clear()`, `.reserve(n)` | changes, in place |
| | `.copy()` | a new Dictionary, keys and values copied |
| | `.keys`, `.values` | Arrays of copies, in the order added (#66) |
| | `for k, v in d`, `for k in d` | each entry, or each key, in the order added |
| | `.size`, `.typename` | `sizeof`; `Dictionary<String, i64>` |

No `.cstr`, no `==`, no `+=`. The general properties are in
[properties.md](properties.md), the ownership rules in
[ownership.md](ownership.md).
