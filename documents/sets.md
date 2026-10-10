# Sets: `Set<T>`

`Set<T>`, or `${T}` for short, is a hash set on the heap (#71): an
owner, freed when its block ends, moved by `return` and by passing,
copied only by `.copy()`, borrowed as a pointer. The rules are in
[ownership.md](ownership.md); this is the summary. A Set is a
Dictionary with no values, and keeps its elements in the order added.

```kelvin
var s = ${3, 1, 4, 1, 5}                 // Set<i64>: 3 1 4 5
s += 9                                   // insert; s.insert(9) says whether it was new
s += &t                                  // t's elements
println(s.count, " ", s.has(4), " ", s.remove(1))
for x in s { print(x, " ") }             // in the order added
var u = s.union(&t)                      // new Sets: union, intersection, difference
var words = ${"to", "be", "or"}          // Set<String>: the text copied in
println(words.has("be"), " ", words.elements.typename)   // true Array<String>
var e:${String} = ${}                    // empty; Set<String>() too
```

- **Elements** are an integer type, hashed as a number, or `String`:
  the Set keeps a copy of the text, and is asked with a `cstr`, a
  template, or a String. A `cstr` element type is an error that says so.
- **Making one:** `${a, b, c}` with `T` inferred from the first element;
  `${}` where the type is written (`${:}` is an empty Dictionary);
  `Set<T>()`, `Set<T>({a, b, c})`, `Set<T>(&other)` a copy; a
  declaration without a value is empty. `{a, b, c}` works where the
  type is written, as a member's value or an initializer.
- **Methods:** `insert(x)` (also `+=`), `true` if it was new; `+=
  &other` inserts another's elements; `has(x)`; `remove(x)`, `true` if
  it was there; `union(&t)`, `intersection(&t)`, `difference(&t)`, new
  Sets; `clear()`; `reserve(n)`; `copy()`. **Properties:** `count`;
  `elements`, an Array of copies in the order added; `size`,
  `typename`.
- **Walking:** `for x in s` gives each element as a let the Set owns,
  in the order added. A Set is not indexed.
- **Not yet:** text (`print(s)` is an error: show the elements), `==`,
  `isSubset`, elements of other types.

## Properties and methods

| On | Property or method | Gives |
|---|---|---|
| `Set<T>`, `${T}` | `.count` | the elements held |
| | `.insert(x)`, `+=` | adds; `true` if it was new; `+= &other` adds another's |
| | `.has(x)` | whether it is there, a `bool` |
| | `.remove(x)` | removes; `true` if it was there |
| | `.union(&t)`, `.intersection(&t)`, `.difference(&t)` | new Sets |
| | `.clear()`, `.reserve(n)` | changes, in place |
| | `.copy()` | a new Set, elements copied |
| | `.elements` | an Array of copies, in the order added |
| | `for x in s` | each element, in the order added |
| | `.size`, `.typename` | `sizeof`; `Set<i64>` |
