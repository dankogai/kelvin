// array initializers are [...] (#48): in declarations, nested in structs,
// designated, as compound literals (T[] counts its items), and inferred
// from items of one type; structs and unions keep {...}
struct point { x: i64; y: i64 }
struct bag { n: i64; xs: [i64](3); p: point }
let sum(a:[const i64], n:i64):i64 { var s = 0; for i in 0..<n { s += a[i] }; return s }
let main():i32 {
    let a:[i32](3) = [1, 2, 3]
    var b:[i64] = [4, 5, 6, 7]
    let c = [1, 2, 3]
    let d = [1.5, 2.5]
    let e = [true, false]
    let m = [[1, 2], [3, 4]]
    let p:point = {1, 2}
    let ps = [p, (point){3, 4}]
    let g:bag = {1, [7, 8, 9], {5, 6}}
    let h:[struct point](2) = [{1, 2}, {3, 4}]
    let sp:[i64](4) = [[2] = 9, [0] = 1]
    let q = ([i32])[10, 20, 30]                // a compound literal declares the array itself (#49)
    let n = sizeof ([i64])[1, 2, 3, 4]
    let s:[u8] = "hi"
    let names:[cstr](2) = ["ab", "cd"]
    var k = 1
    for x in ([i32])[5, 6, 7] { k = k * x }
    println(a[2], " ", b[3], " ", c[1], " ", d[1], " ", e[0], " ", m[1][0], " ", ps[1].y)
    println(g.xs[2], " ", g.p.y, " ", h[1].x, " ", sp[2], " ", sp[1], " ", q[2], " ", n)
    println(s, " ", names[1], " ", k, " ", sum(c, 3), " ", b.size, " ", q.size)
    println(c.typename, " ", d.typename, " ", e.typename, " ", m.typename, " ", ps.typename, " ", q.typename, " ", c.size)
    return 0
}
// out: 3 7 2 2.5 true 3 4
// out: 9 6 3 9 0 30 32
// out: hi cd 210 6 32 12
// out: [i64](3) [f64](2) [bool](2) [[i64](2)](2) [point](2) [i32](3) 24
// c: const int32_t a[3] = {1, 2, 3};
// c: int64_t b[4] = {4, 5, 6, 7};
// c: const int64_t c[3] = {1, 2, 3};
// c: const int64_t m[2][2] = {{1, 2}, {3, 4}};
// c: const struct bag g = {1, {7, 8, 9}, {5, 6}};
// c: const int64_t sp[4] = {[2] = 9, [0] = 1};
// c: const int32_t q[3] = {10, 20, 30};
