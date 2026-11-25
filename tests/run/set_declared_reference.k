// var d := ${...} declares a Set, as := declares an Array and a
// Dictionary of a literal (#749), where kc said a Set is a value
let main():int32 {
    var s := ${"a", "b"}
    var n := ${1, 2, 3}
    var a := $["x"]
    var d := ${"k": 1}
    s += "c"
    println(s.count, " ", n.count, " ", a, " ", d, " ", s.typename, " ", n.typename)
    return 0
}
// out: 3 3 ["x"] {"k": 1} Set<String> Set<i64>
