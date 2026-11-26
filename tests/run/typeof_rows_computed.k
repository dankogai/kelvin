// an array whose rows are a v.type of a count C computes (#774), C's
// __typeof__(v) w[2], zeroed, which kc had not yet; its typename is ?,
// as kelvinc names what it does not see through
let main():int32 {
    var n:int64 = 3
    var v:[int64](n)
    var w:[v.type](2)
    w[1][0] = 1
    w[1][1] = 2
    w[1][2] = 5
    var total:int64 = 0
    for x in w[1] { total += x }
    println(w.count, " ", w[1][2], " ", w[0][0], " ", w[0].count, " ", total)
    println(w.typename, " ", w.size)
    return 0
}
// out: 2 5 0 3 8
// out: ? 48
