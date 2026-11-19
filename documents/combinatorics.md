# Combinatorics: `#import <Combinatorics>`

Permutations, combinations, power sets, base-n numbers and Cartesian
products, each walked by `for` and indexed by a number of any size, as
[js-combinatorics] and [swift-combinatorics] have them.

[js-combinatorics]: https://github.com/dankogai/js-combinatorics
[swift-combinatorics]: https://github.com/dankogai/swift-combinatorics

## Synopsis

```swift
#import <Combinatorics>

let seed = $["a", "b", "c", "d"]

let main():int32 {
    let p = Permutation(4)                       // of 4, each of size 4
    println(p.count, " ", p[0], " ", p[5])       // 24n [0, 1, 2, 3] [0, 3, 2, 1]
    for ix in Combination(4, 2) {                // [0, 1], [0, 2], ... [2, 3]
        print(ix.map { seed[$0] }, " ")          // ["a", "b"] ["a", "c"] ... ["c", "d"]
    }
    println()
    let big = Permutation(36)
    println(big.count, " ", big[big.count - 1][0])   // 371993326789901217467999448150835200000000n 35
    println(PowerSet(3)[5], " ", BaseN(3, 2)[5], " ", CartesianProduct(2, 3)[4])   // [0, 2] [2, 1] [0, 2]
    println(factorial(20), " ", combination(56, 28), " ", factoradic(5))   // 2432902008176640000n 7648690600760440n [0, 1, 2]
    println(Combination(10, 3).sample())         // one of the 120, at random
    return 0
}
```

## Description

Each of the five is a struct of the sizes it is made of: a value, not an
owner, but `CartesianProduct`, which holds its sizes in an Array.

- **Each gives indices,** `0` to `n - 1`, as a `$[i64]`.
  - Kelvin has no generic struct of a program's own, so no
    `Permutation<T>` of a seed's elements, as Swift's.
  - A program picks its own elements by the indices:
    `ix.map { seed[$0] }`, or `seed[ix[k]]`.
  - An anonymous function reads a global and not a local of the
    function around it, C having no closures: a `seed` that `map`
    reads is a global, or the elements are picked by `for`.
- **`x.count` is a `BigInt`,** which any count fits, as
  js-combinatorics' `.length` is a `bigint`: `Permutation(36).count`
  is 36!, some 3.7e41.
- **`x[i]` is the element at index `i`,** straight, of an `i64` or a
  `BigInt`; the order is below.
  - A `BigInt` index is lent ([ownership.md](ownership.md)): `x[b]`
    leaves `b`, and `x[b * 2]` is held for the call.
  - An index below 0 or at the count or past it ends the program,
    `kelvin: index 6 is out of range: the Permutation has 6`, as an
    Array's does.
- **`for ix in x`** walks them in that order, each a new `$[i64]`, from
  one element to the next: no `BigInt` is reckoned in a step.
  - Each is a Sequence ([iterators.md](iterators.md)), so `map`,
    `filter`, `reduce` and `prefix` walk it too: `x.map { $0.copy() }`
    is every element in an Array, each a copy of what the walk holds.
- **`x.sample()`** is an element at random, each about as likely: the
  element at a `BigInt` index from 64 random bits more than the count
  has, reduced. A count of 0 has none, and ends the program.
- **A size below 0 ends the program,** of a maker and of a function
  alike, with what was wrong. Where the program's environment has
  `KELVIN_ABORT`, it aborts instead, as the runtime's checks do.

### `Permutation(n, k)`

The `k`-permutations of `n`, in lexicographic order: `Permutation(4, 2)`
is `[0, 1]`, `[0, 2]`, `[0, 3]`, `[1, 0]`, ... `[3, 2]`, nPk of them.

- `Permutation(n)` is `Permutation(n, n)`, `n!` of them, in the order of
  the factorial number system: `[0, 1, 2, 3]`, `[0, 1, 3, 2]`, ...
  `[3, 2, 1, 0]`.
- A `k` past `n` has none.
- `p.sample()` of `Permutation(n)` is a shuffle, as Fisher and Yates
  make one, of one random number and not `n`.

### `Combination(n, k)`

