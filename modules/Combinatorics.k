// modules/Combinatorics.k - permutations, combinations, power sets, base-n
// numbers and Cartesian products (#614), the arrangements of a multiset and
// permutations and combinations of several sizes (#615), each a Sequence
// of $[i64]s that is also indexed, as js-combinatorics and
// swift-combinatorics have them.
//
//     #import <Combinatorics>
//     let p = Permutation(4)                     // of 4, each of size 4
//     println(p.count, " ", p[5])                // 24n [0, 3, 2, 1]
//     let seed = $["a", "b", "c", "d"]
//     for ix in Combination(4, 2) { println(seed.gather(ix)) }   // ["a", "b"] ...
//
// Kelvin has no generic struct of a program's own, so each gives indices,
// 0 to n - 1, and seed.gather(ix) of the prelude turns them into a seed's own
// elements, of an Array of any type or a String's graphemes (#617). Each counts
// in a BigInt, which any count fits: Permutation(36).count is 36!, some
// 3.7e41. p[i] takes an i64 or a BigInt, and gives its element straight;
// for walks them from one to the next, with no BigInt in each step.
//
// The orders are js-combinatorics': a permutation's and a combination's
// lexicographic; a power set's by the bits of the index, and a base-n
// number's and a product's by their digits, the first the fastest.

#import <stdio.h> as C
#import <stdlib.h> as C

// a check that failed: its reason on stderr, and the program ends with
// status 1, or aborts where KELVIN_ABORT is set, as the runtime's checks
// do (#174)
let combinatorics_fail(what:const String^):() {
    fflush(stdout)
    fputs("kelvin: ", stderr)
    fputs(what^.cstr, stderr)
    fputs("\n", stderr)
    if getenv("KELVIN_ABORT") != nowhere { abort() }
    exit(1)
}

let combinatorics_check(ok:bool, what:cstr):() {
    if !ok {
        let m = String(what)
        combinatorics_fail(&m)
    }
}

// ---------- the functions ----------

// n!, 1 of 0
let factorial(n:i64):BigInt {
    combinatorics_check(n >= 0, "factorial(n) is of an n of 0 or more")
    var f = BigInt(1)
    for i in 2...n { f *= i }
    return f
}

// nPk, the k-permutations of n: n! / (n - k)!, 0 where k is past n
let permutation(n:i64, k:i64):BigInt {
    combinatorics_check(n >= 0 && k >= 0, "permutation(n, k) is of an n and a k of 0 or more")
    if k > n { return BigInt(0) }
    var p = BigInt(1)
    for i in n - k + 1...n { p *= i }
    return p
}

// nCk, the k-combinations of n: n! / (k! (n - k)!), 0 where k is past n
let combination(n:i64, k:i64):BigInt {
    combinatorics_check(n >= 0 && k >= 0, "combination(n, k) is of an n and a k of 0 or more")
    if k > n { return BigInt(0) }
    let r:i64 = k < n - k ? k : n - k
    var c = BigInt(1)
    for i in 1...r {
        c *= n - r + i
        c = c / i                                     // exact: c is (n - r + i)! / ((n - r)! i!) now
    }
    return c
}

// the digits of m in the factorial number system, the least first: digit
// i is of radix i + 1, so the first is always 0 (#614)
let factoradic(m:lent BigInt):$[i64] {
    combinatorics_check(!m.isNegative, "factoradic(n) is of an n of 0 or more")
    var digits:$[i64] = $[0]
    var q = m.copy()
    var radix:i64 = 2
    while !q.isZero {
        digits += (q % radix).i64
        q = q / radix
        radix += 1
    }
    return digits
}

let factoradic(m:i64):$[i64] { factoradic(BigInt(m)) }

// the indices of the k-combination of n at index m, in Combination(n, k)'s
// lexicographic order: its combinadic, as js-combinatorics' combinadic(n, k)(m)
let combinadic(n:i64, k:i64, m:lent BigInt):$[i64] {
    combinatorics_check(n >= 0 && k >= 0 && k <= n, "combinadic(n, k, m) is of an n of 0 or more and a k from 0 to n")
    combinatorics_check(!m.isNegative && m < combination(n, k), "combinadic(n, k, m) is of an m from 0 to nCk - 1")
    var digits:$[i64] = $[]
    var rest = m.copy()
    var c:i64 = 0                                     // the next index to weigh
    for j in 0..<k {
        // how many combinations begin with c at place j: C(n - c - 1, k - j - 1)
        var under = combination(n - c - 1, k - j - 1)
        while rest >= under {
            rest -= under
            // C(n - c - 2, r) of C(n - c - 1, r), r = k - j - 1: times (n - c - 1 - r), over (n - c - 1)
            let top:i64 = n - c - 1
            under = under * (top - (k - j - 1))
            under = under / top
            c += 1
        }
        digits += c
        c += 1
    }
    return digits
}

