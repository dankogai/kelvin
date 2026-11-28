// a fixed array of a count C computes, a local's or a global let's, read
// where a pointer's Optional or an Array's element goes is its first
// element's address (#787), as one of a count written is (#781, #784):
// kc's C refused it
let N:int64 = 3

let main():int32 {
    let n:int64 = 2
    var b:[int64](n)
    b[0] = 4
    var c:[int64](N)
    c[0] = 6
    var q:int64^? = b
    var r:int64^? = c
    var a = $[b]
    var t:$[int64^] = $[c]
    t += b
    var d = ${"k": b}
    println(q!^, " ", r!^, " ", a[0]^, " ", t.count, " ", t[1]^, " ", d.count)
    println(a.typename, " ", d.typename)
    return 0
}
// out: 4 6 4 2 4 1
// out: Array<i64^> Dictionary<String, i64^>
