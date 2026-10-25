// .prefix(n) takes a count, an integer (#372)
let main():int32 {
    let xs = $[1, 2, 3]
    println(xs.prefix(1.5))
    return 0
}
// error: '.prefix' takes a count, an integer, or a function that says whether to keep each value, and this is a floating-point number
