// RegExp (#157): replace with $1, $<name>, $&, $`, $' and $$, all matches
// with g and the first without, empty matches, and split as JS cuts text
#import <RegExp>
let main():int32 {
    var s = $"2026-10-17 and 2027-01-02"
    let dated = $/(\d{4})-(?<month>\d\d)/g
    let year = $/(\d{4})/
    let and = $/and/
    let dash = $/-/g
    var a = s.replace(&dated, "$<month>/$1")
    var b = s.replace(&year, "[$&]")
    var c = s.replace(&and, "<$`|$'>")
    var d = s.replace(&dash, "$$")
    println(a)
    println(b)
    println(c)
    println(d)
    var abc = $"abc"
    let xs = $/x*/g
    let nothing = $//g
    let bs = $/b*/g
    var e = abc.replace(&xs, "-")
    var f = abc.replace(&nothing, "-")
    var g = abc.replace(&bs, "-")
    println(e, " ", f, " ", g)
    var aaa = $"aaa"
    var dotted = $"a.b.c"
    var x = $"x"
    let one = $/a/g
    let dot = $/\./g
    let y = $/y/
    var h = aaa.replace(&one, "bb")
    var i = dotted.replace(&dot, "")
    var j = x.replace(&y, "z")
    println(h, " ", i, " ", j)
    var tpl = $"$<month>/$1"                                   // the replacement a String, borrowed (#161)
    var k = s.replace(&dated, &tpl)
    var l = dated.replace(&s, &tpl)
    println(k, " ", k == l)
    let comma = $/\s*,\s*/
    let each = $//
    let blanks = $/\s+/
    let bare = $/,/
    var list = $"a , b,c ,  d"
    var word = $"héllo"
    var three = $"one  two three"
    var edged = $",a,,b,"
    var empty = $""
    var parts = list.split(&comma)
    var chars = word.split(&each)
    var words = three.split(&blanks)
    var edges = edged.split(&bare)
    var none = abc.split(&y)
    var e1 = empty.split(&bare)
    var e2 = empty.split(&each)
    println(parts, " ", chars, " ", words, " ", edges, " ", none, " ", e1, " ", e2)
    return 0
}
// out: 10/2026-17 and 01/2027-02
// out: [2026]-10-17 and 2027-01-02
// out: 2026-10-17 <2026-10-17 | 2027-01-02> 2027-01-02
// out: 2026$10$17 and 2027$01$02
// out: -a-b-c- -a-b-c- -a--c-
// out: bbbbbb abc x
// out: 10/2026-17 and 01/2027-02 true
// out: ["a", "b", "c", "d"] ["h", "é", "l", "l", "o"] ["one", "two", "three"] ["", "a", "", "b", ""] ["abc"] [""] []
