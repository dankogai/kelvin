// a negative constant index is before the start (#661)
let main():int32 {
    var a:[i64](3) = [1, 2, 3]
    println(a[-1])
    return 0
}
// error: index -1 is before the start of [i64](3): its indices are 0 to 2
