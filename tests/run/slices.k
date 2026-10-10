// slices (#68): xs[lo..<hi], xs[lo...hi], xs[lo...], xs[..<hi], xs[...hi] of
// an Array, a String (by codepoint) and a Bytes, each a new copy, which a
// variable owns; the range is checked at run time
let main():i32 {
    var xs = $[10, 20, 30, 40, 50]
    var a = xs[1..<3]
    var b = xs[1...3]
    var c = xs[3...]
    var d = xs[..<2]
    var e = xs[...2]
    var f = xs[2..<2]
    println(a.count, " ", a[0], " ", a[1], " ", b.count, " ", b[2], " ", c.count, " ", c[0])
    println(d.count, " ", e.count, " ", f.count, " ", a.typename)
    var s = $"héllo, wörld"
    var t = s[1..<5]
    var u = s[7...]
    var v = s[...0]
    println(t, " ", t.count, " ", u, " ", u.count, " ", v, " ", v.count, " ", t.typename)
    var bs = Bytes("abcdef")
    var bt = bs[2..<4]
    println(bt, " ", bt.count)
    var names = $[$"ann", $"bob", $"cy"]
    var two = names[1...]
    two[0] += "!"
    println(two[0], " ", names[1], " ", two.count)
    let n:i64 = 1
    var g = xs[n..<n + 2]
    println(g[1])
    return 0
}
// out: 2 20 30 3 40 2 40
// out: 2 3 0 Array<i64>
// out: éllo 4 wörld 5 h 1 String
// out: cd 2
// out: bob! bob 2
// out: 30
// c: _kv_array_i64 a = _kv_array_i64_slice(&xs, 1, 3);
// c: _kv_array_i64 c = _kv_array_i64_slice(&xs, 3, (xs).count);
// c: kv_string t = kv_string_slice(&s, 1, 5);
// c: kv_bytes bt = kv_bytes_slice(&bs, 2, 4);
