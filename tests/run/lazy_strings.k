// a lazy Sequence of Strings (#323): each value next gives is lent to an
// anonymous function, a copy given to a named one, and freed unless
// filter keeps it; a Sequence that owns is copied in from a place, moved
// in from an expression, and freed with the lazy Sequence
struct word { text: String }
struct word_walk { text: String; at: int64 }
var word_walk.next():String? {
    if .at >= .text.count as int64 { return none }
    let s:String = .text[.at..<.at + 1]
    .at += 1
    return s
}
let word.makeIterator():word_walk { return {.text.copy(), 0} }
let spelled(t:cstr):word { return {String(t)} }
let shout(s:String):String { s + "!" }
let main():int32 {
    let w:word = spelled("abcd")
    let loud = w.lazy.map(shout)
    for s in loud { print(s, ",") }
    println()
    for s in w.lazy.filter({ $0 != $"b" }).map({ $0 + $0 }) { print(s, ",") }
    println()
    for s in spelled("xyz").lazy.map({ $0 + $"?" }) { print(s, ",") }
    println()
    println(spelled("kelvin").lazy.filter({ $0 != $"e" }).reduce($"") { $0 + $1 }, " ", w.text)
    let lens = w.lazy.map { $0.count as int64 }
    for n in lens { print(n) }
    println()
    return 0
}
// out: a!,b!,c!,d!,
// out: aa,cc,dd,
// out: x?,y?,z?,
// out: klvin abcd
// out: 1111
