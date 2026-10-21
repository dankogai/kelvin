// error: '.contains' of Array<i64> looks for an i64, and this is text
let main():int32 {
    var xs = $[1, 2]
    println(xs.contains("a"))
    return 0
}
