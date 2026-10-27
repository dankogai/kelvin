// typeof(x) and typeof(T) (#398), C23's, kept as C has it: x's type with
// its own qualifiers, a let's const too, which x.type leaves; T itself;
// of an expression kelvinc does not see, C's __typeof__
struct point { x:i32, y:i32 }
let main():i32 {
    var n:i64 = 3
    let k:i64 = 4
    var a:typeof(n) = 5
    var p:point = {1, 2}
    var q:typeof(p) = {3, 4}
    var r:typeof(point) = {5, 6}
    let pp:typeof(p)^ := &p
    var s:typeof(n + 1.5) = 2.5
    var xs = [i16](3)
    var ys:typeof(xs)
    let c:typeof(k) = 9
    var w:k.type = 1
    w = 2
    println(a, " ", q, " ", r, " ", pp^.y, " ", s, " ", ys.count, " ", a.typename, " ", s.typename)
    println(sizeof(typeof(p)), " ", 9 as typeof(n), " ", c.typename, " ", w.typename, " ", (typeof(p)){7, 8})
    return 0
}
// out: 5 {x: 3, y: 4} {x: 5, y: 6} 2 2.5 3 i64 f64
// out: 8 9 const i64 i64 {x: 7, y: 8}
// c:     __typeof__(n + 1.5) s = 2.5;
// c:     const int64_t c = 9;
