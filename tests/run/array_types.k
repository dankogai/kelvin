// array types are [T] and [T](N) (#49): members, globals, pointers to
// arrays, parameters (pointers in C), [T](n) zero-filled, also as a VLA,
// .count and .size, compound literals, and the pointer C makes of an array
#import <stdlib.h> as C
struct bag { n: int64; xs: [int64](3); name: [uint8](8) }
var table:[int32](4)
let sum(a:[const int64], n:int64):int64 { var s = 0; for i in 0..<n { s += a[i] }; return s }
let head(a:[int64](4)^):int64 { a^[0] }
let main(argc:int32, argv:[cstr]):int32 {
    var a = [0, 1, 2, 3]
    let b:[float64] = [1.5, 2.5]
    var z = [uint8](5)
    let n:int64 = int64(argc) * 9             // 9: a count C computes, a VLA
    var line = [uint8](n)
    line[n - 1] = 7
    var g:bag = {1, [7, 8, 9], "hey"}
    var m = [[1, 2, 3], [4, 5, 6]]
    var p := a
    let q:[int64](4)^ := &a
    let s:[uint8] = "hello"
    var c = ([int32])[10, 20, 30]
    let d = ([int32](4))[1, 2]
    let e = sizeof([int64](6))
    for i in 0..<a.count { a[i] = a[i] * 2 }
    println(a.count, " ", a.size, " ", b.count, " ", z.count, " ", z[4], " ", line.count, " ", line[0], " ", line[n - 1])
    println(g.xs.count, " ", g.name.count, " ", m.count, " ", m[1].count, " ", p^, " ", q^[3], " ", s.count, " ", c.count)
    println(d.count, " ", d[3], " ", e, " ", table.count, " ", sum(a, a.count), " ", head(&a), " ", a[3])
    println(a.typename, " ", b.typename, " ", z.typename, " ", g.xs.typename, " ", m.typename, " ", q.typename, " ", argv.typename, " ", c.typename)
    return 0
}
// out: 4 32 2 5 0 9 0 7
// out: 3 8 2 3 0 6 6 3
// out: 4 0 48 4 12 0 6
// out: [i64](4) [f64](2) [u8](5) [i64](3) [[i64](3)](2) [i64](4)^ cstr^ [i32](3)
// c: int32_t table[4];
// c: uint8_t z[5] = {0};
// c: uint8_t line[n];
// c: memset(line, 0, sizeof line);
// c: int64_t (*const q)[4] = &a;
// c: (sizeof(a) / sizeof((a)[0]))
