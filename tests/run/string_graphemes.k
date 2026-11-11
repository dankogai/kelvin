// a String's elements are its graphemes (#522), what a reader sees as one
// character, each a String: for c in s, s[i], s[lo..<hi], s.count,
// s.find, s.prefix(n) and s.prefix { ... } count them; a typed loop,
// for c:uchr in s, and s.codepoints walk codepoints; a CR LF is one
let shout(s:const String^):String {
    var t = s^.copy()
    t += "!"
    return t
}

let main():int32 {
    var s = $"é ﬁ 👨‍👩‍👧 🇯🇵\r\nx"
    var parts:$[String] = $[]
    for c in s { parts += c.copy() }
    println(parts.count, " ", s.count, " ", s.codepoints.count, " ", parts[4], " ", parts[7] == "\r\n")
    var n = 0
    for c:uchr in s { n += 1 }
    var m = 0
    for _ in s { m += 1 }
    println(n, " ", m, " ", s[0], " ", s[4], " ", s[s.count - 1], " ", shout(&s)[9])
    println(s[2..<5], "|", s[..<1], "|", s[6...].count, "|", s[0...0])
    let r = 4..<6
    println(s[r], "|", s.find("🇯🇵"), " ", s.find("́"), " ", s.find("x"), " ", s.find("q"))
    println(s.prefix(1), "|", s.prefix(0), "|", s.prefix(99) == s, "|", s.prefix { $0 != ' ' }, "|", s.prefix { $0 != "\r\n" }.count)
    var firsts = 0
    for c in s {
        if c == "🇯🇵" { break }
        firsts += 1
    }
    let empty = $""
    var none = 0
    for c in empty { none += 1 }
    println(firsts, " ", none, " ", empty.count, " ", $"abc".count, " ", $"a\r\nb".count, " ", $"a\r\nb"[1] == "\r\n")
    return 0
}
// out: 9 9 16 👨‍👩‍👧 true
// out: 16 9 é 👨‍👩‍👧 x !
// out: ﬁ 👨‍👩‍👧|é|3|é
// out: 👨‍👩‍👧 |6 0 8 -1
// out: é||true|é|7
// out: 6 0 0 3 3 true
