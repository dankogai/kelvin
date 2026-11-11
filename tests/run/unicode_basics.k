// #import <UnicodeData> (#156): s.normalize(nfc) and the other forms,
// s.graphemes, the case mappings, and a codepoint's name, category,
// combining class, case and decomposition
#import <UnicodeData>
let main():int32 {
    var s = $"e\u0301 ﬁ ㌀ 한글 👨‍👩‍👧 🇯🇵"
    var c = s.normalize(nfc)
    var d = s.normalize(nfd)
    var kc = s.normalize(nfkc)
    var kd = s.normalize(nfkd)
    println(s.codepoints.count, " ", c.codepoints.count, " ", d.codepoints.count, " ", kc.codepoints.count, " ", kd.codepoints.count, " ", kc)
    var gs = s.graphemes
    println(gs.count, " [", gs[0], "] [", gs[6], "] [", gs[8], "] [", gs[10], "] [", gs[11], "]")
    for g in gs { print(g.codepoints.count, " ") }
    println()
    var up = s.upper()
    var low = up.lower()
    var sharp = $"Straße"
    var fold = sharp.fold()
    let e = $"é".codepoints[0]                   // a codepoint is a u32 (#527)
    var name = e.name
    var han = $"한".codepoints[0].name
    var cjk = (0x4E2D as u32).name
    var none = (0xE000 as u32).name
    var dec = e.decomposition
    var compat = $"ﬁ".codepoints[0].compatibility
    var plain = ('a' as u32).decomposition
    let acute:u32 = 0x301
    println(up, " ", low == s, " ", fold, " ", name, " ", e.category, " ", acute.combining, " ", e.combining)
    let sharp_s:u32 = 0xDF
    var cased = $""
    cased += ('A' as u32).lower
    cased += sharp_s.upper
    cased += sharp_s.fold
    cased += ('Z' as u32).fold
    cased += (0x3A9 as u32).lower
    println(cased, " ", ('a' as u32).upper, " ", e.upper.hex)
    println(dec.codepoints.count, " ", compat, " ", han, " ", cjk, " [", none, "] ", plain.count)
    println(('a' as u32).isLetter, " ", ('1' as u32).isNumber, " ", (' ' as u32).isSpace, " ", (',' as u32).isPunctuation, " ", ('+' as u32).isSymbol, " ", acute.isMark, " ", ('1' as u32).category, " ", (0x1F600 as u32).category)
    return 0
}
// out: 18 17 22 21 27 é fi アパート 한글 👨‍👩‍👧 🇯🇵
// out: 12 [é] [한] [ ] [ ] [🇯🇵]
// out: 2 1 1 1 1 1 1 1 1 5 1 2 
// out: É ﬁ ㌀ 한글 👨‍👩‍👧 🇯🇵 true straße LATIN SMALL LETTER E WITH ACUTE Ll 230 0
// out: aßßzω 65 0xc9
// out: 2 fi HANGUL SYLLABLE HAN CJK UNIFIED IDEOGRAPH-4E2D [] 0
// out: true true true true true true Nd So
