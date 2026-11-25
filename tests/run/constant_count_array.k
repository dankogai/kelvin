// an array whose count is a constant C computes, [i64](sizeof(i64)),
// [i64](K) of an enumerator or [i64](2 * 4), is declared with no value
// (#756), by kc as by kelvinc, where kc asked for its elements
enum { K = 3 }
let main():int32 {
    var a:[int64](sizeof(int64))
    var b:[int64](K)
    var c:[uint8](2 * 4)
    var d:[[int64](K)](2)
    a[7] = 1
    b[2] = 2
    c[7] = 3
    d[1][2] = 4
    println(a.count, " ", b.count, " ", c.count, " ", d.count, " ", d[0].count)
    println(a[7], " ", b[2], " ", c[7], " ", d[1][2])
    println(a.typename, " ", b.typename, " ", c.typename, " ", d.typename)
    return 0
}
// out: 8 3 8 2 3
// out: 1 2 3 4
// out: [i64](...) [i64](K) [u8](...) [[i64](K)](2)
