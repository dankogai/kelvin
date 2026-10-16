// error: '.hex' of an array: an array is no pointer; write '(&a[0]).hex'
let main():int32 {
    var a:[int32](3) = [1, 2, 3]
    println(a.hex)
    return 0
}
