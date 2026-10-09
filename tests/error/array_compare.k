// an Array compares by its elements, not as a whole (#57)
let main():i32 {
    var xs = Array<i64>()
    var ys = Array<i64>()
    println(xs == ys)
    return 0
}
// error: an Array has no operator '==': compare its elements
