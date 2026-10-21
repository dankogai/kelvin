// d0 ?? d1 fills in and d0 !! d1 overrides (#237), as swiftalk's: a new
// Dictionary of both, a key in both keeping d0's value or taking d1's, so
// (d0 !! d1) == (d1 ?? d0); ??= and !!= in place; a place is copied, one
// an expression gives taken; !!x is still two nots
// out: {"a": 1, "b": 2, "c": 30} {"a": 1, "b": 20, "c": 30} true {"a": 1, "b": 2} {"b": 20, "c": 30}
// out: {"a": 1, "b": 2, "c": 30} {"a": 100, "b": 2} {"a": 1, "b": 2, "c": 30, "z": 0}
// out: {1: "one", 2: "dos"} {1: "uno", 2: "dos"}
// out: {1: "one", 2: "dos"}
// out: {1: "uno", 2: "dos"}
// out: {"a": 1, "b": 20, "q": 9, "c": 30}
// out: true 7
let base():Dictionary<String, int64> { return ${"a": 1, "b": 2} }

let main():int32 {
    var d0 = ${"a": 1, "b": 2}
    var d1 = ${"b": 20, "c": 30}
    var fill = d0 ?? d1
    var over = d0 !! d1
    println(fill, " ", over, " ", (d0 !! d1) == (d1 ?? d0), " ", d0, " ", d1)
    println(base() ?? d1, " ", d0 !! ${"a": 100}, " ", d0 ?? d1 ?? ${"z": 0})
    var s0 = ${1: $"one"}
    var s1 = ${1: $"uno", 2: $"dos"}
    println(s0 ?? s1, " ", s0 !! s1)
    s0 ??= s1
    println(s0)
    s0 !!= s1
    println(s0)
    d0 ??= ${"q": 9}
    d0 !!= d1
    println(d0)
    let yes = true
    let n:int64? = none
    println(!!yes, " ", n ?? 7)
    return 0
}
