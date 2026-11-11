// UnicodeData is the prelude's (#520), in every program as String is: its
// normalize, graphemes and case of a String, and a codepoint's name
// and category, on a u32 (#527), with no #import
let main():int32 {
    var s = $"é ﬁ 👨‍👩‍👧"
    let c = s.normalize(nfc)
    println(s.codepoints.count, " ", c.codepoints.count, " ", s.graphemes.count, " ", $"Straße".upper(), " ", $"ΣΑΣ".lower())
    let e = $"é".codepoints[0]
    println(e.name, " ", e.category, " ", ('7' as u32).isNumber, " ", $"ア".codepoints[0].script)
    return 0
}
// out: 10 9 5 STRAßE σασ
// out: LATIN SMALL LETTER E WITH ACUTE Ll true Katakana
