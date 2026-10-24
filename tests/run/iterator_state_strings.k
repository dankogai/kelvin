// an Iterator's state that owns (#325) moves in, a var's too, and is
// freed with the Iterator; the Strings it gives are the loop's, freed each
// pass; an Iterator moves by return and by passing, never copied
let letters(t:cstr):Iterator<String> {
    var text = String(t)
    return Iterator(text) {
        if $0.count == 0 { return none }
        let head:String = $0[0..<1]
        $0 = $0[1..<$0.count as int64]
        return head
    }
}
let spell(var it:Iterator<String>):String {
    var out = $""
    for s in it {
        out += &s
        out += "."
    }
    return out
}
let main():int32 {
    var words = Iterator(0) {
        if $0 >= 3 { return none }
        $0 += 1
        var s = $"w"
        s += String($0)
        return s
    }
    println(words.map { $0 + $"!" })
    for s in letters("abc") { print(s, ",") }
    println()
    println(spell(letters("kelvin")))
    var never = letters("unwalked")
    let one = never.next()
    println(one)
    return 0
}
// out: ["w1!", "w2!", "w3!"]
// out: a,b,c,
// out: k.e.l.v.i.n.
// out: some("u")
