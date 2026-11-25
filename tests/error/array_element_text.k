// an element of a fixed array is of its kind (#752), as a member's is
// (#741): text where a number goes was C's error
let main():int32 {
    var a:[int64](2) = [1, "a"]
    return 0
}
// error: an element of [i64](2) is an i64, and this is text
