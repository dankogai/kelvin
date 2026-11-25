// a number where an element that is a pointer goes (#752, #760), a
// bool too: 0 alone is C's null
let main():int32 {
    var ps:[int64^](2) = [0, true]
    return 0
}
// error: an element of [i64^](2) is an i64^, and this is a number