let combinadic(n:i64, k:i64, m:i64):$[i64] { combinadic(n, k, BigInt(m)) }

// a BigInt from 0 to below lim, each about as likely: 64 bits more than
// lim has, reduced, so that the bias is past 2^-64
let combinatorics_random(lim:lent BigInt):BigInt {
    combinatorics_check(!lim.isZero, "sample() of no element: the count is 0")
    var r = BigInt(0)
    var bits = lim.copy()
    while !bits.isZero {
        r = (r << 64) + BigInt(u64.random())
        bits = bits >> 64
    }
    r = (r << 64) + BigInt(u64.random())
    return r % lim
}

// an index as a BigInt, checked against count, of what kind names
let combinatorics_index(i:lent BigInt, count:lent BigInt, kind:cstr):BigInt {
    if i.isNegative || i >= count {
        let at = i.text(10)
        let has = count.text(10)
        var m = $"index "
        m += &at
        m += " is out of range: the "
        m += kind
        m += " has "
        m += &has
        combinatorics_fail(&m)
    }
    return i.copy()
}

// ---------- Permutation ----------

// the k-permutations of 0 to n - 1, in lexicographic order
struct Permutation {
    n: i64
    k: i64
}

let Permutation(n:i64, k:i64):Permutation {
    combinatorics_check(n >= 0 && k >= 0, "Permutation(n, k) is of an n and a k of 0 or more")
    return {n, k}
}

let Permutation(n:i64):Permutation { Permutation(n, n) }

// the walk of a Permutation: all n indices, the first k the element,
// the rest kept in ascending order, so that the next is the next of a
// whole permutation once the rest is turned around
struct Permutation_iterator {
    a: $[i64]
    k: i64
    started: bool
    done: bool
}

let combinatorics_reverse(a:$[i64]^, lo:i64, hi:i64):() {
    var i:i64 = lo
    var j:i64 = hi - 1
    while i < j {
        let t = a^[i]
        a^[i] = a^[j]
        a^[j] = t
        i += 1
        j -= 1
    }
}

var Permutation_iterator.next():$[i64]? {
    if .done { return none }
    let n = .a.count as i64
    if !.started {
        .started = true
        if .k > n {
            .done = true
            return none
        }
        return .a[0..<.k]
    }
    combinatorics_reverse(&.a, .k, n)               // the rest descending: next_permutation moves the first k
    var i:i64 = n - 2
    while i >= 0 && .a[i] >= .a[i + 1] { i -= 1 }
    if i < 0 {
        .done = true
        return none
    }
    var j:i64 = n - 1
    while .a[j] <= .a[i] { j -= 1 }
    let t = .a[i]
    .a[i] = .a[j]
    .a[j] = t
    combinatorics_reverse(&.a, i + 1, n)
    return .a[0..<.k]
}

extend Permutation {
    // nPk
    let count:BigInt { permutation(.n, .k) }

    // the element at i, a BigInt: the first index chosen of n, each of
    // the (n - 1)P(k - 1) that follow, and so on
    let [](i:lent BigInt):$[i64] {
        let total = permutation(.n, .k)
        var rest = combinatorics_index(i, total, "Permutation")
        var left:$[i64] = $[]
        for x in 0..<.n { left += x }
        var out:$[i64] = $[]
        var block = total.copy()
        var m = .n
        for _ in 0..<.k {
            block = block / m                         // the permutations of the rest after one choice
            let d = (rest / block).i64
            rest = rest % block
            out += left[d]
            left.remove(d, 1)
            m -= 1
        }
        return out
    }

    let [](i:i64):$[i64] { self[BigInt(i)] }

    // an element at random, each as likely
    let sample():$[i64] {
        let total = permutation(.n, .k)
        let r = combinatorics_random(total)
        return self[r]
    }

    let makeIterator():Permutation_iterator {
        var a:$[i64] = $[]
        for x in 0..<.n { a += x }
        return {a, .k, false, false}
    }
}

