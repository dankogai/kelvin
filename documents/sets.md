# Sets: `Set<T>`

A set of integers or Strings, owned on the heap, kept in the order added.

## Synopsis

```swift
var t = ${2, 6}
var s = ${3, 1, 4, 1, 5}                 // Set<i64>: 3 1 4 5
s += 9                                   // insert; s.insert(9) says whether it was new
s += &t                                  // t's elements
println(s.count, " ", s.has(4), " ", s.remove(1))
for x in s { print(x, " ") }             // in the order added
var u = s.union(&t)                      // new Sets: union, intersection, difference
var v = s | t                            // the same as operators: |, &, ~ (symmetric difference); |=, &=, ~=
var words = ${"to", "be", "or"}          // Set<String>: the text copied in
println(words.has("be"), " ", words.elements.typename)   // true Array<String>
var e:${String} = ${}                    // empty; Set<String>() too
```

## Description

`Set<T>`, or `${T}` for short, is a hash set on the heap (#71): an
owner, freed when its block ends, moved by `return` and by passing,
copied only by `.copy()`, borrowed as a pointer. The rules are in
[ownership.md](ownership.md); this is the summary. A Set is a
Dictionary with no values, and keeps its elements in the order added.

- **Elements** are an integer type, hashed as a number, or `String`.
  - The Set keeps a copy of the text, and is asked with a `cstr`, a
    template, or a String.
  - A `cstr` element type is an error that says so.
- **Making one:** `${a, b, c}` with `T` inferred from the first
  element.
  - `${}` where the type is written (`${:}` is an empty Dictionary);
    `Set<T>()`; a declaration without a value is empty.
  - `Set<T>({a, b, c})`; `Set<T>(&other)` a copy.
  - `{a, b, c}` works where the type is written, as a member's value
    or an initializer.
- **Methods:** `insert(x)` (also `+=`), `true` if it was new;
  `+= &other` inserts another's elements.
  - A String an expression gives is held while its text is copied in,
    `s += f()` and `${f()}` as `s.insert(f())` (#315).
  - `has(x)`; `remove(x)`, `true` if it was there.
  - `union(&t)`, `intersection(&t)`, `difference(&t)`, new Sets.
  - `clear()`; `reserve(n)`; `copy()`.
  - `map`, `filter` and `reduce` (#307), over the elements in the order
    added, as an Array's (#182, #184): `s.map { $0 % 3 }` is a new Set
    of what the function gives, its duplicates one, an integer or a
    String; `s.filter { $0 > 3 }` a new Set of the elements it keeps;
    `s.reduce(0) { $0 + $1 }` them folded.
    - The function is lent each element, a named one given a copy; to
      map to anything else, map the elements, `s.elements.map`.
  - `flatMap` (#308): the Sets its function gives each element,
    unioned, which makes a Set a monad: `s.flatMap { Set<int64>({$0,
    $0 + 1}) }`.
  - `prefix(n)` and `prefix { ... }` (#372): a new Set of the first `n`
    elements in the order added, or of those before the first the
    function says false for.
- **Operators** (#73): `s | t` is the union, `s & t` the intersection
  and `s ~ t` the symmetric difference (what is in one, not both), new
  Sets of two in variables.
  - `s |= t`, `s &= t` and `s ~= t` change `s` in place, `t` another
    Set in a variable; a borrow, `s |= &t`, is an error that says so
    (#277), as `s += &t` is how a borrow's elements go in.
- **Properties:** `count`; `elements`, an Array of copies in the order
  added, a new owner a function may return, `return s^.elements`
  (#280); `size`, `typename`.
- **Walking:** `for x in s` gives each element as a let the Set owns,
  in the order added. A Set is not indexed.
- **Text:** `print(s)` shows `{3, 1, 4}`, in the order added, and
  `s.pretty` the same indented (#123, #124); `${s}` in a template is
  the same text (#125).
- **Not yet:** `==`, `isSubset`, `-` for the difference, elements of
  other types.

## Where it lives

The prelude. A Set's C comes from `kelvin_prelude.h`, instantiated for each `T`, with hashing in `libkelvin`, linked without an import.

## kc

kc, the compiler written in Kelvin, reads this much of a Set as kelvinc
writes it ([selfhost/README.md](../selfhost/README.md)):

- **The type and its values**: `Set<T>` of integers or Strings, `${a,
  b}`, and `${}` or `{a, b}` where the type is written (#274), printed
  as kelvinc prints one.
- **Its elements**: `.insert(x)` and `+=`, `+= &t`, `.has(x)`,
  `.remove(x)`, `.count`, `.copy()`, `.elements` (#278), and `for x in
  s` in the order added; `.reserve(n)` and `.clear()` (#336).
- **Its text**: printed as kelvinc prints it, `.pretty` and `.typename`
  (#336).
- **The algebra**: `.union(&t)`, `.intersection(&t)`, `.difference(&t)`
  (#275), and `|`, `&`, `~` and `|=`, `&=`, `~=` (#276).
- **map, filter, reduce and flatMap** (#330), map's a Set of integers or
  Strings, as kelvinc's.

kc reads every row of the table below.

Where kc differs, a String element is given to an anonymous function as
a copy, which it owns, where kelvinc lends it (#244); what prints is the
same.

## Properties and methods

| On | Property or method | Gives |
|---|---|---|
| `Set<T>`, `${T}` | `.count` | the elements held |
| | `.insert(x)`, `+=` | adds; `true` if it was new; `+= &other` adds another's |
| | `.has(x)` | whether it is there, a `bool` |
| | `.remove(x)` | removes; `true` if it was there |
| | `.union(&t)`, `.intersection(&t)`, `.difference(&t)` | new Sets |
| | `s \| t`, `s & t`, `s ~ t` | the union, the intersection, the symmetric difference, new Sets (#73) |
| | `s \|= t`, `s &= t`, `s ~= t` | the same, in place |
| | `.clear()`, `.reserve(n)` | changes, in place |
| | `print(s)`, `s.pretty` | `{3, 1, 4}`; the same indented, a String elsewhere (#123, #124) |
| | `.copy()` | a new Set, elements copied |
| | `.elements` | an Array of copies, in the order added |
| | `.map { ... }`, `.map(f)` | a new Set of what `f` gives each element, an integer or a String (#307) |
| | `.filter { ... }`, `.filter(f)` | a new Set of the elements `f` says true for (#307) |
| | `.prefix(n)`, `.prefix { ... }` | a new Set of the first `n` elements in the order added, or of those before the first `f` says false for (#372) |
| | `.reduce(init) { ... }`, `.reduce(init, f)` | the elements folded in the order added, from `init` (#307) |
| | `.flatMap { ... }`, `.flatMap(f)` | the Sets `f` gives each element, unioned (#308) |
| | `for x in s` | each element, in the order added |
| | `.size`, `.typename` | `sizeof`; `Set<i64>` |
