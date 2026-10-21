// d.mapWithKey, d.filterWithKey and d.reduceWithKey (#241): map, filter and
// reduce of a Dictionary whose function takes each key before its value,
// a String key as a cstr, lent; mapWithKey gives the new value alone, of
// the same key
// out: {"ann": 331, "bob": 342, "cy": 207} {"ann": "ann=31", "bob": "bob=42", "cy": "cy=7"} {"bob": 42, "cy": 7} 88 annbobcy
// out: {1: 13, 2: 23, 3: 35} {1: "one", 3: "three"} 6 {3: "three"}
let tagged(k:cstr, v:int64):String { return $`${k}=${v}` }

let main():int32 {
    var a = ${"ann": 31, "bob": 42, "cy": 7}
    var scored = a.mapWithKey { k, v in k.count as int64 * 100 + v }
    var tags = a.mapWithKey(tagged)
    var brief = a.filterWithKey { k, v in k.count < 3 || v > 40 }
    let total = a.reduceWithKey(0) { acc, k, v in acc + k.count as int64 + v }
    let names = a.reduceWithKey($"") { acc, k, v in acc + k }
    println(scored, " ", tags, " ", brief, " ", total, " ", names)
    var sq = ${1: $"one", 2: $"two", 3: $"three"}
    var keyed = sq.mapWithKey { k, v in k * 10 + v.count as int64 }
    var odd = sq.filterWithKey { k, v in k % 2 == 1 }
    let sum = sq.reduceWithKey(0) { acc, k, v in acc + k }
    println(keyed, " ", odd, " ", sum, " ", sq.filterWithKey { $0 > 1 && $1.count > 3 })
    return 0
}
