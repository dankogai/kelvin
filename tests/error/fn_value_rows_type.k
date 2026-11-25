// a function of rows of another type where rows of a count C computes
// go (#748), its type named as it is written, the array an array, by kc
// too (#754), which named its pointer
let apply(n:int64, f:([[int64](n)](2)):int64):int64 {
    var m:[[int64](3)](2) = [[1, 2, 3], [4, 5, 6]]
    return f(m)
}
let main():int32 {
    println(apply(3, { (m:[[float64](3)](2)):int64 in 1 }))
    return 0
}
// error: this is ([[f64](3)](2)):i64, where ([[i64](n)](2)):i64 goes
