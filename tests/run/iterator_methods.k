// it.map, .filter, .reduce, .flatMap (#319): Swift's Sequence methods,
// eager, on an iterator: its values are gathered into an Array, which
// the Array's own method walks and frees; the iterator is walked to its
// end, a var staying there; a method of its own of the name wins
struct countdown { n: int64 }
var countdown.next():int64? {
    if .n == 0 { return none }
    .n -= 1
    return .n + 1
}
let from(n:int64):countdown { return {n} }
struct letters { text: String; at: int64 }
var letters.next():String? {
    if .at >= .text.count as int64 { return none }
    let s:String = .text[.at..<.at + 1]
    .at += 1
    return s
}
let spell(t:cstr):letters { return {String(t), 0} }
let twice(n:int64):int64 { n * 2 }
struct ticks { n: int64 }
var ticks.next():int64? { none }
let ticks.map(k:int64):int64 { .n * k }
let main():int32 {
    println(from(4).map { $0 * 10 }, " ", from(3).map(twice))
    println(from(6).filter { $0 % 2 == 0 }, " ", from(4).reduce(0) { $0 + $1 })
    println(from(3).flatMap { Array<int64>([$0, -$0]) })
    println(from(5).filter { $0 > 1 }.map { $0 * $0 }.reduce(0) { $0 + $1 })
    var c:countdown = {5}
    for x in c {
        if x == 4 { break }
    }
    let rest = c.map { $0 }                      // walked apart: C's arguments have no order
    let none_left = c.map { $0 }
    println(rest, " ", c.n, " ", none_left)
    println(spell("abc").map { $0 + $"!" })
    var w:letters = spell("kelvin")
    let kept = w.filter { $0 != $"e" }.reduce($"") { $0 + $1 }
    println(kept, " ", w.at)
    let t:ticks = {3}
    println(t.map(7))
    return 0
}
// out: [40, 30, 20, 10] [6, 4, 2]
// out: [6, 4, 2] 10
// out: [3, -3, 2, -2, 1, -1]
// out: 54
// out: [3, 2, 1] 0 []
// out: ["a!", "b!", "c!"]
// out: klvin 6
// out: 21
