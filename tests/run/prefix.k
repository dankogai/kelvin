// x.prefix(n) and x.prefix { ... } (#372): Haskell's take and takeWhile.
// An Array, a String, a Dictionary and a Set give a new one of their kind;
// an Iterator, an iterator and a Sequence give an Iterator<T>, lazily, so
// an Iterator that never ends gives the first few, and they chain
struct counter { n: int64 }
var counter.next():int64? {
    .n += 1
    if .n > 5 { return none }
    return .n
}
struct span { lo: int64; hi: int64 }
struct span_walk { at: int64; hi: int64 }
var span_walk.next():int64? {
    if .at >= .hi { return none }
    .at += 1
    return .at - 1
}
let span.makeIterator():span_walk { return {.lo, .hi} }
let words():Iterator<String> {
    return Iterator(0) {
        $0 += 1
        return $"w" + String($0)
    }
}
let main():int32 {
    var nat = Iterator(-1){ $0 += 1; return $0 }
    var five = nat.prefix(5)
    for x in five { print(x, " ") }
    var small = Iterator(-1){ $0 += 1; return $0 }.prefix { $0 < 4 }
    for x in small { print(x, " ") }
    var two = Iterator(-1){ $0 += 1; return $0 }.prefix(10).prefix { $0 < 3 }
    println(two.map { $0 * 10 })
    var c:counter = {0}
    var three = c.prefix(3)
    for x in three { print(x, " ") }
    let sp:span = {0, 100}
    var sq = sp.prefix(3)
    for x in sq { print(x, " ") }
    var sw = sp.prefix { $0 < 2 }
    println(sw.map { $0 })
    var w = words().prefix(3)
    for x in w { print(x, " ") }
    var v = words().prefix { $0 != $"w3" }
    for x in v { print(x, " ") }
    var u = words().prefix(5).prefix { $0.count == 2 }
    println(u.map { $0 + $"!" })
    var half = words().prefix(9)
    println(half.next())
    let xs = $[1, 2, 3, 4, 5]
    println(xs.prefix(2), " ", xs.prefix(9), " ", xs.prefix(-1), " ", xs.prefix { $0 < 3 })
    let ss = $[$"a", $"bb", $"c"]
    println(ss.prefix(2), " ", ss.prefix { $0.count == 1 }, " ", ss.map { $0 + $"." }.prefix(2))
    let s = $"héllo"
    println(s.prefix(2), " ", s.prefix { $0.utf32 != 'l' }, " ", s.prefix(99), " ", ($"ab" + $"cd").prefix { $0.utf32 != 'c' })
    let d = ${"a": $"1", "b": $"22", "c": $"3"}
    println(d.prefix(2), " ", d.prefix { $0.count == 1 })
    let st = ${3, 1, 2}
    println(st.prefix(2), " ", st.prefix { $0 != 1 })
    return 0
}
// out: 0 1 2 3 4 0 1 2 3 [0, 10, 20]
// out: 1 2 3 0 1 2 [0, 1]
// out: w1 w2 w3 w1 w2 ["w1!", "w2!", "w3!", "w4!", "w5!"]
// out: some("w1")
// out: [1, 2] [1, 2, 3, 4, 5] [] [1, 2]
// out: ["a", "bb"] ["a"] ["a.", "bb."]
// out: hé hé héllo ab
// out: {"a": "1", "b": "22"} {"a": "1"}
// out: {3, 1} {3}
