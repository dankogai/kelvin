// [T](N) where a value goes is C's zeroed compound literal, its first
// element's address (#49), which a pointer takes; and [T](n)^ is a
// pointer to an array of a count C computes, as [T](N)^ is of one
// written (#362): kc reads both as kelvinc (#737)
let total(p:const int64^, n:int64):int64 {
    var t:int64 = 0
    for i in 0..<n { t += p[i] }
    return t
}
let first(n:int64, r:[int64](n)^):int64 { r^[0] + r^[1] }
let main(argc:int32, argv:[cstr]):int32 {
    var p:int64^ := [int64](3)
    p[1] = 5
    var rows:[int64](2)^ := [[int64](2)](3)
    rows[2][1] = 6
    let bytes:const uint8^ := [uint8](4)
    println(p[0], " ", p[1], " ", total([int64](4), 4), " ", total(p, 3), " ", rows[2][1], " ", bytes[3])
    p := [int64](2)
    println(p[0], " ", p[1])
    let n:int64 = int64(argc) + 2
    var v:[int64](n)
    v[0] = 1
    v[1] = 4
    v[2] = 0
    let r:[int64](n)^ := &v
    let q := &v
    r^[2] = 9
    println(r^[1], " ", r[0][1], " ", r^.count, " ", q^.count, " ", first(n, r), " ", v[2])
    for x in r^ { print(x, " ") }
    println()
    return 0
}
// out: 0 5 0 5 6 0
// out: 0 0
// out: 4 4 3 3 5 9
// out: 1 4 9 
