// RegExp is the prelude's (#504): a program that names it, or writes a
// $/.../ literal, has it, Match and BytesMatch, with no #import <RegExp>,
// which still builds, doing nothing; libkelvin holds its code
let months(s:const String^, re:const RegExp^):Array<String> {
    var out:Array<String> = $[]
    for m in s^.match(re) { out.append(m["month"].copy()) }
    return out
}
let main():int32 {
    var s = $"2026-10-17 and 2027-01-02"
    let re = $/(\d{4})-(?<month>\d\d)/g
    println(re.test(&s), " ", s.replace(&re, "$<month>/$1"), " ", months(&s, &re))
    let words = RegExp("\\s+", "")
    println(s.split(&words))
    let m:Match = s.match(&$/(\d+)-/)[0]
    println(m[1], " ", m.start)
    var b = Bytes("a1b22")
    let bm:Array<BytesMatch> = b.match(&$/\d+/g)
    println(bm.count, " ", $/é/i.test(&$"É"))
    return 0
}
// out: true 10/2026-17 and 01/2027-02 ["10", "01"]
// out: ["2026-10-17", "and", "2027-01-02"]
// out: 2026 0
// out: 2 true
