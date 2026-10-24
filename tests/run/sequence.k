// a Sequence (#321), Swift's: a value whose let makeIterator() gives a
// fresh iterator, which for walks, so the Sequence stays as it was and
// may be a let, walked again and again; map, filter, reduce and flatMap
// walk a fresh one too
struct span { lo: int64; hi: int64 }
struct span_walk { at: int64; hi: int64 }
var span_walk.next():int64? {
    if .at >= .hi { return none }
    .at += 1
    return .at - 1
}
let span.makeIterator():span_walk { return {.lo, .hi} }
let upto(n:int64):span { return {0, n} }

struct word { text: String }                   // a Sequence that owns
struct word_walk { text: String; at: int64 }
var word_walk.next():String? {
    if .at >= .text.count as int64 { return none }
    let s:String = .text[.at..<.at + 1]
    .at += 1
    return s
}
let word.makeIterator():word_walk { return {.text.copy(), 0} }
let spelled(t:cstr):word { return {String(t)} }

struct twice_over { n: int64 }                 // both: makeIterator wins, as Swift's for
var twice_over.next():int64? { none }
let twice_over.makeIterator():span_walk { return {0, .n} }

let main():int32 {
    let s:span = {1, 4}
    for x in s { print(x, ",") }
    for x in s { print(x, ",") }
    println()
    for x in upto(3) { print(x, ",") }
    println()
    println(s.map { $0 * 10 }, " ", s.filter { $0 != 2 }, " ", s.reduce(0) { $0 + $1 })
    println(upto(3).flatMap { Array<int64>([$0, $0]) }, " ", s.lo, " ", s.hi)
    let w:word = spelled("abc")
    for c in w { print(c, ".") }
    println(" ", w.text)
    println(spelled("kelvin").filter { $0 != $"e" }.reduce($"") { $0 + $1 })
    for c in spelled("xy") { print(c) }
    println()
    var both:twice_over = {3}
    for x in both { print(x, ",") }
    println(" ", both.n)
    return 0
}
// out: 1,2,3,1,2,3,
// out: 0,1,2,
// out: [10, 20, 30] [1, 3] 6
// out: [0, 0, 1, 1, 2, 2] 1 4
// out: a.b.c. abc
// out: klvin
// out: xy
// out: 0,1,2, 3