The `k`-combinations of `n`, each ascending, in lexicographic order:
`Combination(4, 2)` is `[0, 1]`, `[0, 2]`, `[0, 3]`, `[1, 2]`,
`[1, 3]`, `[2, 3]`, nCk of them. `k` is always written: a combination
of all `n` is one. A `k` past `n` has none, and a `k` of 0 has one, `[]`.

### `PowerSet(n)`

The subsets of `n`, each ascending, `2 ** n` of them: subset `i` holds
the places of `i`'s bits, so `[]`, `[0]`, `[1]`, `[0, 1]`, `[2]`, ...,
as js-combinatorics orders them.

### `BaseN(base, digits)`

The numbers of `digits` digits in `base`, each digit from 0 to
`base - 1`, the first the lowest and the fastest: `BaseN(3, 2)` is
`[0, 0]`, `[1, 0]`, `[2, 0]`, `[0, 1]`, ... `[2, 2]`, `base ** digits`
of them. `BaseN(base)` is `BaseN(base, base)`, as Swift's.

### `CartesianProduct(a, b, ...)`

The tuples of an index into each of sets of the sizes given, the first
the fastest: `CartesianProduct(2, 3)` is `[0, 0]`, `[1, 0]`, `[0, 1]`,
... `[1, 2]`, the product of the sizes of them.

- Two, three or four sizes are written as arguments.
- Any number is an Array of them, `CartesianProduct(&sizes)`, as
  js-combinatorics' `CartesianProduct.from`.
- A size of 0 makes none; no sizes at all make one, `[]`.

### The functions

js-combinatorics' and Swift's, each of `i64`s, each count a `BigInt`.

- `factorial(n)` is `n!`; `permutation(n, k)` nPk; `combination(n, k)`
  nCk, 0 where `k` is past `n`.
- `factoradic(m)` is `m` in the factorial number system, its digits the
  least first, digit `i` of radix `i + 1`, so the first is always 0:
  `factoradic(5)` is `[0, 1, 2]`, 1 × 1! + 2 × 2!. `m` is an `i64` or a
  `BigInt`.
- `combinadic(n, k, m)` is `Combination(n, k)[m]`, the indices of the
  `m`th combination, js-combinatorics' `combinadic(n, k)(m)`: Kelvin has
  no closures to give a function of `m`.

## Where it lives

A module, modules/Combinatorics.k, built by `make` into a header and a
library, modules/Combinatorics.kh and `libkCombinatorics`, which a
program that imports it reads and links; see [modules.md](modules.md).
It is written in Kelvin, on the prelude's `BigInt`, and its header
brings in C's `<stdio.h>` and `<stdlib.h>`, for the messages of its
checks, as JSON's brings in `<stdio.h>`.

## Properties and methods

| On | Property or method | Gives |
|---|---|---|
| the module | `Permutation(n, k)`, `Permutation(n)` | the `k`-permutations of `n`, lexicographic; of all `n` |
| | `Combination(n, k)` | the `k`-combinations of `n`, each ascending, lexicographic |
| | `PowerSet(n)` | the subsets of `n`, subset `i` the places of `i`'s bits |
| | `BaseN(base, digits)`, `BaseN(base)` | the numbers of `digits` digits in `base`, the first digit the lowest; of `base` digits |
| | `CartesianProduct(a, b)`, `(a, b, c)`, `(a, b, c, d)`, `(&sizes)` | an index into each of sets of those sizes, the first the fastest |
| | `factorial(n)`, `permutation(n, k)`, `combination(n, k)` | `n!`, nPk, nCk, `BigInt`s |
| | `factoradic(m)` | `m`'s digits in the factorial number system, the least first, a `$[i64]` |
| | `combinadic(n, k, m)` | `Combination(n, k)[m]` |
| each of the five | `.count` | how many, a `BigInt` |
| | `x[i]` | the element at `i`, an `i64` or a `BigInt`, lent; a `$[i64]` of indices |
| | `for ix in x` | each element in order, walked from one to the next |
| | `.map`, `.filter`, `.reduce`, `.prefix` | as of any Sequence |
| | `.sample()` | an element at random |
| `Permutation`, `Combination` | `.n`, `.k` | the sizes it is of |
| `PowerSet` | `.n` | |
| `BaseN` | `.base`, `.digits` | |
| `CartesianProduct` | `.sizes` | the sizes, an `Array<i64>` |
