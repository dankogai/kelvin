// an array is declared with its elements, [...], or its zeros (#48, #741)
let main():int32 {
    var a:[int64](3) = 5
    return 0
}
// error: 'a' is a [i64](3), and this is a number
