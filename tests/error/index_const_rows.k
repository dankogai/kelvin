// a row's index too, of an array of arrays (#661)
let main():int32 {
    var m:[[i64](2)](3) = [[1, 2], [3, 4], [5, 6]]
    println(m[1][2])
    return 0
}
// error: index 2 is past the end of [i64](2): its indices are 0 to 1
