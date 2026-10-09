// a [...] among the elements makes an Array, which Array<i64> cannot hold (#58)
let main():i32 {
    var xs = Array<i64>([[1], [2]])
    return 0
}
// error: '[...]' here makes an Array, and an element of Array<i64> is i64
