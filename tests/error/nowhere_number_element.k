// nowhere where an element that is a number goes (#764)
let main():int32 {
    var a:[int64](2) = [nowhere, 1]
    return 0
}
// error: an element of [i64](2) is an i64, and this is any^
