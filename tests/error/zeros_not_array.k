// [T](n) is an array's zeros, its first element's address where a value goes (#48, #724)
let main():int32 {
    var x:int64 = [int64](3)
    return 0
}
// error: 'x' is an i64, and this is i64^
