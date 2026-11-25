// a function whose parameter is a fixed array is a value of its type as
// written (#754), ([i64](3)):i64, and goes where a function type that
// is the same in C goes: the array's pointer, i64^, an array of no
// count, and rows behind a pointer; kc reads them as kelvinc
let three(m:[int64](3)):int64 { m[0] }
let open(m:[int64]):int64 { m[1] }
let behind(m:int64^):int64 { m[2] }
let rows(m:[[int64](3)](2)):int64 { m[1][2] }
let rowp(m:[int64](3)^):int64 { m[1][0] }
let fixed(m:[const int64](3)):int64 { m[0] }
let take3(f:([int64](3)):int64):int64 {
    var a:[int64](3) = [7, 8, 9]
    return f(a)
}
let takep(f:(int64^):int64):int64 {
    var a:[int64](3) = [7, 8, 9]
    return f(a)
}
let takeg(f:([[int64](3)](2)):int64):int64 {
    var m:[[int64](3)](2) = [[1, 2, 3], [4, 5, 6]]
    return f(m)
}
let main():int32 {
    println(three.typename, " ", open.typename, " ", behind.typename)
    println(rows.typename, " ", rowp.typename, " ", fixed.typename)
    println(take3(three), " ", take3(open), " ", take3(behind), " ", takep(three), " ", takep(behind))
    println(takeg(rows), " ", takeg(rowp))
    println(take3({ (m:[int64](3)):int64 in m[1] }), " ", take3({ (m:int64^):int64 in m[2] }), " ", take3({ $0[0] }))
    let h := three
    let g:(int64^):int64 := three
    let k := { (m:[int64](3)):int64 in m[1] }
    var a:[int64](3) = [1, 2, 3]
    println(h.typename, " ", g.typename, " ", k.typename, " ", h(a), " ", g(a), " ", k(a))
    return 0
}
// out: ([i64](3)):i64 ([i64]):i64 (i64^):i64
// out: ([[i64](3)](2)):i64 ([i64](3)^):i64 ([const i64](3)):i64
// out: 7 8 9 7 9
// out: 6 4
// out: 8 9 7
// out: ([i64](3)):i64 (i64^):i64 ([i64](3)):i64 1 1 2
