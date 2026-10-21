// a ?? b of two Optionals of a type (#252): an Optional, a where it has
// a value, else b, as Swift's; so is a ?? none. A b of the value's type
// still gives the value, and a chain ends with one: a ?? b ?? 0. Of
// values that own, a and b are copied where they are places, else taken
// out: some(2) some(5) none none some(5) some(3)
// out: some(2) 2 2
// out: some("o") some("o") none some("four") some("one") some("two")
// out: some("o") some("o")
// out: some(2) some(some(2)) none
let maybe(n:int64):int64? { if n > 0 { return n }; return none }
let named(n:int64):String? {
    if n == 1 { return $"one" }
    if n == 2 { return $"two" }
    if n == 4 { return $"four" }
    return none
}

let main():int32 {
    var a:int64? = none
    var b:int64? = 2
    var c:int64? = 5
    println(a ?? b, " ", c ?? b, " ", a ?? a, " ", a ?? none, " ", c ?? none, " ", maybe(0) ?? maybe(3))
    let x:int64? = a ?? b
    println(x, " ", (a ?? b) ?? 0, " ", a ?? b ?? 0)
    var p:String? = none
    var o:String? = $"o"
    println(p ?? o, " ", o ?? p, " ", p ?? none, " ", named(0) ?? named(4), " ", named(1) ?? o, " ", p ?? named(2))
    let s = p ?? o
    println(s, " ", o)
    var nn:int64?? = none
    var n2:int64?? = b
    println(nn ?? b, " ", nn ?? n2, " ", nn ?? none)
    return 0
}
