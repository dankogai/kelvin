// an enum's case holds a fixed array (#361): made of [a, b] or of an
// array, set, bound by switch and if let to a copy, read through v.c, of
// a call's value too, printed, and compared element by element
enum shape { dot; tri: [int64](3); pair: [float64](2); names: [cstr](2) }
let area(s:shape):int64 {
    switch s {
    case dot: return 0
    case tri(t): return t[0] + t[1] + t[2]
    case pair(p): return p.count
    case names(ns): return ns.count
    }
    return -1
}
let mk(i:int64):shape { return shape.tri([i, i + 1, i + 2]) }
let main():int32 {
    let a = shape.tri([3, 4, 5])
    var b = shape.pair([1.5, 2.5])
    let c = shape.names(["x", "y"])
    var sides = [6, 7, 8]
    let d = shape.tri(sides)
    println(area(a), " ", area(b), " ", area(c), " ", area(d), " ", area(shape.dot))
    println(a, " ", b, " ", c)
    println(a == shape.tri([3, 4, 5]), " ", a == d, " ", b != shape.pair([1.5, 2.5]))
    if let tri(t) = d { println(t[2], " ", t.count) }
    println(a.tri[1], " ", a.tri.count, " ", mk(4).tri[1])
    b.pair = [9.5, 0.5]
    println(b)
    return 0
}
// out: 12 2 2 21 0
// out: tri([3, 4, 5]) pair([1.5, 2.5]) names(["x", "y"])
// out: true false false
// out: 8 3
// out: 4 3 5
// out: pair([9.5, 0.5])
// c: typedef int64_t _kv_shape_tri_t[3];
// c: memcpy(_kv_v.u.tri, v, sizeof _kv_v.u.tri);
