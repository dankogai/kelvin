// d[k] = v takes a value of the Dictionary's value type (#246): a number any
// number, as C converts; a String a String or text, which becomes one; an
// Optional its T or none; a struct its own, or a list of it
// out: {"a": 2, "b": 1, "c": 2}{1: "lit", 2: "own"}{1: some(5), 2: none}{"o": {x: 1}, "q": {x: 2}}
struct pt { x: int64 }
let main():int32 {
    var d = ${"a": 1}
    d["a"] = 2
    d["b"] = true
    d["c"] = $"xy".count
    var s:Dictionary<int64, String> = ${:}
    s[1] = "lit"
    s[2] = $"own"
    var o:Dictionary<int64, int64?> = ${:}
    o[1] = 5
    o[2] = none
    var p:Dictionary<String, pt> = ${:}
    p["o"] = (pt){1}
    p["q"] = {2}
    println(d, s, o, p)
    return 0
}
