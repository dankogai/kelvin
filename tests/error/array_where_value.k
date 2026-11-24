// an array where a value goes is its first element's address (#736)
let main():int32 {
    var a:[int64](3) = [1, 2, 3]
    var o:int64? = a
    return 0
}
// error: case 'some' of i64? holds an i64, and this is i64^
