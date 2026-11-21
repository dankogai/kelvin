// what #661 leaves as it was: a constant index inside the array, the last
// too, and an index that is no constant, which C does not check
let main():int32 {
    var a:[i64](3) = [1, 2, 3]
    var m:[[i64](2)](3) = [[1, 2], [3, 4], [5, 6]]
    a[2] = 9
    var i:i64 = 1
    println(a[0], " ", a[2], " ", m[2][1], " ", a[i])
    return 0
}
// out: 1 9 6 2
