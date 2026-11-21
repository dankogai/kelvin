// so of setting an element past the end (#661)
let main():int32 {
    var a:[i64](3) = [1, 2, 3]
    a[3] = 4
    println(a[0])
    return 0
}
// error: index 3 is past the end of [i64](3): its indices are 0 to 2
