// a member and a row that are arrays take zeros, [T](n), and a compound
// literal, ([T])[a, b] (#773), as a declaration does, where they were
// C's errors; and an array of no count written takes its zeros' count
struct grid { cells:[int64](2) }
let main():int32 {
    var g:grid = {[int64](2)}
    var h:grid = {.cells = ([int64])[3, 4]}
    var m:[[int64](2)](3) = [[int64](2), ([int64])[5, 6], [7, 8]]
    var a:[int64] = [int64](2)
    var b:[int64] = ([int64])[1, 2, 3]
    println(g.cells[0], " ", g.cells[1], " ", h.cells[0], " ", h.cells[1])
    println(m[0][1], " ", m[1][0], " ", m[1][1], " ", m[2][0])
    println(a.count, " ", a[1], " ", b.count, " ", b[2])
    return 0
}
// out: 0 0 3 4
// out: 0 5 6 7
// out: 2 0 3 3
