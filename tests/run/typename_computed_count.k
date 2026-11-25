// .typename of a type whose count C computes names it as written (#747),
// [i64](n), and (...) of a count that is no name, where it was C's ?:
// a variable's, a row's, a pointer's, a parameter's, a v.type's, and a
// function's that takes a function of such rows
let apply(n:int64, f:([[int64](n)](2)):int64):int64 { 0 }
let both(n:int64, f:([int64](n)):int64, g:(int64):int64):int64 { 0 }
let grid(n:int64, m:[[int64](n)](2)):int64 {
    println(m.typename, " ", m[0].typename)
    return 0
}
let behind(n:int64, p:[int64](n)^):int64 {
    println(p.typename)
    return 0
}
let main():int32 {
    var n:int64 = 3
    var v:[int64](n)
    var o:[int64?](n)
    var w:[int64](n + 1)
    var r:[[int64](n)](n * 2)
    println(v.typename, " ", o.typename, " ", w.typename)
    println(r.typename, " ", r[0].typename, " ", r[0][0].typename, " ", (&r).typename, " ", (&r[0]).typename)
    var t:v.type
    var u:r.type
    println(t.typename, " ", u.typename, " ", u[0].typename)
    var m:[[int64](3)](2) = [[1, 2, 3], [4, 5, 6]]
    grid(3, m)
    var a:[int64](3) = [1, 2, 3]
    behind(3, &a)
    println(apply.typename)
    println(both.typename)
    return 0
}
// out: [i64](n) [i64?](n) [i64](...)
// out: [[i64](n)](...) [i64](n) i64 [[i64](n)](...)^ [i64](n)^
// out: [i64](n) [[i64](n)](...) [i64](n)
// out: [i64](n)^ [i64](n)
// out: [i64](n)^
// out: (i64, ([[i64](n)](2)):i64):i64
// out: (i64, ([i64](n)):i64, (i64):i64):i64
