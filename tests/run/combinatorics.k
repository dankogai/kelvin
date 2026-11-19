// #import <Combinatorics> (#614): Permutation, Combination, PowerSet, BaseN
// and CartesianProduct, each a Sequence of $[i64]s, counted by a BigInt and
// indexed by an i64 or a BigInt; and factorial, permutation, combination,
// factoradic and combinadic, js-combinatorics' values
#import <Combinatorics>

let seed = $["a", "b", "c", "d"]

let main():int32 {
    let p = Permutation(4)
    println(p.count, " ", p[0], " ", p[5], " ", p[23], " ", p)
    for ix in Combination(4, 2) { print(ix.map { seed[$0] }, " ") }
    println()
    var n = 0
    var last:$[i64] = $[]
    for x in p {                                   // walked one to the next
        n += 1
        last = x.copy()
    }
    println(n, " ", last, " ", Permutation(4, 2).map { $0.copy() })
    println(PowerSet(3).map { $0.copy() }, " ", PowerSet(3)[5], " ", PowerSet(0).count)
    println(BaseN(3, 2).map { $0.copy() }, " ", BaseN(2).count, " ", BaseN(0, 1).count)
    println(CartesianProduct(2, 3).map { $0.copy() }, " ", CartesianProduct(2, 0, 3).count)
    let sizes = $[3, 1, 2]
    println(CartesianProduct(&sizes)[5], " ", Combination(3, 4).count, " ", Combination(3, 0).map { $0.copy() })

    // big: a count of any size, an index a BigInt
    let big = Permutation(36)
    let at = big.count - 1
    println(big.count, " ", big[at], " ", at)
    let half = Combination(100, 50)
    println(half.count, " ", half[half.count - 1].count, " ", half[half.count - 1][0])
    println(PowerSet(64).count, " ", BaseN(16, 16)[BaseN(16, 16).count - 1].count)

    // js-combinatorics' functions
    println(permutation(24, 12), " ", permutation(26, 13), " ", combination(56, 28), " ", combination(58, 29))
    println(factorial(0), " ", factorial(18), " ", factorial(19), " ", permutation(3, 4))
    println(factoradic(6402373705727999), " ", factoradic(0), " ", factoradic(5))
    println(combinadic(16, 8, 0), " ", combinadic(16, 8, 12869), " ", combinadic(16, 8, 100) == Combination(16, 8)[100])

    // sample: one element, each as likely
    let s = Permutation(5).sample()
    var sorted = s.copy()
    sorted.sort()
    println(s.count, " ", sorted, " ", Combination(10, 3).sample().count, " ", PowerSet(5).sample().count <= 5)
    return 0
}
// out: 24n [0, 1, 2, 3] [0, 3, 2, 1] [3, 2, 1, 0] {n: 4, k: 4}
// out: ["a", "b"] ["a", "c"] ["a", "d"] ["b", "c"] ["b", "d"] ["c", "d"] 
// out: 24 [3, 2, 1, 0] [[0, 1], [0, 2], [0, 3], [1, 0], [1, 2], [1, 3], [2, 0], [2, 1], [2, 3], [3, 0], [3, 1], [3, 2]]
// out: [[], [0], [1], [0, 1], [2], [0, 2], [1, 2], [0, 1, 2]] [0, 2] 1n
// out: [[0, 0], [1, 0], [2, 0], [0, 1], [1, 1], [2, 1], [0, 2], [1, 2], [2, 2]] 4n 0n
// out: [[0, 0], [1, 0], [0, 1], [1, 1], [0, 2], [1, 2]] 0n
// out: [2, 0, 1] 0n [[]]
// out: 371993326789901217467999448150835200000000n [35, 34, 33, 32, 31, 30, 29, 28, 27, 26, 25, 24, 23, 22, 21, 20, 19, 18, 17, 16, 15, 14, 13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1, 0] 371993326789901217467999448150835199999999n
// out: 100891344545564193334812497256n 50 50
// out: 18446744073709551616n 16
// out: 1295295050649600n 64764752532480000n 7648690600760440n 30067266499541040n
// out: 1n 6402373705728000n 121645100408832000n 0n
// out: [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17] [0] [0, 1, 2]
// out: [0, 1, 2, 3, 4, 5, 6, 7] [8, 9, 10, 11, 12, 13, 14, 15] true
// out: 5 [0, 1, 2, 3, 4] 3 true
