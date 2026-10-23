// flatMap of an Array, a Dictionary and a Set (#308), which makes each a
// monad: its function gives one of the receiver's kind for each element,
// and the results are one, concatenated, merged in the order added, a
// later entry winning, as d[k] = v, or unioned; flatMapWithKey is a
// Dictionary's. The monad laws hold: left identity, right identity and
// associativity, a Set's compared by its elements
let pair(x:int64):$[int64] { Array<int64>([x, x * 10]) }
let words(s:String):$[String] { $[s.copy(), s + "!"] }
let f(x:int64):$[int64] { Array<int64>([x, x * 10]) }
let g(x:int64):$[int64] { Array<int64>([x + 1]) }
let sf(x:int64):Set<int64> { Set<int64>({x, x * 10}) }
let sg(x:int64):Set<int64> { Set<int64>({x + 1}) }
let df(v:int64):Dictionary<String, int64> { Dictionary<String, int64>({"a": v, "b": v * 10}) }
let dg(v:int64):Dictionary<String, int64> { Dictionary<String, int64>({"c": v + 1}) }
let main():int32 {
    let xs = $[1, 2, 3]
    println(xs.flatMap { Array<int64>([$0, $0 * 10]) }, " ", xs.flatMap(pair), " ", xs.flatMap { $0 > 1 ? Array<int64>([$0]) : Array<int64>() }, " ", $[$"a", $"b"].flatMap(words))
    let d = ${"a": 1, "b": 2}
    println(d.flatMap { Dictionary<String, int64>({"x": $0, "y": $0 * 10}) }, " ", d.flatMapWithKey { Dictionary<String, int64>({String($0): $1, "z": $1 + 100}) })
    let s = ${1, 2, 3}
    println(s.flatMap { Set<int64>({$0, $0 + 1}) }, " ", ${"to", "be"}.flatMap { ${$0.copy(), $0 + "!"} })
    println(xs.flatMap { Array<int64>([$0]) }.flatMap { Array<int64>([$0, $0]) }.count)
    println(Array<int64>([5]).flatMap(f) == f(5), " ", xs.flatMap { Array<int64>([$0]) } == xs, " ", xs.flatMap(f).flatMap(g) == xs.flatMap { f($0).flatMap(g) })
    println(Set<int64>({5}).flatMap(sf).elements == sf(5).elements, " ", s.flatMap { Set<int64>({$0}) }.elements == s.elements, " ", s.flatMap(sf).flatMap(sg).elements == s.flatMap { sf($0).flatMap(sg) }.elements)
    println(Dictionary<String, int64>({"k": 5}).flatMap(df) == df(5), " ", d.flatMapWithKey { Dictionary<String, int64>({String($0): $1}) } == d, " ", d.flatMap(df).flatMap(dg) == d.flatMap { df($0).flatMap(dg) })
    return 0
}
// out: [1, 10, 2, 20, 3, 30] [1, 10, 2, 20, 3, 30] [2, 3] ["a", "a!", "b", "b!"]
// out: {"x": 2, "y": 20} {"a": 1, "z": 102, "b": 2}
// out: {1, 2, 3, 4} {"to", "to!", "be", "be!"}
// out: 6
// out: true true true
// out: true true true
// out: true true true
