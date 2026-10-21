// d.contains(v), d.firstKey(v), d.lastKey(v) (#249): whether v is among
// the values by their ==, and the key of the first or last, in the order
// added, a K?, some of a copy or none; of a function of each value, or
// WithKey of each key, a String's as its cstr, and its value, the ones
// it says true for. A Dictionary an expression gives is held and freed
// out: true false some("ann") some("cy") none
// out: true some("bob") some("cy")
// out: true some("ann") some("ann")
// out: some("bob") some("cy") true
// out: true some(3) 1
// out: some("cy")
// out: bob
let big(v:int64):bool { return v > 40 }
let ages():Dictionary<String, int64> { return ${"ann": 31, "bob": 42, "cy": 31} }

let main():int32 {
    var a = ${"ann": 31, "bob": 42, "cy": 31}
    println(a.contains(42), " ", a.contains(7), " ", a.firstKey(31), " ", a.lastKey(31), " ", a.firstKey(7))
    println(a.contains { v in v > 40 }, " ", a.firstKey(big), " ", a.lastKey { $0 < 40 })
    println(a.containsWithKey { k, v in k[0] == 'b' && v == 42 }, " ", a.firstKeyWithKey { k, v in v == 31 }, " ",
            a.lastKeyWithKey { k, v in k[0] == 'a' })
    println(ages().firstKey(42), " ", ages().lastKey(31), " ", ages().contains(31))
    var n = ${1: $"one", 2: $"two", 3: $"one"}
    println(n.contains("two"), " ", n.lastKey($"one"), " ", n.firstKey { $0.count == 3 } ?? -1)
    a.remove("ann")
    println(a.firstKey(31))
    if let some(k) = a.lastKey(42) { println(k) }
    return 0
}
