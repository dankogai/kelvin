// and of a Dictionary's (#627)
let main():int32 {
    var d:${i64: i64} = ${:}
    d[1] = 2
    println(d[1, 0])
    return 0
}
// error: a subscript takes one index, and this gives 2: C's comma is no list of indices; a slice is [lo..<hi]
