// a w:v.type of an array of a count C computes is read as the array
// (#756): its count and size, its elements, a walk and its text, by kc
// as by kelvinc, where kc knew no member of it and walked none
let main():int32 {
    var n:int64 = 3
    var v:[int64](n)
    var w:v.type
    w[0] = 1
    w[1] = 2
    w[2] = 3
    println(w.count, " ", w.size, " ", w.typename)
    for x in w { print(x, " ") }
    println(w)
    let p := &w[1]
    w[1] = 4
    println(p^)
    var rows:[[int64](n)](2)
    var again:rows.type
    again[1][2] = 6
    println(again.count, " ", again[0].count, " ", again[1][2], " ", again.typename)
    return 0
}
// out: 3 24 [i64](n)
// out: 1 2 3 [1, 2, 3]
// out: 4
// out: 2 3 6 [[i64](n)](2)
