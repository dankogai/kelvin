// d0 == d1 (#235): two Dictionaries of the same key and value types
// with the same entries, in any order, each value by its own ==: a
// String by its text, an Optional by its case and value, a Dictionary
// by its entries; != is the opposite; one an expression gives is held
// out: true false true false true true
// out: true false
// out: false true
// out: true false true
// out: true
// out: true true false false
enum tree { leaf: int64; kids: Dictionary<String, tree> }   // an enum and its Dictionary compare each other

let ages():Dictionary<String, int64> { return ${"ann": 31, "bob": 42} }

let main():int32 {
    var a = ${"ann": 31, "bob": 42}
    var b:Dictionary<String, int64> = ${:}
    b["bob"] = 42
    b["ann"] = 31
    var c = ${"ann": 31, "bob": 43}
    var d = ${"ann": 31}
    println(a == b, " ", a == c, " ", a != c, " ", a == d, " ", ages() == a, " ", a == ages())
    var s = ${1: $"one", 2: $"two"}
    var t = ${2: $"two", 1: $"one"}
    println(s == t, " ", s != t)
    var o:Dictionary<int64, int64?> = ${:}
    o[1] = none
    var p:Dictionary<int64, int64?> = ${:}
    p[1] = 0
    println(o == p, " ", o == o)
    var n = ${"x": ${"y": 1}}
    var m = ${"x": ${"y": 1}}
    let same = n == m
    m["x"]!["y"] = 2
    println(same, " ", n == m, " ", n["z"] == m["z"])
    var e1:Dictionary<int64, int64> = ${:}
    var e2:Dictionary<int64, int64> = ${:}
    println(e1 == e2)
    var ta:Dictionary<String, tree> = ${:}
    ta["x"] = tree.leaf(1)
    var tb:Dictionary<String, tree> = ${:}
    tb["x"] = tree.leaf(1)
    let k1 = tree.kids(ta.copy())
    let k2 = tree.kids(tb.copy())
    let before = ta == tb
    let kids_before = k1 == k2
    tb["y"] = tree.leaf(2)
    let k3 = tree.kids(tb.copy())
    println(before, " ", kids_before, " ", ta == tb, " ", k1 == k3)
    return 0
}
