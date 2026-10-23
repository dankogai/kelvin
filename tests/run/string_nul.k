// a String holds a NUL, which a cstr cannot (#299): $"\x00mid" is four
// codepoints, where KV_STRING_OF stopped at the NUL; escape() writes it as
// \u{0}, which unescape() and a literal read back, as they do print's
// \u0000; a cstr, a literal on the right of +, stops at it as C does
let main():int32 {
    let a = $"\x00mid"
    let e:String = a.escape()
    println(a.count, " ", e, " ", e.unescape() == a, " ", $"\\x00mid".unescape().escape() == e)
    println($"\u{0}mid" == a, " ", $"\u0000mid" == a, " ", String("m\u{0}n").count)
    var t = $"x"
    t += (0 as uint32).uchr
    t += "y"
    var s:String = "x\u{0}y"
    let xs:$[String] = $["x\u0000y"]
    println($[t.copy()], " ", s == t, " ", xs[0] == t, " ", ("p\u{0}q" + t).count, " ", ($"p" + "\u{0}q").count)
    return 0
}
// out: 4 \u{0}mid true true
// out: true true 3
// out: ["x\u0000y"] true true 6 1
