// a value read through const is a value (#738): the variable inferred
// of it is of the plain type, which a var changes, where it was const
// itself and C refused the change; the read is const and named so, a
// pointer's own const after it, as const i64^ const^
let main():int32 {
    let s:cstr := "abc"
    var d = s[0]
    d += 1
    var a:[int64](2) = [1, 2]
    let q:const int64^ := &a[0]
    var y = q[1]
    y += 40
    let k:int64 = 3
    let p := &k
    var z = p^
    z = 4
    let c:[const int64](2) = [5, 6]
    var x = c[0]
    x = 9
    println(d, " ", y, " ", z, " ", x)
    println(d.typename, " ", y.typename, " ", z.typename, " ", x.typename)
    println(s[1].typename, " ", q[1].typename, " ", q^.typename, " ", p^.typename, " ", c[0].typename)
    let names:[const cstr] = ["a", "b"]
    let pp := &q
    println(names.typename, " ", names[0].typename, " ", pp.typename, " ", p.typename)
    return 0
}
// out: 98 42 4 9
// out: u8 i64 i64 i64
// out: const u8 const i64 const i64 const i64 const i64
// out: [cstr const](2) cstr const const i64^ const^ const i64^
