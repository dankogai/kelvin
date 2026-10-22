// s.escape(), s.unescape(), b.toBase64() and Bytes.fromBase64() at their
// edges (#155, #164), which runtime/string.k and runtime/bytes.k now give,
// written in Kelvin (#290): every escape, ones that are not, surrogate
// pairs, a NUL, which ends escape() as it ended the C, and Base64 of 0 to 6
// bytes in either alphabet, padded or not, read back with blanks
let un(t:cstr) {
    let s = String(t)
    let u = s.unescape()
    let e = u.escape()
    println(u.bytes^.escape(), " ", u.count, " ", e.bytes^.escape())
}
let main():int32 {
    let samples = $[$"", $"plain", $"hÃ©llo", $"a\\b", $"ðŸ˜€ and æ—¥æœ¬", $"\u{a0}\u{ffff}\u{10ffff}"]
    for s in samples {
        let e = s.escape()
        println(e, " ", e.unescape() == s)
    }
    un("\\u{1F600}")
    un("\\u{110000}")
    un("\\u{D800}")
    un("\\u{}")
    un("\\u{123456789}")
    un("\\uD83D\\uDE00")
    un("\\uD83Dx")
    un("\\u00e9\\u0041")
    un("\\uDE00")
    un("\\u12")
    un("\\x41\\x4g\\xZ")
    un("\\n\\r\\t\\0\\\\\\\"\\'")
    un("\\q\\")
    un("end\\")
    un("\\x00mid")
    un("Ã©\\u{e9}")
    for n in 0..<7 {
        var b = Bytes()
        for k in 0..<n { b += (250 + k) as u8 }
        println(n, " ", b.toBase64(), " ", b.toBase64(url), " ", b.toBase64(nopad), " ", b.toBase64(url, nopad))
    }
    let text = Bytes("Kelvin, base64!")
    let enc = text.toBase64()
    println(enc, " ", Bytes.fromBase64(enc.cstr) == text, " ", Bytes.fromBase64("S2Vs dmlu\n") , " ", Bytes.fromBase64("+/-_"), " ", Bytes.fromBase64("QQ==QUJD"), " ", Bytes.fromBase64(""))
    return 0
}
// out:  true
// out: plain true
// out: h\u{E9}llo true
// out: a\\b true
// out: \u{1F600} and \u{65E5}\u{672C} true
// out: \u{A0}\u{FFFF}\u{10FFFF} true
// out: \xF0\x9F\x98\x80 1 \\u{1F600}
// out: \\u{110000} 10 \\\\u{110000}
// out: \\u{D800} 8 \\\\u{D800}
// out: \\u{} 4 \\\\u{}
// out: \\u{123456789} 13 \\\\u{123456789}
// out: \xF0\x9F\x98\x80 1 \\u{1F600}
// out: \\uD83Dx 7 \\\\uD83Dx
// out: \xC3\xA9A 2 \\u{E9}A
// out: \\uDE00 6 \\\\uDE00
// out: \\u12 4 \\\\u12
// out: A\\x4g\\xZ 8 A\\\\x4g\\\\xZ
// out: \x0A\x0D\x09\x00\\"' 7 \x0A\x0D\x09
// out: \\q\\ 3 \\\\q\\\\
// out: end\\ 4 end\\\\
// out: \x00mid 4 
// out: \xC3\xA9\xC3\xA9 2 \\u{E9}\\u{E9}
// out: 0    
// out: 1 +g== -g== +g -g
// out: 2 +vs= -vs= +vs -vs
// out: 3 +vv8 -vv8 +vv8 -vv8
// out: 4 +vv8/Q== -vv8_Q== +vv8/Q -vv8_Q
// out: 5 +vv8/f4= -vv8_f4= +vv8/f4 -vv8_f4
// out: 6 +vv8/f7/ -vv8_f7_ +vv8/f7/ -vv8_f7_
// out: S2VsdmluLCBiYXNlNjQh true Kelvin ûÿ¿ A 
