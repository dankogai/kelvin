// a designated element's value is of the array's kind (#752, #757):
// kc says it, where it left the value to C
let main():int32 {
    var xs:[int64](3) = [[1] = "a"]
    return 0
}
// error: an element of [i64](3) is an i64, and this is text
