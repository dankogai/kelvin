// error: '.hex' of an array: an array is no pointer; write '(&a[0]).hex'
let main():i32 {
    var a:i32[3] = [1, 2, 3]
    println(a.hex)
    return 0
}
