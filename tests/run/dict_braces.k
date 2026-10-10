// a Dictionary literal in braces (#69): ${k: v}, ${:}, {k: v} where the type
// is written, Dictionary<K, V>({k: v}), nested, with struct and Array values
struct point { x: i32; y: i32 }
let main():i32 {
    var d = ${"a": 1, "b": 2}
    var e:$[String: i64] = ${:}
    var f:$[String: i64] = {"x": 9}
    var g = Dictionary<i64, String>({1: $"one"})
    var h = Dictionary<String, $[String: i64]>({"in": {"k": 1}})
    var p = ${"o": (point){1, 2}}
    var q:$[String: point] = ${"o": {3, 4}}
    var r = ${"xs": [1, 2], "ys": [3]}
    e["z"] = 26
    println(d.count, " ", d["b"], " ", e.count, " ", f["x"], " ", g[1], " ", h["in"]["k"])
    println(p["o"].y, " ", q["o"].x, " ", r["xs"].count, " ", r.typename)
    var s = $`${d["a"]} and ${"lit"}`
    println(s)
    return 0
}
// out: 2 2 1 9 one 1
// out: 2 3 2 Dictionary<String, Array<i64>>
// out: 1 and lit
// c: _kv_dict_String_point_set(&_kv_d, "o", (struct point){3, 4});
