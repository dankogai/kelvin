// a variable of the type of a function whose rows count by a parameter
// (#753): let h := apply, where C found no n in the variable's type; a
// row of a count C computes is written with no count in a function
// type, T (*)[], which a row of any count goes to
let apply(n:int64, f:([[int64](n)](2)):int64):int64 {
    var m:[[int64](3)](2) = [[1, 2, 3], [4, 5, 6]]
    return f(m)
}
let grid(n:int64, m:[[int64](n)](2)):int64 { m[1][n - 1] }
let behind(n:int64, p:[int64](n)^):int64 { p^[n - 1] }
let corners(m:[[int64](3)](2)):int64 { m[0][0] + m[1][2] }
let main():int32 {
    let h := apply
    println(h(3, { (m:[[int64](3)](2)):int64 in m[0][1] + m[1][1] }), " ", h(3, corners), " ", h.typename)
    var a:[int64](3) = [1, 2, 3]
    var m:[[int64](3)](2) = [[1, 2, 3], [4, 5, 6]]
    let g := grid
    let b := behind
    println(g(3, m), " ", b(3, &a), " ", b.typename)
    var v := apply
    v := apply
    println(v(3, corners))
    return 0
}
// out: 7 7 (i64, ([[i64](n)](2)):i64):i64
// out: 6 3 (i64, [i64](n)^):i64
// out: 7
