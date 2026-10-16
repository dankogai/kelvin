// Base64 in the prelude (#155): b.toBase64() standard and padded, with the
// words url and nopad, and Bytes.fromBase64(text) of a cstr or a String
// borrowed, taking either alphabet, with or without padding, blanks skipped
let main():int32 {
    var man = Bytes("Man")
    var ma = Bytes("Ma")
    var m = Bytes("M")
    var light = Bytes("light work.")
    var empty = Bytes()
    var high = Bytes("\xfb\xff\xbf")
    var s1 = man.toBase64()
    var s2 = ma.toBase64()
    var s3 = m.toBase64()
    var s4 = m.toBase64(nopad)
    var s5 = light.toBase64()
    var s6 = empty.toBase64()
    var s7 = high.toBase64()
    var s8 = high.toBase64(url)
    var s9 = high.toBase64(url, nopad)
    var s10 = ma.toBase64(nopad, url)
    println(s1, " ", s2, " ", s3, " ", s4, " ", s5, " [", s6, "]")
    println(s7, " ", s8, " ", s9, " ", s10)
    var d1 = Bytes.fromBase64("TWFu")
    var d2 = Bytes.fromBase64("TQ==")
    var d3 = Bytes.fromBase64("TQ")
    var d4 = Bytes.fromBase64("-_-_")
    var d5 = Bytes.fromBase64("+/+/")
    var d6 = Bytes.fromBase64("TW\nFu ")
    var d7 = Bytes.fromBase64("")
    var d8 = Bytes.fromBase64(&s5)
    println(d1, " ", d2, " ", d3, " ", d4[0], " ", d4[1], " ", d4[2], " ", d4 == d5)
    println(d6, " ", d7.count, " ", d8)
    var all = Bytes(256)
    for i in 0..<256 { all[i] = i as u8 }
    var text = all.toBase64()
    var back = Bytes.fromBase64(&text)
    var textURL = all.toBase64(url, nopad)
    var backURL = Bytes.fromBase64(&textURL)
    println(text.count, " ", back == all, " ", textURL.count, " ", backURL == all, " ", s5.typename, " ", d1.typename)
    return 0
}
// out: TWFu TWE= TQ== TQ bGlnaHQgd29yay4= []
// out: +/+/ -_-_ -_-_ TWE
// out: Man M M 251 255 191 true
// out: Man 0 light work.
// out: 344 true 342 true String Bytes
