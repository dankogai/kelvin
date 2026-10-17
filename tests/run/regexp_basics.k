// #import <RegExp> (#157): $/.../ literals, test, exec, search, match with
// and without g, the groups and their names, the flags, and the texts
#import <RegExp>
let main():int32 {
    let re = $/(\d{4})-(?<month>\d\d)/g
    var s = $"2026-10-17 and 2027-01-02"
    println(re.test(&s), " ", re.groups, " ", re.global, " ", re.source, " ", re.flags, " ", re.search(&s))
    var ms = s.match(&re)
    println(ms.count)
    for m in ms {
        var month = m["month"]
        var whole = m[0]
        print(whole, " ", m.text[1], " ", month, " ", m.start, " ", m.end, " ", m.count)
        println(" ", m.has(2), " ", m.startOf(2), " ", m.endOf(2))
    }
    let first = RegExp.compile("\\d+", "")
    var one = s.match(&first)
    println(one.count, " ", one[0].text[0], " ", first.global, " ", first.groups)
    if let m = re.exec(&s) { println("exec ", m.text[0]) } else { println("none") }
    var plain = $"nothing here"
    if let m = re.exec(&plain) { println("exec ", m.text[0]) } else { println("none") }
    if let m = re.execFrom(&s, 8) { println("from 8: ", m.text[0], " ", m.start) }
    let opt = $/(a)?(b)/
    var b = $"b"
    var om = b.match(&opt)
    println(om[0].has(1), " ", om[0].has(2), " [", om[0].text[1], "] ", om[0].startOf(1))
    let alt = $/cat|dog/gi
    var pets = $"Cat, dog, bird"
    var pm = pets.match(&alt)
    println(pm.count, " ", pm[0].text[0], " ", pm[1].text[0], " ", alt.ignoreCase, " ", pets.search(&alt), " ", pets.test(&alt))
    let sticky = $/\d/y
    let x = $/x/
    var digits = $"12x3"
    var sm = digits.match(&sticky)
    println(sm.count, " ", sticky.sticky, " ", digits.search(&x))
    var pat = $"(\\d+)F"                                     // RegExp(pattern, flags), each a cstr or a String borrowed (#162)
    var flg = $"gi"
    let r1 = RegExp("(\\d+)F", "g")
    let r2 = RegExp(&pat, &flg)
    let r3 = RegExp.compile("x", &flg)
    var temps = $"212f and 32F"
    var m1 = temps.match(&r1)
    var m2 = temps.match(&r2)
    println(m1.count, " ", m2.count, " ", r2.flags, " ", r3.ignoreCase, " ", r1.source)
    return 0
}
// out: true 2 true (\d{4})-(?<month>\d\d) g 0
// out: 2
// out: 2026-10 2026 10 0 7 3 true 5 7
// out: 2027-01 2027 01 15 22 3 true 20 22
// out: 1 2026 false 0
// out: exec 2026-10
// out: none
// out: from 8: 2027-01 15
// out: false true [] -1
// out: 2 Cat dog true 0 true
// out: 1 true 2
// out: 1 2 gi true (\d+)F
