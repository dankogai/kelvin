// an Array compares by its elements, not as a whole (#57)
let main():int32 {
    var xs = Array<int64>()
    var ys = Array<int64>()
    println(xs == ys)
    return 0
}
// error: an Array has no operator '==': compare its elements
