// error: '.addr' of an array: an array is no pointer; write '(&a[0]).addr'
let main():int32 {
    var a:[int32](3) = [1, 2, 3]
    println(a.addr)
    return 0
}
