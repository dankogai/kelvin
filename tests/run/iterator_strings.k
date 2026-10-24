// an iterator of Strings (#318): each one next() gives is the loop's,
// freed at the end of each pass, on break and on continue; an iterator
// that owns, given by an expression, is held and freed after the loop
struct numbered { i: int64; last: int64 }
extend numbered {
    var next():String? {
        .i += 1
        if .i > .last { return none }
        var s = String("w")
        s.append(String(.i))
        return s
    }
}
struct letters { text: String; at: int64 }
var letters.next():String? {
    if .at >= .text.count as int64 { return none }
    let s:String = .text[.at..<.at + 1]
    .at += 1
    return s
}
let spell(t:cstr):letters { return {String(t), 0} }
let main():int32 {
    var w:numbered = {0, 4}
    for s in w {
        if s == $"w2" { continue }
        if s == $"w4" { break }
        print(s, ",")
    }
    println()
    for s in spell("abc") { print(s, ".") }
    println()
    return 0
}
// out: w1,w3,
// out: a.b.c.
