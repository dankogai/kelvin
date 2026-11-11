// RegExp's offsets in a String are of graphemes (#522), as s[i] and
// s[lo..<hi] are: a match's start the grapheme it begins in, its end past
// the grapheme it ends in, so that s[m.start..<m.end] holds the match;
// execFrom's from is a grapheme index
let main():int32 {
    var s = $"é ﬁ 👨‍👩‍👧 x42"
    let digits = $/\d+/
    if let some(m) = digits.exec(&s) { println(m.start, " ", m.end, " ", s[m.start..<m.end], " ", s.search(&digits)) }
    let acute = $/́/
    if let some(m) = acute.exec(&s) { println(m.start, " ", m.end, " ", s[m.start..<m.end], " ", m[0].codepoints.count) }
    if let some(m) = $/\S/.execFrom(&s, 4) { println(m.start, " ", m[0]) }
    let words = $/\S+/g
    var spans:$[i64] = $[]
    for m in s.match(&words) {
        spans += m.start
        spans += m.end
    }
    println(spans)
    return 0
}
// out: 7 9 42 7
// out: 0 1 é 1
// out: 4 👨
// out: [0, 1, 2, 3, 4, 5, 6, 9]
