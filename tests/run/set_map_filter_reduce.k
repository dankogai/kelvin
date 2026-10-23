// a Set's map, filter and reduce (#307), over its elements in the order
// added: map makes a Set of what its function gives, duplicates one,
// filter keeps the elements it says true for, reduce folds them; a named
// function is given a copy, and a Set an expression gives is freed
let twice(x:int64):int64 { x * 2 }
let shout(t:String):String { t + "!" }
let mk():Set<int64> { ${5, 6} }
let main():int32 {
    let s = ${3, 1, 4, 1, 5, 9, 2, 6}
    let w = ${"to", "be", "or", "not"}
    println(s.map { $0 % 3 }, " ", s.map(twice), " ", s.filter { $0 > 3 }, " ", s.reduce(0) { $0 + $1 })
    println(w.map { $0.count as int64 }, " ", w.map(shout), " ", w.filter { $0.count == 2 }, " ", w.reduce($"") { $0 + $1 })
    println(mk().map { $0 + 1 }, " ", s.filter { $0 > 2 }.map { $0 * 10 }.reduce(0) { $0 + $1 }, " ", ${0}.filter { $0 > 0 })
    let m:Set<String> = w.map { $0 + $0 }
    println(m.has("toto"), " ", m.count, " ", s.reduce(0.5) { $0 + $1 })
    return 0
}
// out: {0, 1, 2} {6, 2, 8, 10, 18, 4, 12} {4, 5, 9, 6} 30
// out: {2, 3} {"to!", "be!", "or!", "not!"} {"to", "be", "or"} tobeornot
// out: {6, 7} 270 {}
// out: true 4 30.5
