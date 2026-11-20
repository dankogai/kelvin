// a fixed array is not set by a literal after it is declared (#648),
// where kelvinc said the literal is no value here
let main():int32 {
    var a:[i64](2) = [1, 2]
    a = [3, 4]
    println(a[0])
    return 0
}
// error: an array is not assigned: assign its elements, a[i]
