// a row of an array of arrays is an array, no number (#736)
let main():int32 {
    var a:[[int64](2)](2) = [[1, 2], [3, 4]]
    var x:int64 = a[1]
    return 0
}
// error: 'x' is an i64, and this is i64^
