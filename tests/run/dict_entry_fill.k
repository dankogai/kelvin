// d[k] ??= v sets the entry only where k is absent, and d[k] !!= v only
// where it is present (#243); the key is read once, and v is made only
// where it is set, so fresh runs twice of four
// out: {"ann": 32, "bob": 42}
// out: {1: "eins", 2: "two"} 2
// out: {"ann": 32, "bob": 33}
// out: {"x": some(5)}
var made = 0
let fresh(s:cstr):String {
    made += 1
    return String(s)
}

let main():int32 {
    var a = ${"ann": 31}
    a["ann"] ??= 99
    a["bob"] ??= 42
    a["ann"] !!= 32
    a["cy"] !!= 7
    println(a)
    var s = ${1: $"one"}
    s[1] ??= fresh("uno")
    s[2] ??= fresh("two")
    s[1] !!= fresh("eins")
    s[3] !!= fresh("drei")
    println(s, " ", made)
    var key = $"bob"
    a[key] ??= 0
    a[key] !!= a["ann"]! + 1
    println(a)
    var o:Dictionary<String, int64?> = ${:}
    o["x"] ??= none
    o["x"] !!= 5
    println(o)
    return 0
}
