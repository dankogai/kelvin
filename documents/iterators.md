# Iterators

An iterator is a value whose `next()` gives each value in turn, then
`none` (#318), as Swift's `IteratorProtocol` does. `Iterator<T>` makes
one of a state and a function (#325), as Swift's
`sequence(state:next:)` does. A Sequence is a
value whose `makeIterator()` gives a fresh iterator (#321), as Swift's
`Sequence` does. `for x in s` walks either, and `map`, `filter`,
`reduce` and `flatMap` take either as they take an Array (#319);
`s.lazy.map` and `s.lazy.filter` call their function only as each value
is asked for (#323), and so do an Iterator's (#327).

**Where it lives:** the core. `Iterator<T>` is kv_iter, runtime/iter.k's, in `libkelvin`, linked without an import. An iterator of the program's own is a struct or a union with a var method `next`, a Sequence one with a let method `makeIterator`; `for` and the four methods are kelvinc's own, written as C's, with nothing linked.

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

## `Iterator<T>`: a state and a function

```swift
let fibs():Iterator<int64> {
    return Iterator($[0, 1]) {                // the state, and a function of it
        let r = $0[0]
        if r > 1000 { return none }           // then none
        let next:int64 = $0[0] + $0[1]
        $0[0] = $0[1]                         // $0 is the state itself
        $0[1] = next
        return r                              // each value
    }
}

let main():int32 {
    var it = fibs()
    let first = it.next()                     // some(0)
    for x in it {                             // 1,1,2,3,5,8,
        if x > 10 { break }
        print(x, ",")
    }
    println(" ", first, " ", fibs().filter { $0 % 2 == 0 })   // some(0) [0, 2, 8, 34, 144, 610]
    return 0
}
```

- **`Iterator(state) { ... }`** (#325), Swift's `sequence(state:next:)`,
  is an `Iterator<T>` of the state and the function after it.
  - The function gives each value, a `T?`, then `none`: `return v`
    and `return none`.
  - **`$0` is the state itself**: what the function changes stays
    changed for the next call, as a var method's `self` does (#318).
  - `T` is what its first `return v` gives; `return none` before it
    waits for it. `Iterator<T>(state) { ... }` writes it.
  - `{ (s:S):T? in ... }` writes the parameter, which is the state
    itself too, and the result.
  - `Iterator(state, f)` takes a function of the program's,
    `let f(s:S^):T?`, given a borrow of the state that may change it.
  - In a `for` header, the function goes inside the parentheses,
    `Iterator(0, { ... })`, since a `{` there starts the body.
- **The state** is a value: a number, a struct, or an owner, as
  `$[0, 1]` or a String; an array is no value (#48), so it is an Array
  or a struct instead.
  - Kelvin has no tuples, so a pair of numbers is two elements of an
    Array, or a struct, `Iterator<int64>((point){0, 1}) { ... }`.
- **An `Iterator<T>` is an owner** ([ownership.md](ownership.md)).
  - Its state is on the heap: one that owns moves in, a var's too,
    and is freed with the Iterator.
  - It moves by `return` and passing, as `fibs()` gives it and a
    function that takes `var it:Iterator<T>` walks it; it is not
    copied.
  - The end of its block frees it, walked to its end or not.
- **It is an iterator**, walked once: `it.next()` on a var, `for x in
  it`, `map`, `filter`, `reduce` and `flatMap`, as the next sections
  have them.
  - A let is an error: walking changes it.
  - `it.lazy.map(f)` and `it.lazy.filter(f)` make another Iterator,
    lazily (#327): see [Lazy](#lazy-slazymap-and-slazyfilter).
  - It has no text: `print` of one is an error.

## An iterator of the program's: `var T.next():E?`

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

## A Sequence: `let T.makeIterator():I`

```swift
struct span { lo: int64; hi: int64 }           // a Sequence
struct span_walk { at: int64; hi: int64 }      // its iterator
var span_walk.next():int64? {
    if .at >= .hi { return none }
    .at += 1
    return .at - 1
}
let span.makeIterator():span_walk { return {.lo, .hi} }

let main():int32 {
    let s:span = {1, 4}
    for x in s { print(x, ",") }              // 1,2,3,
    for x in s { print(x, ",") }              // 1,2,3, again: s stays as it was
    println()
    println(s.map { $0 * 10 })               // [10, 20, 30]
    return 0
}
```

- **A Sequence** (#321) is a value of a struct or a union of the
  program with a method `makeIterator`.
  - `makeIterator` is a let method that takes nothing and gives an
    iterator, a value whose `var next():E?` gives each value.
  - A var `makeIterator`, one that takes something, or one that gives
    no iterator is an error that names `let T.makeIterator():I`.
  - The iterator holds what it walks by value, a copy of what it needs,
    as `span_walk` holds the bounds and a word's iterator holds a copy
    of its String.
- **`for x in s` walks `s.makeIterator()`**, a fresh iterator held for
  the loop and freed after it where it owns.
  - `s` reads and never changes: it may be a let, and each `for` over
    it walks it afresh.
  - A Sequence an expression gives, `for x in upto(3)`, is held for the
    loop, and freed after it where it owns.
  - `x` is as an iterator's, above.
- **`map`, `filter`, `reduce` and `flatMap`**, below, walk a fresh
  iterator too, and leave `s` as it was.
- **A value with both** `makeIterator` and `next` is a Sequence, as in
  Swift's `for`: `makeIterator` wins.

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
- **An iterator is walked to its end**, as a `for` leaves it: a var
  stays at its end, a let is an error, and one an expression gives is
  held and freed.
  - A Sequence's are walked on a fresh iterator, from `makeIterator()`,
    and the Sequence stays as it was (#321).
- **A method of the value's own** of one of these names wins, as a
  struct's member wins over a property.

## Lazy: `s.lazy.map` and `s.lazy.filter`

```swift
struct span { lo: int64; hi: int64 }
struct span_walk { at: int64; hi: int64 }
var span_walk.next():int64? {
    if .at >= .hi { return none }
    .at += 1
    return .at - 1
}
let span.makeIterator():span_walk { return {.lo, .hi} }
let tens(n:int64):int64 {
    println("tens of ", n)
    return n * 10
}

let main():int32 {
    let s:span = {1, 5}
    let m = s.lazy.map(tens)                  // nothing called yet
    for x in m {                              // tens of 1, got 10, tens of 2, got 20
        println("got ", x)
        if x == 20 { break }
    }
    let endless:span = {0, 1000000000}
    for x in endless.lazy.filter({ $0 % 7 == 3 }) {
        if x > 30 { break }                   // 3,10,17,24,
        print(x, ",")
    }
    println()
    return 0
}
```

- **`s.lazy.map(f)` and `s.lazy.filter(f)`** (#323), Swift's, give a
  lazy Sequence: one whose iterator calls the base's `next()`, and `f`,
  only when it is asked for a value.
  - Nothing is gathered: `f` runs between the loop's passes, a `break`
    stops it, and an endless Sequence is walked as far as it is asked.
  - `.map`'s value is a Sequence of what `f` gives; `.filter`'s, of the
    values `f` says true for, a `bool`.
  - `.lazy` stands before `map` or `filter` alone; with nothing after
    it, or another method, it is an error.
- **A lazy Sequence is a Sequence** of a struct kelvinc makes, whose
  type is not written: bind it with `let`, walk it with `for`, as often
  as wanted, each walk afresh.
  - Its own `map` and `filter` are lazy too, so they chain:
    `s.lazy.map({ ... }).filter({ ... })`.
  - Its `reduce` and `flatMap` are eager, as any Sequence's: they walk
    it to its end.
  - `print` and `println` of one are errors: its values are made only as
    they are asked for, and its own text would not paste back.
- **The values** are as an Array's map has them (#244): each is lent to
  an anonymous `f`, a named `f` is given a copy, and the one `next`
  gave is freed, unless `filter` keeps it.
- **The base** is held in the lazy Sequence: a copy of a place that
  owns, as `w.lazy.map { ... }` of a let `w` holding a String; one an
  expression gives moves in; it is freed with the lazy Sequence.
- **An iterator of the program's** has no `.lazy`: an error says to give
  its type a `let makeIterator()`, since a lazy Sequence is walked
  afresh.
- In a `for` header, the function goes in parentheses,
  `.lazy.map({ ... })`, since a `{` there starts the body.

### An Iterator's: `it.lazy.map` and `it.lazy.filter`

```swift
let naturals():Iterator<int64> {
    return Iterator(0) {
        $0 += 1
        return $0                             // never none: it never ends
    }
}
let evens_squared():Iterator<int64> {
    return naturals().lazy.filter({ $0 % 2 == 0 }).lazy.map({ $0 * $0 })
}

let main():int32 {
    for x in evens_squared() {                // 4,16,36,64,100,
        if x > 100 { break }
        print(x, ",")
    }
    println()
    return 0
}
```

- **`it.lazy.map(f)` and `it.lazy.filter(f)`** (#327) of an
  `Iterator<T>` give an `Iterator<U>`: its state is `it`, moved in, and
  its `next` asks `it` for each value and calls `f` only as it is asked.
  - `it` holds nothing after, as a move leaves it; using it is an error.
  - Its type is written, `Iterator<U>`, so a function returns a lazy
    chain, as `evens_squared` does, of an Iterator that never ends.
- **It is a plain Iterator**, walked once: its own `map`, `filter`,
  `reduce` and `flatMap` are eager, as any Iterator's, so a lazy chain
  writes `.lazy` again, `it.lazy.filter({ ... }).lazy.map({ ... })`.
  - A lazy Sequence's map and filter stay lazy instead, its type being
    one kelvinc makes; an Iterator's is the one `Iterator<U>`.
- **The values** are as a lazy Sequence's: lent to an anonymous `f`, a
  copy given to a named one, and freed unless `filter` keeps them.

## Not yet

- **kc's `map`, `filter`, `reduce` and `flatMap`**: kc reads var
  methods and `for x in it` (#320), and these wait for its anonymous
  functions ([selfhost/README.md](../selfhost/README.md)).
- **kc's eager methods**: kc walks a Sequence in `for` (#322), reads
  `.lazy.map` and `.lazy.filter` (#324) and `Iterator<T>` (#326), and the
  eager `map`, `filter`, `reduce` and `flatMap` wait, where kc's
  anonymous functions do not go yet.
- kc reads an Iterator's `it.lazy.map` and `it.lazy.filter` (#328).

## What each takes and gives

Each line is written as it would be declared, in Kelvin's spelling.

<!-- fragment -->
```swift
Iterator(state:S) { ... }: Iterator<T>    // $0: the state itself; returns each T, then none
Iterator(state:S, f:(S^):T?): Iterator<T>
var T.next():E?                        // an iterator: each value, then none
let T.makeIterator():I                 // a Sequence: a fresh iterator, I one
for x in it { ... }                    // x: E, each value, up to none; it changes
for x in s { ... }                     // x: E, of s.makeIterator(); s stays
s.lazy.map(f:(E):U)                    // a lazy Sequence of U: f runs as each is asked for
s.lazy.filter(f:(E):bool)              // a lazy Sequence of the E f keeps
it.lazy.map(f:(T):U): Iterator<U>      // it moves in; f runs as each is asked for
it.lazy.filter(f:(T):bool): Iterator<T>
it.map(f:(E):U): Array<U>
it.filter(f:(E):bool): Array<E>
it.reduce(init:A, f:(A, E):A): A
it.flatMap(f:(E):Array<U>): Array<U>
```

## Properties and methods

| On | Property or method | Gives |
|---|---|---|
| `Iterator<T>` | `Iterator(state) { ... }`, `Iterator(state, f)` | an iterator of the state and the function, which gives each value, then `none` (#325) |
| | `.next()` on a var | the next value as `some`, then `none` (#325) |
| | `for x in it`, `.map`, `.filter`, `.reduce`, `.flatMap` | as any iterator's (#325) |
| | `.lazy.map(f)`, `.lazy.filter(f)` | an `Iterator<U>` of it, moved in, `f` called as each is asked for (#327) |
| an iterator, `var T.next():E?` | `.next()` on a var | the next value as `some`, then `none`; it changes the iterator (#318) |
| | `for x in it` | each value, up to `none`; a var goes on where `break` left it (#318) |
| | `.map(f)`, `.map { ... }` | a new `Array<U>` of `f` of each value (#319) |
| | `.filter(f)`, `.filter { ... }` | a new `Array<E>` of the values `f` says true for (#319) |
| | `.reduce(init, f)`, `.reduce(init) { ... }` | `f` of the value so far and each value, from `init`, of `init`'s type (#319) |
| | `.flatMap(f)`, `.flatMap { ... }` | the Arrays `f` gives each value, concatenated, a new `Array<U>` (#319) |
| a Sequence, `let T.makeIterator():I` | `.makeIterator()` | a fresh iterator, which the Sequence gives each time (#321) |
| | `for x in s` | each value of a fresh iterator; `s` stays as it was, a let too (#321) |
| | `.map`, `.filter`, `.reduce`, `.flatMap` | as an iterator's, of a fresh iterator; `s` stays as it was (#321) |
| | `.lazy.map(f)`, `.lazy.map { ... }` | a lazy Sequence of what `f` gives, `f` called as each is asked for (#323) |
| | `.lazy.filter(f)`, `.lazy.filter { ... }` | a lazy Sequence of the values `f` keeps (#323) |
| a lazy Sequence | `.map`, `.filter` | lazy too, chained (#323) |
| | `for x in l`, `.reduce`, `.flatMap` | as any Sequence's: a fresh walk each time (#323) |

An iterator and a Sequence of the program have the properties of any struct or union, as
[structs.md](structs.md) has them; the general ones are in
[properties.md](properties.md).
