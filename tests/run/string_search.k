// find, has, starts, ends and trim on a String (#177): the text sought a
// cstr or a String borrowed, &t, the index found a codepoint count, -1
// where there is none; trim takes the blanks off either end, JS's \s
let main():int32 {
    var s = $"héllo, wörld"
    var w = $"wörld"
    var x = $"xyz"
    println(s.find("llo"), " ", s.find(&w), " ", s.find("ö"), " ", s.find(""), " ", s.find("nope"), " ", s.find(&x))
    println(s.has("wör"), " ", s.has(&w), " ", s.has("WÖR"), " ", s.has(""), " ", s.has(&x))
    println(s.starts("hé"), " ", s.starts(&w), " ", s.ends(&w), " ", s.ends("ld"), " ", s.ends("l"), " ", s.starts(""))
    var padded = $"  \t héllo 　\n"
    var t = padded.trim()
    var blank = $" \t\n"
    var tb = blank.trim()
    var none = $"tight"
    var tn = none.trim()
    println("[", t, "] ", t.count, " [", tb, "] ", tb.count, " ", tn == none)
    var empty = $""
    println(empty.find(""), " ", empty.find("a"), " ", empty.has(""), " ", empty.starts(""), " ", empty.ends("a"))
    if s.has("wörld") && !s.starts("w") { println("found, not at the start, at ", s.find("w")) }
    return 0
}
// out: 2 7 8 0 -1 -1
// out: true true false true false
// out: true false true true false true
// out: [héllo] 5 [] 0 true
// out: 0 -1 true true false
// out: found, not at the start, at 7
