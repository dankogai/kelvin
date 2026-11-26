// zeros of another count where an array is declared (#773), which
// kelvinc took without a word
let main():int32 {
    var a:[int64](2) = [int64](3)
    return 0
}
// error: 'a' is a [i64](2), and this is [i64](3)
