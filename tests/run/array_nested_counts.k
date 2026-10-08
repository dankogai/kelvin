// [[T]] with a value counts every dimension from the rows (#49): the first
// row's count, which every row matches, so C gets the inner counts it needs
let main():i32 {
    var array3d:[[[i32]]] = [[[0, 1], [0, 1]], [[0, 1], [0, 1]]]
    var m:[[i64]] = [[1, 2, 3], [4, 5, 6]]
    let c = ([[i32]])[[7, 8], [9, 10]]
    println(array3d.typename, " ", array3d[1][1][1], " ", array3d.count, " ", array3d[0].count)
    println(m.typename, " ", m[1][2], " ", c.typename, " ", c[1][0])
    return 0
}
// out: [[[i32](2)](2)](2) 1 2 2
// out: [[i64](3)](2) 6 [[i32](2)](2) 9
// c: int32_t array3d[2][2][2] = {{{0, 1}, {0, 1}}, {{0, 1}, {0, 1}}};
// c: int64_t m[2][3] = {{1, 2, 3}, {4, 5, 6}};
