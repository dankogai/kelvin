// a fixed array is not set whole (#648): kelvinc's error, where it was C's
let main():int32 {
    var a:[i64](3)
    a = 1
    println(a[0])
    return 0
}
// error: an array is not assigned: assign its elements, a[i]
