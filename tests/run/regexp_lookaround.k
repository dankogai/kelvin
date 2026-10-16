// RegExp (#157): lookahead and lookbehind, positive and negative, with
// groups inside them, backreferences by number and by name, lazy and
// counted quantifiers, and the empty check of a loop
#import <RegExp>
let main():int32 {
    var prices = $"cost $12.50 or $7, not 9"
    let priced = $/(?<=\$)\d+(?:\.\d+)?/g
    let unpriced = $/(?<!\$)\b\d+\b/g
    var pm = prices.match(&priced)
    var nm = prices.match(&unpriced)
    println(pm.count, " ", pm[0].text[0], " ", pm[1].text[0], " ", nm.count, " ", nm[0].text[0])
    var foos = $"foobar foobaz"
    let ahead = $/foo(?=bar)/g
    let notAhead = $/foo(?!bar)/g
    var la = foos.match(&ahead)
    var nla = foos.match(&notAhead)
    println(la.count, " ", la[0].start, " ", nla.count, " ", nla[0].start)
    let behindGroup = $/(?<=(\w))c/
    let behindDigits = $/(?<=(\d+))x/
    var abc = $"abc"
    var num = $"123x"
    var cap = abc.match(&behindGroup)
    var lb = num.match(&behindDigits)
    println(cap[0].text[1], " ", lb[0].text[1])
    let lazyTag = $/<(.+?)>/g
    let greedyTag = $/<(.+)>/g
    var tagged = $"<a><bc>"
    var tags = tagged.match(&lazyTag)
    var greedy = tagged.match(&greedyTag)
    println(tags.count, " ", tags[1].text[1], " ", greedy.count, " ", greedy[0].text[1])
    let doubled = $/(\w)\1/g
    let namedBack = $/(?<x>a)(?<y>b)\k<y>\k<x>/
    var moon = $"look at the moon"
    var abba = $"abba"
    var dbl = moon.match(&doubled)
    var named = abba.match(&namedBack)
    println(dbl.count, " ", dbl[1].text[0], " ", named.count, " ", named[0].text[0])
    let twoThree = $/a{2,3}/g
    let two = $/a{2}/g
    let twoPlus = $/ab{2,}/g
    var a4 = $"aaaa"
    var a5 = $"aaaaa"
    var abs = $"ab abb abbb"
    var counted = a4.match(&twoThree)
    var exact = a5.match(&two)
    var atleast = abs.match(&twoPlus)
    println(counted.count, " ", counted[0].text[0], " ", exact.count, " ", atleast.count, " ", atleast[0].text[0], " ", atleast[1].text[0])
    let starStar = $/(a*)*b/
    let starPlus = $/(a*)+b/
    let either = $/(?:(a)|b)+/
    var b = $"b"
    var aab = $"aab"
    var ab = $"ab"
    var star = b.match(&starStar)
    var inner = aab.match(&starPlus)
    var reset = ab.match(&either)
    println(star[0].has(1), " ", inner[0].text[1].count, " ", reset[0].has(1))
    let ciBack = $/(ab)\1/i
    var abab = $"Abab"
    var ci = abab.match(&ciBack)
    println(ci.count, " ", ci[0].text[0])
    let modified = $/(?i:a)b|(?-i:c)d/gi
    var cases = $"Ab AB cd CD"
    var mm = cases.match(&modified)
    println(mm.count, " ", mm[0].text[0], " ", mm[1].text[0])
    return 0
}
// out: 2 12.50 7 2 50
// out: 1 0 1 7
// out: b 123
// out: 2 bc 1 a><bc
// out: 2 oo 1 abba
// out: 1 aaa 2 2 abb abbb
// out: false 2 false
// out: 1 Abab
// out: 3 Ab AB