// ---------- Combination ----------

// the k-combinations of 0 to n - 1, each ascending, in lexicographic order
struct Combination {
    n: i64
    k: i64
}

let Combination(n:i64, k:i64):Combination {
    combinatorics_check(n >= 0 && k >= 0, "Combination(n, k) is of an n and a k of 0 or more")
    return {n, k}
}

struct Combination_iterator {
    c: $[i64]
    n: i64
    started: bool
    done: bool
}

var Combination_iterator.next():$[i64]? {
    if .done { return none }
    let k = .c.count as i64
    if !.started {
        .started = true
        if k > .n {
            .done = true
            return none
        }
        return .c.copy()
    }
    var i:i64 = k - 1
    while i >= 0 && .c[i] == .n - k + i { i -= 1 }
    if i < 0 {
        .done = true
        return none
    }
    .c[i] += 1
    for j in i + 1..<k { .c[j] = .c[j - 1] + 1 }
    return .c.copy()
}

extend Combination {
    // nCk
    let count:BigInt { combination(.n, .k) }

    let [](i:lent BigInt):$[i64] {
        let total = combination(.n, .k)
        let at = combinatorics_index(i, total, "Combination")
        return combinadic(.n, .k, at)
    }

    let [](i:i64):$[i64] { self[BigInt(i)] }

    let sample():$[i64] {
        let total = combination(.n, .k)
        let r = combinatorics_random(total)
        return self[r]
    }

    let makeIterator():Combination_iterator {
        var c:$[i64] = $[]
        for x in 0..<.k { c += x }
        return {c, .n, false, false}
    }
}

// ---------- PowerSet ----------

// the subsets of 0 to n - 1, each ascending: subset i holds the places of
// i's bits, so [], [0], [1], [0, 1], [2], ...
struct PowerSet {
    n: i64
}

let PowerSet(n:i64):PowerSet {
    combinatorics_check(n >= 0, "PowerSet(n) is of an n of 0 or more")
    return {n}
}

struct PowerSet_iterator {
    bits: $[bool]
    started: bool
    done: bool
}

let combinatorics_members(bits:const $[bool]^):$[i64] {
    var out:$[i64] = $[]
    for i in 0..<bits^.count as i64 {
        if bits^[i] { out += i }
    }
    return out
}

var PowerSet_iterator.next():$[i64]? {
    if .done { return none }
    if !.started {
        .started = true
        return combinatorics_members(&.bits)
    }
    var i:i64 = 0
    let n = .bits.count as i64
    while i < n && .bits[i] {                         // add 1, the first bit the lowest
        .bits[i] = false
        i += 1
    }
    if i == n {
        .done = true
        return none
    }
    .bits[i] = true
    return combinatorics_members(&.bits)
}

extend PowerSet {
    // 2 ** n
    let count:BigInt { BigInt(1) << .n }

    let [](i:lent BigInt):$[i64] {
        let total = BigInt(1) << .n
        let at = combinatorics_index(i, total, "PowerSet")
        var out:$[i64] = $[]
        for b in 0..<.n {
            if at.bits[b] { out += b }
        }
        return out
    }

    let [](i:i64):$[i64] { self[BigInt(i)] }

    let sample():$[i64] {
        let total = BigInt(1) << .n
        let r = combinatorics_random(total)
        return self[r]
    }

    let makeIterator():PowerSet_iterator {
        var bits:$[bool] = $[]
        for _ in 0..<.n { bits += false }
        return {bits, false, false}
    }
}

// ---------- BaseN and CartesianProduct ----------

// the digits of a mixed radix, the first the fastest: element i of radix
// r has the digits of i in it, the first its lowest
let combinatorics_digits(i:lent BigInt, radix:const $[i64]^):$[i64] {
    var out:$[i64] = $[]
    var q = i.copy()
    for r in radix^ {
        out += (q % r).i64
        q = q / r
    }
    return out
}

let combinatorics_product(radix:const $[i64]^):BigInt {
    var c = BigInt(1)
    for r in radix^ { c *= r }
    return c
}

struct Digits_iterator {
    d: $[i64]
    radix: $[i64]
    started: bool
    done: bool
}

