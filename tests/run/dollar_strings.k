// $[...] and ${...} make their text Strings at any depth (#616), as if
// each were $"...": $["a"] is an Array<String>, and $"" is the type
// String; a type written wins, so $["a"] where a $[cstr] goes is of cstrs
struct box { names: $[cstr] }
let twice(s:$""):$"" { s + s }
let first():$[[cstr]] { return $[["r", "s"], ["t"]] }
let count(xs:$[cstr]):i64 { xs.count as i64 }
let main():int32 {
    let a = $["a", "b"]
    let b = $[["a"], ["b", "c"]]
    let c = ${"k": "v"}
    let e = $[`a${1}`, """x"""]
    let f = $[{"a": 1}, {"b": 2}]
    let g = ${"k": {"x": "y"}}
    println(a.typename, " ", b.typename, " ", c.typename, " ", e.typename)
    println(f.typename, " ", g.typename)
    println(a, " ", b, " ", c, " ", e, " ", f, " ", g)
    var i:$[$""] = $[]
    i += $"q"
    let j:${$"": $[$""]} = ${"k": ["v"]}
    let o:$""? = none
    let sx:$"" = "x"
    println(i.typename, " ", j.typename, " ", o.typename, " ", sx.typename, " ", twice($"ab"))
    var cs:$[cstr] = $["x"]
    cs = $["y", "z"]
    let w:cstr := cs[0]
    let n = first()
    let bx:box = {$["m"]}
    var d:${String: cstr} = ${"k": "v"}
    d = ${"j": "w"}
    println(cs.typename, " ", n.typename, " ", d.typename, " ", w, " ", n, " ", bx.names, " ", d, " ", count($["a"]))
    println(Array(["x"]).typename, " ", $[1, 2].typename, " ", $[[0, 1], [2, 3]].typename)
    return 0
}
// out: Array<String> Array<Array<String>> Dictionary<String, String> Array<String>
// out: Array<Dictionary<String, i64>> Dictionary<String, Dictionary<String, String>>
// out: ["a", "b"] [["a"], ["b", "c"]] {"k": "v"} ["a1", "x"] [{"a": 1}, {"b": 2}] {"k": {"x": "y"}}
// out: Array<String> Dictionary<String, Array<String>> String? String abab
// out: Array<cstr> Array<Array<cstr>> Dictionary<String, cstr> y [["r", "s"], ["t"]] ["m"] {"j": "w"} 1
// out: Array<cstr> Array<i64> Array<Array<i64>>
