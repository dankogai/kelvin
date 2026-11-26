// a fixed array read where an element goes is its first element's
// address (#781): $[b], ${"k": b}, Array([b]) and [b, c], no type
// written, are of i64^, which kc refused, an Array of [i64](2) is not
// here yet; and it goes where an i64^ is the element
let main():int32 {
    var b:[int64](2) = [1, 2]
    var c:[int64](3) = [3, 4, 5]
    var a = $[b, c]
    var d = ${"k": b}
    var m = Array([c])
    var f = [b, c]
    var t:$[int64^] = $[b]
    t += c
    println(a.count, " ", a[1]^, " ", d.count, " ", m[0]^, " ", f.count, " ", f[0]^, " ", t.count, " ", t[1]^)
    println(a.typename, " ", d.typename, " ", f.typename)
    return 0
}
// out: 2 3 1 3 2 1 2 3
// out: Array<i64^> Dictionary<String, i64^> [i64^](2)
