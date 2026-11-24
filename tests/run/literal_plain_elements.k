// an element of a literal whose type is inferred is a value (#746): read
// through const, or of a volatile, it is of the plain type, as a
// variable inferred of it is (#738), where the Array, the Dictionary and
// the Set were of const elements and C warned or refused, and the fixed
// array's elements were const
let main():int32 {
    var x:int64 = 1
    let q:const int64^ := &x
    var a = $[q[0]]
    a += 2
    var f = [q[0], q[0]]
    f[0] = 3
    var d = ${"k": q[0]}
    d["j"] = 2
    var s = ${q[0]}
    var e = ${q[0]: q[0]}
    println(a, " ", f[0], " ", d.count, " ", s, " ", e)
    println(a.typename, " ", f.typename, " ", d.typename, " ", s.typename, " ", e.typename)
    var nested = $[[q[0]], [2]]
    var rows = [[q[0], 1], [2, 3]]
    rows[0][0] = 5
    println(nested, " ", rows[0][0], " ", nested.typename, " ", rows.typename)
    var p:int64^ const := &x
    var ps = $[p]
    var pf = [p, p]
    pf[0] := nowhere
    let name:cstr const := "a"
    var names = $[name]
    println(ps[0]^, " ", pf[1]^, " ", names, " ", ps.typename, " ", pf.typename, " ", names.typename)
    var v:volatile int64 = 2
    var va = $[v]
    var vf = [v, v]
    var w = v
    w += 1
    println(va, " ", vf[1], " ", w, " ", va.typename, " ", vf.typename, " ", w.typename, " ", v.typename)
    let k:int64 = 3
    let r := &k
    var rs = $[r]
    println(rs[0]^, " ", rs.typename)
    return 0
}
// out: [1, 2] 3 2 {1} {1: 1}
// out: Array<i64> [i64](2) Dictionary<String, i64> Set<i64> Dictionary<i64, i64>
// out: [[1], [2]] 5 Array<Array<i64>> [[i64](2)](2)
// out: 1 1 ["a"] Array<i64^> [i64^](2) Array<cstr>
// out: [2] 2 3 Array<i64> [i64](2) i64 volatile i64
// out: 3 Array<const i64^>
