// q[i] of a pointer steps it, as C's: of a T^ the T i places on, and of
// a [T](N)^, a pointer to a whole array, the array i rows on (#726); so
// q[0] is q^, and q[1] a next row only where q points among rows
struct grid { rows:[[int64](3)](2) }
let second(q:[int64](3)^):int64 { q[1][0] }
let total(q:[int64](3)^, n:int64):int64 {
    var t:int64 = 0
    for i in 0..<n { for x in q[i] { t += x } }
    return t
}
let main():int32 {
    var two:[[int64](3)](2) = [[1, 2, 3], [4, 5, 6]]
    var r:[int64](3)^ := &two[0]
    println(r[1][2], " ", r[1], " ", r[0], " ", r[1].count, " ", r[1].typename, " ", sizeof(r[1]))
    r[1][0] = 9
    r[0][2] += 1
    println(two, " ", second(r), " ", total(r, 2), " ", (r + 1)^[2])
    for x in r[1] { print(x, " ") }
    println()
    // of a single array, q[0] is the array
    var sq:[int64](4) = [1, 4, 9, 16]
    let q:[int64](4)^ := &sq
    println(q^[1], " ", q[0][1], " ", q[0].count)
    // a member's rows, and an element's address
    var g:grid = {[[1, 2, 3], [4, 5, 6]]}
    let m:[int64](3)^ := &g.rows[0]
    let p := &m[1][1]
    println(p^, " ", m[1][1].typename, " ", m[1] == m[0])
    // a T^'s element is a T
    var a:[int64](3) = [1, 2, 3]
    var e:int64^ := &a[0]
    e[1] += 300
    let x = e[1]
    var f:[float64](2) = [1.5, 2.5]
    let fp:float64^ := &f[0]
    println(a[1], " ", x.typename, " ", (e[1] + 1).typename, " ", fp[1], " ", fp[1].typename)
    return 0
}
// out: 6 [4, 5, 6] [1, 2, 3] 3 [i64](3) 24
// out: [[1, 2, 4], [9, 5, 6]] 9 27 6
// out: 9 5 6 
// out: 4 4 4
// out: 5 i64 false
// out: 302 i64 i64 2.5 f64
