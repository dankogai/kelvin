// UnicodeData is the prelude's (#520), in every program as String is: its
// normalize, graphemes and case of a String, and a uchr's name and
// category, with no #import
let main():int32 {
    var s = $"é ﬁ 👨‍👩‍👧"
    let c = s.normalize(nfc)
    println(s.codepoints.count, " ", c.codepoints.count, " ", s.graphemes.count, " ", $"Straße".upper(), " ", $"ΣΑΣ".lower())
    println(uchr("é").name, " ", uchr("é").category, " ", uchr("7").isNumber, " ", uchr("ア").script)
    return 0
}
// out: 10 9 5 STRAßE σασ
// out: LATIN SMALL LETTER E WITH ACUTE Ll true Katakana
