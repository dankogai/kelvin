# Iterators

An iterator is a value whose `next()` gives each value in turn, then
`none` (#318), as Swift's `IteratorProtocol` does. `for x in it` walks
one, and `map`, `filter`, `reduce` and `flatMap` take one as they take
an Array (#319).

**Where it lives:** the core. An iterator is a struct or a union of the program with a var method `next`; `for` and the four methods are kelvinc's own, written as C's, with nothing linked.

```swift
struct countdown { n: int64 }
var countdown.next():int64? {                 // each value, then none
    if .n == 0 { return none }
    .n -= 1
    return .n + 1
}
let from(n:int64):countdown { return {n} }

let main():int32 {
    for x in from(3) { print(x, ",") }        // 3,2,1,
    println()
    println(from(4).map { $0 * 10 })         // [40, 30, 20, 10]
    println(from(6).filter { $0 % 2 == 0 })  // [6, 4, 2]
    println(from(4).reduce(0) { $0 + $1 })   // 10
    var c:countdown = {5}
    for x in c {
        if x == 4 { break }
    }
    println(c.n)                              // 3: c goes on where it stopped
    return 0
}
```

## An iterator: `var T.next():E?`

- **An iterator** is a value of a struct or a union of the program
  with a method `next`.
  - `next` takes nothing and gives an Optional, `E?`: each value as
    `some`, then `none` once there are no more.
  - It is a var method (#318), `var T.next():E?`, or `var next():E?`
    in `extend T { }`, since it changes the iterator: its `self` is the
    caller's var.
  - What the iterator holds is up to it: a count, a position in a
    String it owns, a pointer along a list.
- **A `next` of another shape is an error** where the iterator is
  walked, and names `var T.next():T?`:
  - a let method, which reads `self` and never changes it;
  - one that takes something, or that gives no Optional.
- **Var methods** are in [structs.md](structs.md#methods): a var method
  is called on a variable, a member, an element or `p^`, never on a
  let or a value a call gives.

## Walking: `for x in it`

```swift
struct letters { text: String; at: int64 }
var letters.next():String? {
    if .at >= .text.count as int64 { return none }
    let s:String = .text[.at..<.at + 1]
    .at += 1
    return s
}
let spell(t:cstr):letters { return {String(t), 0} }

let main():int32 {
    for s in spell("abc") { print(s, ".") }   // a.b.c.
    println()
    return 0
}
```

- **The loop calls `next()`** before each pass, and ends at the first
  `none`.
- **The loop changes the iterator**, as `next` does.
  - A var walked in part, by `break`, goes on where it stopped: the
    next `for` over it starts there.
  - One walked to the end stays at its end, and a second `for` over
    it walks nothing.
  - A let, or one through a `const T^`, is an error that says to
    declare it with var.
- **An iterator an expression gives**, `for x in from(3)`, is held in
  a hidden var for the loop, and freed after it where it owns.
- **`x` is a let**, as in any `for` ([flow-controls.md](flow-controls.md)).
  - An owner `next` gives, a `String`, is the loop's: it is freed at
    the end of each pass, at `break` and at `continue`, and `x`
    borrows it.
  - `for x:E in it` writes its type, which must be `next`'s; `for _ in
    it` names none.
  - Two loop variables, `for k, v in it`, are a Dictionary's, and an
    error here.

## `map`, `filter`, `reduce` and `flatMap`

```swift
struct countdown { n: int64 }
var countdown.next():int64? {
    if .n == 0 { return none }
    .n -= 1
    return .n + 1
}
let from(n:int64):countdown { return {n} }
let twice(n:int64):int64 { n * 2 }

let main():int32 {
    println(from(3).map(twice))                                     // [6, 4, 2]
    println(from(3).flatMap { Array<int64>([$0, -$0]) })            // [3, -3, 2, -2, 1, -1]
    println(from(5).filter { $0 > 1 }.map { $0 * $0 }.reduce(0) { $0 + $1 })   // 54
    return 0
}
```

- **They are Swift's `Sequence` methods** (#319), eager as Swift's
  are: each walks the iterator to its end and gives what an Array's
  would.
  - `it.map(f)`, `it.map { ... }` is a new `Array<U>` of `f` of each
    value.
  - `it.filter { ... }` is a new `Array<E>` of the values `f` says
    true for.
  - `it.reduce(init) { ... }` is `f` of the value so far and each
    value, from `init`, of `init`'s type.
  - `it.flatMap { ... }` is the Arrays `f` gives each value,
    concatenated, a new `Array<U>`.
- **The values are gathered first**: `next()` is called to `none`, its
  values move into an Array, and the Array's own method walks it and
  frees it ([arrays.md](arrays.md)).
  - So every `next()` runs before the first `f`, where Swift's would
    take turns: a `next` or an `f` that prints shows it.
  - An iterator that never gives `none` never ends here, as in Swift.
- **The rules are an Array's** (#182, #184, #244, #308): an anonymous
  function is lent each value, a named one given a copy, and they
  chain, as `it.filter { ... }.map { ... }.reduce(0) { ... }`.
- **The iterator is walked to its end**, as a `for` leaves it: a var
  stays at its end, a let is an error, and one an expression gives is
  held and freed.
- **A method of the iterator's own** of one of these names wins, as a
  struct's member wins over a property.

## Not yet

- **Swift's `Sequence`**, `makeIterator()`, which would give a fresh
  iterator each time, so that a collection of the program's is walked
  afresh and stays as it was.
- **Lazy methods**, Swift's `.lazy.map`, which would give an iterator
  rather than an Array, and so take an iterator that never ends.
- **kc** reads neither iterators nor var methods
  ([selfhost/README.md](../selfhost/README.md)).

## What each takes and gives

Each line is written as it would be declared, in Kelvin's spelling.

<!-- fragment -->
```swift
var T.next():E?                        // an iterator: each value, then none
for x in it { ... }                    // x: E, each value, up to none; it changes
it.map(f:(E):U): Array<U>
it.filter(f:(E):bool): Array<E>
it.reduce(init:A, f:(A, E):A): A
it.flatMap(f:(E):Array<U>): Array<U>
```

## Properties and methods

| On | Property or method | Gives |
|---|---|---|
| an iterator, `var T.next():E?` | `.next()` on a var | the next value as `some`, then `none`; it changes the iterator (#318) |
| | `for x in it` | each value, up to `none`; a var goes on where `break` left it (#318) |
| | `.map(f)`, `.map { ... }` | a new `Array<U>` of `f` of each value (#319) |
| | `.filter(f)`, `.filter { ... }` | a new `Array<E>` of the values `f` says true for (#319) |
| | `.reduce(init, f)`, `.reduce(init) { ... }` | `f` of the value so far and each value, from `init`, of `init`'s type (#319) |
| | `.flatMap(f)`, `.flatMap { ... }` | the Arrays `f` gives each value, concatenated, a new `Array<U>` (#319) |

An iterator has the properties of any struct or union, as
[structs.md](structs.md) has them; the general ones are in
[properties.md](properties.md).
