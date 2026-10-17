// a RegExp on a Bytes (#168): b.escape(&re) and b.escape($/.../), with the
// b flag (#171) matched byte by byte, each byte the codepoint of its value,
// every matched byte as \xHH and every byte that is not printable ASCII
// too; Bytes.unescape(text, &re) reads the escapes back where the pattern
// matches the text alone; without b, the bytes are read as UTF-8
#import <RegExp>
let main():int32 {
    var b = Bytes("a\\b héllo")
    b += 0
    b += 0xFF
    var e1 = b.escape($/[\x80-\xFF]/gb)
    var e2 = b.escape($/l+/b)
    var e0 = b.escape()
    println(e1)
    println(e2)
    println(e0, " ", e0 == e1)
    let nul = $/\x00|\xFF/gb
    var caps = b.escape(&nul)
    println(caps)
    var s = $"A\\x41\\u{E9}B\\x42"
    let hexEsc = $/\\x[0-9A-F]{2}/gb
    var u1 = Bytes.unescape(&s, &hexEsc)
    var u2 = Bytes.unescape("A\\x41\\u{E9}B", $/\\u\{[0-9A-F]+\}/b)
    var u0 = Bytes.unescape(&s)
    var e3 = u1.escape()
    var e4 = u2.escape()
    var e5 = u0.escape()
    println(e3, " ", u1.count)
    println(e4, " ", u2.count)
    println(e5, " ", u0.count)
    var accent = Bytes("é")
    var hb = accent.escape($/[\x80-\xff]/gb)                 // two bytes, each a character with b
    var hu = accent.escape($/[\u0080-\u00ff]/g)              // one codepoint, é, without it
    var acc = $"é"
    var sb = acc.escape()
    let twoBytes = $/[\x80-\xff]/gb
    let oneChar = $/[\u0080-\u00ff]/g
    var text = $"aé"
    var textBytes = Bytes("aé")
    var mb = textBytes.match(&twoBytes)                      // the text of a String cut inside é would end the program
    var mu = text.match(&oneChar)
    print(hb, " ", hu, " ", sb, " ", mb.count, " ", mu.count, " ", text.test(&twoBytes))
    println(" ", twoBytes.binary, " ", oneChar.unicode, " ", twoBytes.flags)
    var raw = Bytes("x")
    raw += 0xC3
    raw += 0x28
    let lead = $/\xC3(?!\x28)/b
    var e6 = raw.escape(&lead)
    var e7 = raw.escape($/\X/gb)
    println(e6, " ", e7)
    return 0
}
// out: a\\b h\xC3\xA9llo\x00\xFF
// out: a\\b h\xC3\xA9\x6C\x6Co\x00\xFF
// out: a\\b h\xC3\xA9llo\x00\xFF true
// out: a\\b h\xC3\xA9llo\x00\xFF
// out: AA\\u{E9}BB 10
// out: A\\x41\xC3\xA9B 8
// out: AA\xC3\xA9BB 6
// out: \xC3\xA9 \xC3\xA9 \u{E9} 2 1 true true true gb
// out: x\xC3( \x78\xC3\x28
