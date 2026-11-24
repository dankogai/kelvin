// a function type's parameter whose rows count by another parameter,
// f:([[i64](n)](2)):i64 (#743): a pointer to a row in C, which a
// function of rows of three goes to
let apply(n:int64, f:([[int64](n)](2)):int64):int64 {
    var m:[[int64](3)](2) = [[1, 2, 3], [4, 5, 6]]
    return f(m)
}
let main():int32 {
    println(apply(3, { (m:[[int64](3)](2)):int64 in m[0][0] + m[1][2] }))
    println(apply(3, { (m:[[int64](3)](2)):int64 in m[0][1] * m[1][1] }))
    return 0
}
// out: 7
// out: 10