var Digits_iterator.next():$[i64]? {
    if .done { return none }
    let n = .d.count as i64
    if !.started {
        .started = true
        for r in .radix {
            if r == 0 {                               // a radix of 0: no element at all
                .done = true
                return none
            }
        }
        return .d.copy()
    }
    var i:i64 = 0
    while i < n && .d[i] == .radix[i] - 1 {           // add 1, the first digit the lowest
        .d[i] = 0
        i += 1
    }
    if i == n {
        .done = true
        return none
    }
    .d[i] += 1
    return .d.copy()
}

let combinatorics_walk(radix:const $[i64]^):Digits_iterator {
    var d:$[i64] = $[]
    for _ in 0..<radix^.count as i64 { d += 0 }
    return {d, radix^.copy(), false, false}
}

// the numbers of size digits in a base, each digit from 0 to base - 1
struct BaseN {
    base: i64
    digits: i64
}

let BaseN(base:i64, digits:i64):BaseN {
    combinatorics_check(base >= 0 && digits >= 0, "BaseN(base, digits) is of a base and digits of 0 or more")
    return {base, digits}
}

let BaseN(base:i64):BaseN { BaseN(base, base) }

let combinatorics_radix(b:BaseN):$[i64] {
    var r:$[i64] = $[]
    for _ in 0..<b.digits { r += b.base }
    return r
}

extend BaseN {
    // base ** digits
    let count:BigInt { BigInt(.base) ** .digits }

    let [](i:lent BigInt):$[i64] {
        let radix = combinatorics_radix(self)
        let total = combinatorics_product(&radix)
        let at = combinatorics_index(i, total, "BaseN")
        return combinatorics_digits(at, &radix)
    }

    let [](i:i64):$[i64] { self[BigInt(i)] }

    let sample():$[i64] {
        let radix = combinatorics_radix(self)
        let total = combinatorics_product(&radix)
        let r = combinatorics_random(total)
        return combinatorics_digits(r, &radix)
    }

    let makeIterator():Digits_iterator {
        let radix = combinatorics_radix(self)
        return combinatorics_walk(&radix)
    }
}

// the Cartesian product of sets of the sizes given: element i is an index
// into each, the first the fastest
struct CartesianProduct {
    sizes: $[i64]
}

let CartesianProduct(sizes:const $[i64]^):CartesianProduct {
    for s in sizes^ {
        combinatorics_check(s >= 0, "CartesianProduct's sizes are 0 or more")
    }
    return {sizes^.copy()}
}

let CartesianProduct(a:i64, b:i64):CartesianProduct {
    let s = $[a, b]
    return CartesianProduct(&s)
}

let CartesianProduct(a:i64, b:i64, c:i64):CartesianProduct {
    let s = $[a, b, c]
    return CartesianProduct(&s)
}

let CartesianProduct(a:i64, b:i64, c:i64, d:i64):CartesianProduct {
    let s = $[a, b, c, d]
    return CartesianProduct(&s)
}

extend CartesianProduct {
    // the product of the sizes
    let count:BigInt { combinatorics_product(&.sizes) }

    let [](i:lent BigInt):$[i64] {
        let total = combinatorics_product(&.sizes)
        let at = combinatorics_index(i, total, "CartesianProduct")
        return combinatorics_digits(at, &.sizes)
    }

    let [](i:i64):$[i64] { self[BigInt(i)] }

    let sample():$[i64] {
        let total = combinatorics_product(&.sizes)
        let r = combinatorics_random(total)
        return combinatorics_digits(r, &.sizes)
    }

    let makeIterator():Digits_iterator { combinatorics_walk(&.sizes) }
}

// ---------- UniquePermutation ----------

// the arrangements of k of a multiset, each distinct one once: of the
// values given, which may repeat, as swift-combinatorics' UniquePermutation
// of a seed with duplicates (#615). The distinct values are ranked in the
// order they first appear, and the arrangements are in lexicographic
// order of those ranks
struct UniquePermutation {
    values: $[i64]       // each distinct value, in the order it first appears
    counts: $[i64]       // and how many of it there are
    k: i64
}

