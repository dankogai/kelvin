// a parameter's array of arrays whose inner count C computes, of a
// parameter before it (#366): a pointer to rows of n, as C has it, which
// kc writes as kelvinc does (#703)
let sum(n:i64, m:[[i64](n)](2)):i64 {
    var s:i64 = 0
    for i in 0..<2 {
        for j in 0..<n { s += m[i][j] }
    }
    return s
}
let main():int32 {
    var a:[[i64](3)](2) = [[1, 2, 3], [4, 5, 6]]
    var b:[[i64](2)](2) = [[10, 20], [30, 40]]
    println(sum(3, a), " ", sum(2, b))
    return 0
}
// out: 21 100
