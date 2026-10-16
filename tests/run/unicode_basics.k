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
    println(s.count, " ", c.count, " ", d.count, " ", kc.count, " ", kd.count, " ", kc)
    var gs = s.graphemes
    println(gs.count, " [", gs[0], "] [", gs[6], "] [", gs[8], "] [", gs[10], "] [", gs[11], "]")
    for g in gs { print(g.count, " ") }
    println()
    var up = s.upper()
    var low = up.lower()
    var sharp = $"Straße"
    var fold = sharp.fold()
    var name = uchr("é").name
    var han = uchr("한").name
    var cjk = uchr("中").name
    var none = uchr(0xE000).name
    var dec = uchr("é").decomposition
    var compat = uchr("ﬁ").compatibility
    var plain = uchr("a").decomposition
    println(up, " ", low == s, " ", fold, " ", name, " ", uchr("é").category, " ", uchr("\u0301").combining, " ", uchr("é").combining)
    println('A'.uchr.lower, " ", uchr("ß").upper, " ", uchr("ß").fold, " ", 'Z'.uchr.fold, " ", uchr("Ω").lower)
    println(dec.count, " ", compat, " ", han, " ", cjk, " [", none, "] ", plain.count)
    println('a'.uchr.isLetter, " ", '1'.uchr.isNumber, " ", ' '.uchr.isSpace, " ", ','.uchr.isPunctuation, " ", '+'.uchr.isSymbol, " ", uchr("\u0301").isMark, " ", '1'.uchr.category, " ", uchr("😀").category)
    return 0
}
// out: 18 17 22 21 27 é fi アパート 한글 👨‍👩‍👧 🇯🇵
// out: 12 [é] [한] [ ] [ ] [🇯🇵]
// out: 2 1 1 1 1 1 1 1 1 5 1 2 
// out: É ﬁ ㌀ 한글 👨‍👩‍👧 🇯🇵 true straße LATIN SMALL LETTER E WITH ACUTE Ll 230 0
// out: a ß ß z ω
// out: 2 fi HANGUL SYLLABLE HAN CJK UNIFIED IDEOGRAPH-4E2D [] 0
// out: true true true true true true Nd So
