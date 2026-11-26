// Array<T>(x) takes a count (#771): text is none, which was C's error,
// incompatible pointer to integer conversion
let main():int32 {
    var a = Array<int64>("a")
    return 0
}
// error: Array<i64>(n) takes a count, and this is text
