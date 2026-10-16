// a [...] among the elements makes an Array, which Array<i64> cannot hold (#58)
let main():int32 {
    var xs = Array<int64>([[1], [2]])
    return 0
}
// error: '[...]' here makes an Array, and an element of Array<i64> is i64
