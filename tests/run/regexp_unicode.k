// RegExp (#157): codepoints, \p{...} by category, script and property, \X,
// the i flag by case folding, \u{...}, and the m and s flags
#import <RegExp>
let main():int32 {
    var s = $"abc αβγ 中文 😀 ﾊﾟ"
    let greekRe = $/\p{Script=Greek}+/
    let hanRe = $/\p{sc=Hani}+/
    let lettersRe = $/\p{L}+/g
    let emojiRe = $/\p{Emoji_Presentation}/
    let otherRe = $/[^\p{Letter}\s]/
    var greek = s.match(&greekRe)
    var han = s.match(&hanRe)
    var letters = s.match(&lettersRe)
    var emoji = s.match(&emojiRe)
    var notLetter = s.match(&otherRe)
    println(greek[0].text[0], " ", greek[0].start, " ", han[0].text[0], " ", letters.count, " ", emoji[0].text[0], " ", emoji[0].start, " ", notLetter[0].text[0])
    let anyRe = $/./g
    let upperRe = $/\p{Lu}/g
    var mixed = $"aBcD"
    var dots = s.match(&anyRe)
    var lu = mixed.match(&upperRe)
    println(dots.count, " ", s.count, " ", lu.count, " ", lu[1].text[0])
    var fam = $"👨‍👩‍👧🇯🇵é!"
    let clusterRe = $/\X/g
    let threeRe = $/^\X\X\X!$/
    var clusters = fam.match(&clusterRe)
    println(clusters.count, " ", clusters[2].text[0].count, " ", threeRe.test(&fam))
    let ci = $/straße|ΣΊΣΥΦΟΣ/i
    let cig = $/straße|σίσυφος/gi
    var up = $"STRASSE STRAßE σίσυφος"
    var cm = up.match(&cig)
    println(ci.search(&up), " ", cm.count, " ", cm[1].text[0])
    let az = $/[a-z]/gi
    var kks = $"K k ſ"
    var ranges = kks.match(&az)
    println(ranges.count)
    let braces = $/\u{1F600}/
    let pair = $/😀/
    let tab = $/\x09|\cI/
    var smile = $"A😀Z"
    var tabbed = $"tab\there"
    var esc = smile.match(&braces)
    var esc2 = smile.match(&pair)
    var hex = tabbed.match(&tab)
    println(esc[0].start, " ", esc2[0].end, " ", hex[0].start)
    var lines = $"one\ntwo three\nfour"
    let wordLine = $/^\w+$/gm
    let wholeLine = $/^.+$/
    let wholeS = $/^.+$/s
    let dotStar = $/^.*$/
    let anything = $/^[^]*$/
    var starts = lines.match(&wordLine)
    var all = lines.match(&wholeLine)
    var allS = lines.match(&wholeS)
    println(starts.count, " ", all.count, " ", allS[0].text[0].count, " ", dotStar.test(&lines), " ", anything.test(&lines))
    let wordsRe = $/\w+/g
    let boundary = $/\bl/
    var hello = $"héllo wörld"
    var w = hello.match(&wordsRe)
    var b = hello.match(&boundary)
    println(w.count, " ", w[0].text[0], " ", b.count)
    var e = uchr("é")
    println(e.script, " ", e.hasProperty("Alphabetic"), " ", uchr("1").hasProperty("Alpha"), " ", uchr("😀").hasProperty("Emoji"))
    return 0
}
// out: αβγ 4 中文 4 😀 11 😀
// out: 15 15 2 D
// out: 4 2 true
// out: 8 2 σίσυφος
// out: 3
// out: 1 2 3
// out: 2 0 18 false true
// out: 4 h 1
// out: Latin true false true
