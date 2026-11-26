// rows of no count written whose first is zeros take the zeros' count
// (#773, #777), which was C's error of kc's C
let main():int32 {
    var m:[[int64]](3) = [[int64](2), [3, 4], [5, 6]]
    println(m[0][1], " ", m[1][0], " ", m[2][1], " ", m[0].count, " ", m.count, " ", m.size)
    return 0
}
// out: 0 3 6 2 3 48
