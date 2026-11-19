// UniquePermutation, Permutations and Combinations (#615), as
// swift-combinatorics has them: the arrangements of a multiset, each
// distinct one once, and the permutations and combinations of several sizes
#import <Combinatorics>

let main():int32 {
    let u = UniquePermutation(&$[1, 1, 2])
    println(u.count, " ", u.map { $0.copy() }, " ", u[1], " ", u)
    let v = UniquePermutation(&$[3, 1, 3, 2, 1, 3], 4)
    println(v.count, " ", v[0], " ", v[1], " ", v[2], " ", v[37])
    var n = 0
    var same = true
    for x in v {                                   // walked one to the next, as indexed
        if x != v[n] { same = false }
        n += 1
    }
    println(n, " ", same, " ", UniquePermutation(&$[0, 0, 1], 2).map { $0.copy() }, " ", UniquePermutation(&$[1, 2], 3).count)
    var cs:$[i64] = $[]
    for c in $"mississippi".codepoints { cs += c as i64 }
    let ms = UniquePermutation(&cs)                // 11! / (4! 4! 2!)
    var word = $""
    for c in ms[ms.count - 1] { word += c }
    println(ms.count, " ", word)

    let p = Permutations(3, &$[1, 3])              // 3P1 + 3P3
    println(p.count, " ", p.map { $0.copy() })
    let c = Combinations(4, 2...3)                 // 4C2 + 4C3
    println(c.count, " ", c.map { $0.copy() }, " ", c[6])
    let all = Combinations(4, 0...)                // sizes past 4 have none: every subset, by size
    println(all.count, " ", all[0], " ", all[15], " ", Permutations(3, 0...).count, " ", Combinations(5, &Array<i64>()).count)
    let big = Combinations(100, 49...51)
    println(big.count, " ", big[big.count - 1].count, " ", Permutations(20, &$[20])[0].count)
    return 0
}
// out: 3n [[1, 1, 2], [1, 2, 1], [2, 1, 1]] [1, 2, 1] {values: [1, 2], counts: [2, 1], k: 3}
// out: 38n [3, 3, 3, 1] [3, 3, 3, 2] [3, 3, 1, 3] [2, 1, 1, 3]
// out: 38 true [[0, 0], [0, 1], [1, 0]] 0n
// out: 34650n ppssssiiiim
// out: 9n [[0], [1], [2], [0, 1, 2], [0, 2, 1], [1, 0, 2], [1, 2, 0], [2, 0, 1], [2, 1, 0]]
// out: 10n [[0, 1], [0, 2], [0, 3], [1, 2], [1, 3], [2, 3], [0, 1, 2], [0, 1, 3], [0, 2, 3], [1, 2, 3]] [0, 1, 2]
// out: 16n [] [0, 1, 2, 3] 16n 0n
// out: 298717510321180258697189942856n 51 20
