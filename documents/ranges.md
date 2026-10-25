# Ranges: `Range<T>`

A range is a value of its own, `Range<T>` (#373): the integers from a
lower bound up to an upper one. It is a Sequence, walked by `for` and
by `map`, `filter`, `reduce`, `flatMap`, `lazy` and `prefix`, as
[iterators.md](iterators.md) has them.

**Where it lives:** the core. A Range is kelvinc's own, a struct of its
bounds written into the program's C, with nothing linked; the Iterator
its `lazy` and `prefix { ... }` give is the prelude's `kv_iter`, in
`libkelvin`, linked without an import.

```swift
let squares(r:Range):$[int64] { return r.map { $0 * $0 } }

let main():int32 {
    let r = 0..<5                             // Range<i64>: 0 1 2 3 4
    let c = 1...3                             // 1 2 3
    let n = 3
    for i in -n..<n { print(i, ",") }         // -3,-2,-1,0,1,2,
    for i in ..<3 { print(i, ",") }           // 0,1,2,: from 0
    println()
    println(r.filter { $0 % 2 == 0 }, " ", c.reduce(0) { $0 + $1 }, " ", squares(c))   // [0, 2, 4] 6 [1, 4, 9]
    let naturals = 0...                       // no end: up to i64's largest
    println(naturals.prefix(3), " ", naturals.lazy.map { $0 * $0 }.prefix(4).map { $0 })   // 0..<3 [0, 1, 4, 9]
    let small:Range<uint8> = 250...
    println(small, " ", small.prefix(10))     // 250... 250...255
    return 0
}
```

## Writing one

- **`lo..<hi`** is from `lo` up to `hi`, without it; **`lo...hi`** with
  it.
- **`lo...`** has no end: it walks up to its type's largest, and stops
  there, never wrapping.
  - So `0...` of `i64` is as good as endless, and `250...` of a `u8`
    is 250 to 255.
- **`..<hi` and `...hi`** start at 0: `..<4` is `0..<4`.
  - `-n..<n` is from `-n`: the `-` is the bound's own.
- **A bound** is an expression down to the shifts, as in a `for`
  ([flow-controls.md](flow-controls.md)): `0..<n - 1` ends before
  `n - 1`.
  - A range binds tighter than a comparison, and looser than `+` and
    `<<`, as Swift's.
  - `lo..<` is an error; a range without an end is `lo...`.
- **`T`** is written, `Range<uint8>`, and `Range` alone is
  `Range<i64>`.
  - Unwritten, it is the upper bound's type where kelvinc sees it, else
    the lower one's, else `i64`, as a `for`'s counter (#28).
  - A range given where a `Range<T>` goes, to a variable, a parameter,
    a member, a result or a `Range<T>?`, is of that `T`.
  - `T` is an integer type, `i8` to `i64` or `u8` to `u64`; a
    floating-point or `bool` bound is an error.
- **A lower bound past the upper** is empty: `5..<1` walks nothing.

## A value

- **A Range is copied** as a number is: it owns nothing.
  - It goes where a value goes: a let, a var, a parameter, a result, a
    member, an element of an Array, a `Range<T>?`.
- **Its text** is as written, and pastes back: `0..<5`, `1...3`, `0...`.
  - `print`, a template's `${r}` and the text of an Array or a struct
    that holds one show it so.
  - A typed one shows its bounds alone: `Range<uint8>`'s `1...3` pastes
    back as a `Range<i64>`, as a `u8`'s `3` does as an `i64`.
- **It has no operators**: `r == s` and the rest are errors.
- **Its other methods are not yet**: `.count`, `.contains(x)`, its
  bounds; `r.count` is an error that names what a Range has.

## Walking: `for i in r`

- **`for i in a..<b`** counts as before (#28); now also
  `for i in ..<n`, `for i in ...n`, and `for i in 0... { }`, which a
  `break` ends, or its type's largest.
- **`for i in r`** of a Range value walks its values, from `lo`.
  - `i` is a let of `T`; `for i:U in r` converts each to `U`.
  - `r` is read once, and stays as it was: a Range is walked afresh
    each time, as a Sequence is.

## `map`, `filter`, `reduce` and `flatMap`

- **They are a Sequence's** ([iterators.md](iterators.md)): the values
  walked to the end, into an Array, which the Array's method then walks.
  - `(1...3).map { $0 * 10 }` is `[10, 20, 30]`.
- **A Range without an end** has no end to walk to.
  - Written so, `(0...).map { ... }` is an error that says to take the
    first few, `.prefix(10).map`, or to walk it lazily.
  - One whose end is known only at run time ends the program, as a
    check does (#174): `kelvin: this Range has no end, and '.map' walks
    one to its end: take its first few, '.prefix(n)'`.
- **`r.lazy.map(f)` and `r.lazy.filter(f)`** give an `Iterator<U>`, which
  calls `f` only as each value is asked for, and is walked once.

## The first few: `prefix`

- **`r.prefix(n)`** is the Range of its first `n` values, Haskell's
  `take`.
  - `(0...).prefix(5)` is `0..<5`, and `(250...).prefix(10)` of a `u8`
    is `250...255`: `lo...hi` where `hi` is its type's largest.
  - A count of 0 or less gives an empty one, `lo..<lo`.
- **`r.prefix { ... }`** is an `Iterator<T>` of the values up to the
  first its function says false for, lazily, Haskell's `takeWhile`.

## Slices

- **`xs[lo..<hi]`** slices an Array, a String or a Bytes as before
  (#68), its bounds written: [arrays.md](arrays.md).
- A Range value does not index yet: `xs[r]` is an error that says to
  write its bounds.

## Properties and methods

| On | Property or method | Gives |
|---|---|---|
| `Range<T>` | `lo..<hi`, `lo...hi`, `lo...`, `..<hi`, `...hi` | a Range: without `hi`, with it, up to `T`'s largest, from 0 |
| | `print(r)`, `${r}` | `0..<5`, `1...3`, `0...`, as written |
| | `for i in r` | each value, from `lo` |
| | `.map { ... }`, `.map(f)` | an Array of what `f` gives each value |
| | `.filter { ... }`, `.filter(f)` | an Array of the values `f` says true for |
| | `.reduce(init) { ... }`, `.reduce(init, f)` | the values folded, from `init` |
| | `.flatMap { ... }`, `.flatMap(f)` | the Arrays `f` gives each value, concatenated |
| | `.lazy.map { ... }`, `.lazy.filter { ... }` | an `Iterator<U>`, lazily |
| | `.prefix(n)` | the Range of its first `n` values |
| | `.prefix { ... }` | an `Iterator<T>` of the values before the first `f` says false for |

## kc

kc, the compiler written in Kelvin, reads all of this as kelvinc writes
it ([selfhost/README.md](../selfhost/README.md)), with these
differences:

- **`T`** is one of kc's integers, `i64`, `i32`, `u8` or `u32`.
- **A `for` over a range** counts with an `i64`, as kc's always has;
  the values are the same.
  - kc's `for` writes no type, so `for i:U in r` is not kc's.
- **Templates** are not kc's, so neither is `${r}`.
- **An error** is said by its line alone; the words are kelvinc's.

kc reads every row of the table above but `${r}`.

## Not yet

- Ranges of floating-point numbers, as Swift's `Range<Double>`.
- Reversed and stepped ranges, `stride`.
- `==`, `.count`, `.contains(x)`, the bounds, and slicing by a Range
  value.
