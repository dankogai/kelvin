// Array<T>(c) of a cstr (#771), which kelvinc built: its address was
// the count, and the program ended, out of memory
let main():int32 {
    var c:cstr := "a"
    var a = Array<int64>(c)
    return 0
}
// error: Array<i64>(n) takes a count, and this is cstr
