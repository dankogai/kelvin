// s.find, s.has, s.starts, s.ends and s.trim() at their edges (#177), which
// runtime/string.k now gives, written in Kelvin (#289): empty text and
// needles, codepoints of more than a byte, borrows, and every blank of
// JS's \s
let show(s:String) {
    println("[", s, "] ", s.count)
}
let main():int32 {
    let e = $""
    let s = $"héllo wörld héllo"
    let blank = $" \t\n\u{3000}\u{a0} "
    var empty_t = $""
    let w = $"wörld"
    println(s.find("héllo"), " ", s.find("wörld"), " ", s.find("llo"), " ", s.find("x"), " ", s.find(""), " ", e.find(""), " ", e.find("a"))
    println(s.find(&w), " ", s.find(&empty_t), " ", e.find(&empty_t), " ", s.has("ö"), " ", s.has(&w), " ", e.has(""))
    println(s.starts("hé"), " ", s.starts(""), " ", s.starts("é"), " ", e.starts(""), " ", e.starts("a"), " ", s.starts(&s), " ", w.starts(&s))
    println(s.ends("llo"), " ", s.ends(""), " ", s.ends("hé"), " ", e.ends(""), " ", s.ends(&s), " ", s.ends(&w))
    show(s.trim())
    show(blank.trim())
    show(e.trim())
    show($"\u{3000}x\u{2028} y\u{feff}".trim())
    show($"  ab  ".trim())
    show($"é".trim())
    return 0
}
// out: 0 6 2 -1 0 0 -1
// out: 6 0 0 true true true
// out: true true false true false true false
// out: true true false true true false
// out: [héllo wörld héllo] 17
// out: [] 0
// out: [] 0
// out: [x  y] 4
// out: [ab] 2
// out: [é] 1
