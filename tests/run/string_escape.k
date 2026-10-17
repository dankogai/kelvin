// s.escape() and s.unescape() of the prelude (#164): each codepoint beyond
// ASCII as \u{...} and a backslash as \\, read back by unescape, which also
// reads \uHHHH, a surrogate pair, \xHH, \n, \r, \t, \0, \" and \'; an escape
// that is none, or a codepoint that is not one, stays as written
let main():int32 {
    var s = $"café 😀 a\\b \"q\" naïve"
    var e = s.escape()
    var u = e.unescape()
    println(e)
    println(u, " ", u == s, " ", e.count, " ", u.count)
    var plain = $"ascii only"
    var pe = plain.escape()
    println(pe, " ", pe == plain)
    var back = $"\\u0041\\uD83D\\uDE00\\x41\\t|\\\\|\\\"|\\'|\\n"
    var ub = back.unescape()
    println(ub, " ", ub.count)
    var odd = $"\\z \\u{zz} \\u{110000} \\uD83D \\x4G \\"
    var uo = odd.unescape()
    println(uo, " ", uo == odd)
    var nul = $"a\\0b"
    var un = nul.unescape()
    println(un.count, " ", un.bytes^.count)
    return 0
}
// out: caf\u{E9} \u{1F600} a\\b "q" na\u{EF}ve
// out: café 😀 a\b "q" naïve true 39 20
// out: ascii only true
// out: A😀A	|\|"|'|
// out:  12
// out: \z \u{zz} \u{110000} \uD83D \x4G \ true
// out: 3 3
