// one fixed array is not assigned to another (#648)
let main():int32 {
    var a:[i64](2) = [1, 2]
    var b:[i64](2) = [3, 4]
    a = b
    println(a[0])
    return 0
}
// error: an array is not assigned: assign its elements, a[i]
