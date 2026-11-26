// Array<T>(nowhere) (#771): an any^ is no count, which was C's error
let main():int32 {
    var a = Array<int64>(nowhere)
    return 0
}
// error: Array<i64>(n) takes a count, and this is any^
