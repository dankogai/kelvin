// a subscript of an owning type (#136): the getter gives a copy, the
// setter's new value moves in, and the type's owners are freed as ever
struct Names { xs: Array<String> }
extend Names {
    var [](i:int64):String {
        get { .xs[i].copy() }
        set(v) { .xs[i] = v.copy() }
    }
}
struct Counts { d: Dictionary<String, i64> }
extend Counts {
    var [](k:cstr):i64 {
        get { .d.has(k) ? .d[k] : 0 }
        set(v) { .d[k] = v }
    }
}
let main():i32 {
    var n:Names = {$[$"a", $"b"]}
    n[1] = $"bee"
    let s = n[1]
    println(s, " ", n.xs)
    var c:Counts = {${:}}
    c["a"] += 1
    c["a"] += 1
    c["b"] = 5
    println(c["a"], " ", c["b"], " ", c["z"], " ", c.d)
    return 0
}
// out: bee ["a", "bee"]
// out: 2 5 0 {"a": 2, "b": 5}
