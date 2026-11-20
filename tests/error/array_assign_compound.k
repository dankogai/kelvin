// nor by x op= y (#648), C's invalid operands before
let main():int32 {
    var a:[i64](2) = [1, 2]
    a += 1
    println(a[0])
    return 0
}
// error: an array is not assigned: assign its elements, a[i]
