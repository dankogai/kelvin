// ?? and !! bind right to left (#251), as Swift's ??: p ?? o ?? z is
// p ?? (o ?? z), the first value of the chain, or z; of Dictionaries,
// d0 ?? d1 ?? d2 and d0 !! d1 !! d2 are as either way, and a ?? and a !!
// in one chain group from the right too
// out: o z o
// out: 2 3 some(2)
// out: {"a": 1, "b": 2, "c": 3} {"a": 9, "b": 2} {"a": 1, "b": 2}
let main():int32 {
    var p:String? = none
    var o:String? = $"o"
    var q:String? = none
    println(p ?? o ?? $"z", " ", p ?? q ?? $"z", " ", o ?? p ?? $"z")
    var a:int64? = none
    var b:int64? = 2
    var nn:int64?? = none
    println(a ?? b ?? 3, " ", a ?? a ?? 3, " ", nn ?? b ?? 9)
    var d0 = ${"a": 1}
    var d1 = ${"a": 2, "b": 2}
    println(d0 ?? d1 ?? ${"c": 3}, " ", d0 !! d1 !! ${"a": 9}, " ", d0 ?? d1 !! ${"a": 9})
    return 0
}
