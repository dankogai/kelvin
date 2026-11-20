// a built-in subscript takes one index: xs[0, 1] was C's comma, or C's too
// many arguments of an Array's (#627)
let main():int32 {
    var xs = $[1, 2, 3]
    println(xs[0, 1])
    return 0
}
// error: a subscript takes one index, and this gives 2: C's comma is no list of indices; a slice is [lo..<hi]
