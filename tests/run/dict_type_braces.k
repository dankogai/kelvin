// a Dictionary type in braces (#70): ${K: V}, nested, as a parameter, a
// member, with Array and struct values
let total(d:${String: i64}^):i64 {
    var n:i64 = 0
    for k, v in d^ { n += v }
    return n
}
struct bag { m: ${i64: $[String]}; name: String }
let main():i32 {
    var d:${String: i64} = ${:}
    d["a"] = 1; d["b"] = 2
    var n:${String: ${String: i64}} = ${"x": {"y": 3}}
    var b:bag = {${1: $["one"]}, $"b"}
    var p:${String: {x:f64, y:f64}} = ${"o": {1.0, 2.0}}
    println(total(&d), " ", d.typename, " ", n["x"]["y"], " ", n.typename, " ", b.m[1][0], " ", p["o"].y, " ", p.typename)
    return 0
}
// out: 3 Dictionary<String, i64> 3 Dictionary<String, Dictionary<String, i64>> one 2.0 Dictionary<String, {x: f64, y: f64}>
// c: int64_t total(_kv_dict_String_i64 *const d)
// c: _kv_dict_i64_Array_String m;
