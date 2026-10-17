// b.escape() (#166): the bytes as text, each that is not printable ASCII
// as \xHH and a backslash as \\, a String; s.unescape() reads it back
// where the bytes were text, and \xHH stays where it is not;
// Bytes.unescape(text) (#167) reads any of it back into a Bytes
let main():int32 {
    var b = Bytes("a\\b\tc")
    b += 0
    b += 0xFF
    b += 0x7F
    b += ' '
    b += '~'
    var e = b.escape()
    println(e, " ", e.count, " ", b.count)
    var t = Bytes("plain text")
    var te = t.escape()
    var back = te.unescape()
    var plain = $"plain text"
    println(te, " ", back == plain)
    var u = Bytes("héllo")
    var ue = u.escape()
    println(ue)
    var r1 = Bytes.unescape(&e)
    var r2 = Bytes.unescape("\\x41\\u{E9}\\uD83D\\uDE00\\n\\z\\")
    var r3 = Bytes.unescape(&ue)
    var r2e = r2.escape()
    println(r1 == b, " ", r1.count, " ", r2.count, " ", r2e, " ", r3 == u)
    return 0
}
// out: a\\b\x09c\x00\xFF\x7F ~ 23 10
// out: plain text true
// out: h\xC3\xA9llo
// out: true 10 11 A\xC3\xA9\xF0\x9F\x98\x80\x0A\\z\\ true