// the distinct sequences of slots values drawn from a multiset of the
// counts, swift-combinatorics' sequences(): D_t(s) = sum over j copies of
// value t of C(s, j) D_(t-1)(s - j)
let combinatorics_sequences(counts:const $[i64]^, slots:i64):BigInt {
    var h:$[BigInt] = $[]
    for _ in 0...slots { h += BigInt(0) }
    h[0] = BigInt(1)
    var filled:i64 = 0
    for c in counts^ {
        let reach:i64 = slots < filled + c ? slots : filled + c
        var next:$[BigInt] = $[]
        for _ in 0...slots { next += BigInt(0) }
        for s in 0...reach {
            var sum = BigInt(0)
            let lo:i64 = s - filled > 0 ? s - filled : 0
            let hi:i64 = c < s ? c : s
            for j in lo...hi { sum += combination(s, j) * h[s - j] }
            next[s] = sum.copy()
        }
        h = next.copy()
        filled = reach
    }
    return h[slots].copy()
}

let UniquePermutation(vals:const $[i64]^, k:i64):UniquePermutation {
    combinatorics_check(k >= 0, "UniquePermutation(values, k) is of a k of 0 or more")
    var values:$[i64] = $[]
    var counts:$[i64] = $[]
    for v in vals^ {
        var at:i64 = 0 - 1
        for i in 0..<values.count as i64 {
            if values[i] == v { at = i }
        }
        if at < 0 {
            values += v
            counts += 1
        } else {
            counts[at] += 1
        }
    }
    return {values, counts, k}
}

let UniquePermutation(vals:const $[i64]^):UniquePermutation { UniquePermutation(vals, vals^.count as i64) }

// the walk of a UniquePermutation: the ranks of all n values, the first k
// the element, the rest ascending, as a Permutation's walk, whose next
// permutation passes over what is the same
struct UniquePermutation_iterator {
    a: $[i64]
    values: $[i64]
    k: i64
    started: bool
    done: bool
}

let combinatorics_valued(ranks:const $[i64]^, values:const $[i64]^, k:i64):$[i64] {
    var out:$[i64] = $[]
    for i in 0..<k { out += values^[ranks^[i]] }
    return out
}

var UniquePermutation_iterator.next():$[i64]? {
    if .done { return none }
    let n = .a.count as i64
    if !.started {
        .started = true
        if .k > n {
            .done = true
            return none
        }
        return combinatorics_valued(&.a, &.values, .k)
    }
    combinatorics_reverse(&.a, .k, n)
    var i:i64 = n - 2
    while i >= 0 && .a[i] >= .a[i + 1] { i -= 1 }
    if i < 0 {
        .done = true
        return none
    }
    var j:i64 = n - 1
    while .a[j] <= .a[i] { j -= 1 }
    let t = .a[i]
    .a[i] = .a[j]
    .a[j] = t
    combinatorics_reverse(&.a, i + 1, n)
    return combinatorics_valued(&.a, &.values, .k)
}

extend UniquePermutation {
    // the distinct arrangements of k of them
    let count:BigInt { combinatorics_sequences(&.counts, .k) }

    // the element at i: at each place, each value in turn that is left,
    // passing over the arrangements of the rest that begin with it
    let [](i:lent BigInt):$[i64] {
        let total = combinatorics_sequences(&.counts, .k)
        var rest = combinatorics_index(i, total, "UniquePermutation")
        var left = .counts.copy()
        var out:$[i64] = $[]
        var slots:i64 = .k - 1
        while slots >= 0 {
            for t in 0..<left.count as i64 {
                if left[t] > 0 {
                    left[t] -= 1
                    let block = combinatorics_sequences(&left, slots)
                    if rest < block {
                        out += .values[t]
                        break
                    }
                    rest -= block
                    left[t] += 1
                }
            }
            slots -= 1
        }
        return out
    }

    let [](i:i64):$[i64] { self[BigInt(i)] }

    let sample():$[i64] {
        let total = combinatorics_sequences(&.counts, .k)
        let r = combinatorics_random(total)
        return self[r]
    }

    let makeIterator():UniquePermutation_iterator {
        var a:$[i64] = $[]
        for t in 0..<.counts.count as i64 {
            for _ in 0..<.counts[t] { a += t }
        }
        return {a, .values.copy(), .k, false, false}
    }
}

// ---------- Permutations and Combinations ----------

// the sizes of a Range that a set of n has: its values from 0 to n, an
// end past n, or none, being all of them up to n (#615)
let combinatorics_sizes(n:i64, r:Range<i64>):$[i64] {
    combinatorics_check(r.lowerBound >= 0, "the sizes of Permutations and Combinations are 0 or more")
    var out:$[i64] = $[]
    for s in r.prefix(n + 1) {
        if s > n { break }
        out += s
    }
    return out
}

