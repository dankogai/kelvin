// a constant index past a fixed array's end is kelvinc's error (#661), where
// C only warned and the program read past it
let main():int32 {
    var a:[i64](3) = [1, 2, 3]
    println(a[5])
    return 0
}
// error: index 5 is past the end of [i64](3): its indices are 0 to 2
