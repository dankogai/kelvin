// so of a String's, which C built with a warning (#627)
let main():int32 {
    let s = $"abc"
    println(s[0, 1])
    return 0
}
// error: a subscript takes one index, and this gives 2: C's comma is no list of indices; a slice is [lo..<hi]
