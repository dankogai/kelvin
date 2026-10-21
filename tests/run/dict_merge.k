// d.merge(&e) in place and d.merging(&e) a new Dictionary (#236): e's
// entries added, copied; where a key is in both, the function, trailing
// or after a comma, of d's value and a copy of e's, which it owns, gives
// the one kept, else e's value wins; e by value moves in and is freed.
// An anonymous function's parameters may be named without their types,
// { a, b in ... }, where its context gives them
// out: {"ann": 1, "bob": 10, "cy": 20} {"ann": 1, "bob": 12, "cy": 20} {"ann": 1, "bob": 12, "cy": 20} {"ann": 1, "bob": 210, "cy": 20}
// out: {"ann": 1, "bob": -8, "cy": 20} {"bob": 10, "cy": 20}
// out: {1: "one/uno", 2: "dos"}
// out: {1: "uno", 2: "dos"}
// out: {"k": "wv", "z": "y"}
// out: 42 7 [4] [30, 40]
let add(a:int64, b:int64):int64 { return a + b }

let main():int32 {
    var a = ${"ann": 1, "bob": 2}
    var b = ${"bob": 10, "cy": 20}
    var c = a.merging(&b)
    var d = a.merging(&b) { x, y in x + y }
    var e = a.merging(&b, add)
    var f = a.merging(&b) { $0 * 100 + $1 }
    println(c, " ", d, " ", e, " ", f)
    a.merge(&b) { old, new in old - new }
    println(a, " ", b)
    var s = ${1: $"one"}
    var t = ${1: $"uno", 2: $"dos"}
    s.merge(&t) { p, q in p + "/" + q }
    println(s)
    s.merge(t)
    println(s)
    var u = ${"k": $"v"}.merging(${"k": $"w", "z": $"y"}) { p, q in q + p }
    println(u)
    let times:(int64, int64):int64 := { x, y in x * y }
    var xs:$[int64] = $[]
    xs += 3
    xs += 4
    println(times(6, 7), " ", xs.reduce(0) { acc, x in acc + x }, " ", xs.filter { x in x % 2 == 0 }, " ", xs.map { x in x * 10 })
    return 0
}
