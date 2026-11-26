// Array<T>(a) of a fixed array of another element (#771), which kelvinc
// copied as it lay
let main():int32 {
    var b:[float64](3) = [1.0, 2.0, 3.0]
    var a = Array<int64>(b)
    return 0
}
// error: Array<i64>(a) takes a fixed array of i64, and this is [f64](3)