let combinatorics_sizes_checked(n:i64, sizes:const $[i64]^):$[i64] {
    for s in sizes^ {
        combinatorics_check(s >= 0 && s <= n, "the sizes of Permutations and Combinations are from 0 to n")
    }
    return sizes^.copy()
}

// the k-permutations of n for each size k given, in the order given, each
// size's in Permutation(n, k)'s order: swift-combinatorics' Permutations(of:sizes:)
struct Permutations {
    n: i64
    sizes: $[i64]
}

let Permutations(n:i64, sizes:const $[i64]^):Permutations {
    combinatorics_check(n >= 0, "Permutations(n, sizes) is of an n of 0 or more")
    return {n, combinatorics_sizes_checked(n, sizes)}
}

let Permutations(n:i64, sizes:Range<i64>):Permutations {
    combinatorics_check(n >= 0, "Permutations(n, sizes) is of an n of 0 or more")
    return {n, combinatorics_sizes(n, sizes)}
}

struct Permutations_iterator {
    n: i64
    sizes: $[i64]
    at: i64
    inner: Permutation_iterator
}

var Permutations_iterator.next():$[i64]? {
    while .at < .sizes.count as i64 {
        if let x = .inner.next() { return x.copy() }
        .at += 1
        if .at < .sizes.count as i64 { .inner = Permutation(.n, .sizes[.at]).makeIterator() }
    }
    return none
}

extend Permutations {
    // the sum of nPk over the sizes
    let count:BigInt {
        var c = BigInt(0)
        for k in .sizes { c += permutation(.n, k) }
        return c
    }

    let [](i:lent BigInt):$[i64] {
        let total = self.count
        var rest = combinatorics_index(i, total, "Permutations")
        for k in .sizes {
            let block = permutation(.n, k)
            if rest < block { return Permutation(.n, k)[rest] }
            rest -= block
        }
        return Array<i64>()                           // never: the index is checked
    }

    let [](i:i64):$[i64] { self[BigInt(i)] }

    let sample():$[i64] {
        let total = self.count
        let r = combinatorics_random(total)
        return self[r]
    }

    let makeIterator():Permutations_iterator {
        let first:i64 = .sizes.count > 0 ? .sizes[0] : 0
        return {.n, .sizes.copy(), 0, Permutation(.n, first).makeIterator()}
    }
}

// the k-combinations of n for each size k given, in the order given, each
// size's in Combination(n, k)'s order: swift-combinatorics' Combinations(of:sizes:)
struct Combinations {
    n: i64
    sizes: $[i64]
}

let Combinations(n:i64, sizes:const $[i64]^):Combinations {
    combinatorics_check(n >= 0, "Combinations(n, sizes) is of an n of 0 or more")
    return {n, combinatorics_sizes_checked(n, sizes)}
}

let Combinations(n:i64, sizes:Range<i64>):Combinations {
    combinatorics_check(n >= 0, "Combinations(n, sizes) is of an n of 0 or more")
    return {n, combinatorics_sizes(n, sizes)}
}

struct Combinations_iterator {
    n: i64
    sizes: $[i64]
    at: i64
    inner: Combination_iterator
}

var Combinations_iterator.next():$[i64]? {
    while .at < .sizes.count as i64 {
        if let x = .inner.next() { return x.copy() }
        .at += 1
        if .at < .sizes.count as i64 { .inner = Combination(.n, .sizes[.at]).makeIterator() }
    }
    return none
}

extend Combinations {
    // the sum of nCk over the sizes
    let count:BigInt {
        var c = BigInt(0)
        for k in .sizes { c += combination(.n, k) }
        return c
    }

    let [](i:lent BigInt):$[i64] {
        let total = self.count
        var rest = combinatorics_index(i, total, "Combinations")
        for k in .sizes {
            let block = combination(.n, k)
            if rest < block { return Combination(.n, k)[rest] }
            rest -= block
        }
        return Array<i64>()                           // never: the index is checked
    }

    let [](i:i64):$[i64] { self[BigInt(i)] }

    let sample():$[i64] {
        let total = self.count
        let r = combinatorics_random(total)
        return self[r]
    }

    let makeIterator():Combinations_iterator {
        let first:i64 = .sizes.count > 0 ? .sizes[0] : 0
        return {.n, .sizes.copy(), 0, Combination(.n, first).makeIterator()}
    }
}
