// a struct of one member that is an Array takes it in braces (#764),
// {$[1]}, which kc read as $0 of an anonymous function; a Dictionary in
// a Dictionary's literal; and an array of a v.type's rows
struct one { xs:$[int64] }
let main():int32 {
    var o:one = {$[1]}
    var p:one = {$[1, 2, 3]}
    var q:one = {.xs = $[4, 5]}
    println(o.xs, " ", p.xs.count, " ", q.xs)
    var d:${String: ${String: int64}} = ${"a": ${"b": 1, "c": 2}, "e": ${:}}
    println(d["a"]["b"], " ", d["a"].count, " ", d["e"].count)
    var v:[int64](3)
    var w:[v.type](2)
    w[1][2] = 5
    println(w.count, " ", w[1][2], " ", w[0][0], " ", w.size)
    var z:[v.type](2) = [[1, 2, 3], [4, 5, 6]]
    println(z[1][0], " ", z[0].count)
    return 0
}
// out: [1] 3 [4, 5]
// out: some(1) 2 0
// out: 2 5 0 48
// out: 4 3
