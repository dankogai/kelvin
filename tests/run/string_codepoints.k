// s.codepoints (#521): a String's codepoints, an Array<u32> (#527); for c
// in s.codepoints walks the String in place, with no Array made, each a
// u32, of a var, a borrow, and a String an expression gives
let shout(s:const String^):String {
    var t = s^.copy()
    t += "!"
    return t
}

let total(s:const String^):i64 {
    var n:i64 = 0
    for c in s^.codepoints { n += c as i64 }
    return n
}

let main():int32 {
    var s = $"é ﬁ 👨‍👩‍👧"
    var n = 0
    var us:$[u32] = $[]
    for c in s.codepoints {
        n += 1
        us += c
    }
    println(us)
    let cs = s.codepoints
    println(n, " ", cs.count, " ", s.count, " ", cs[1], " ", $"ab".codepoints, " ", $"".codepoints.count)
    var m = 0
    for c in shout(&s).codepoints { m += 1 }
    println(m, " ", total(&s), " ", total($"AB"))
    return 0
}
// out: [101, 769, 32, 64257, 32, 128104, 8205, 128105, 8205, 128103]
// out: 10 10 5 769 [97, 98] 0
// out: 11 465913 131
