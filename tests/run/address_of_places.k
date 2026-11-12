// & takes a place, a variable, a member, an element or p^, a compound
// literal, and a function's name; an owner an expression gives is held
// and has an address too (#535 leaves them as they were)
struct pt { x: i64; y: i64 }
struct line { a: pt; b: pt }
let name():String { $"n" }
let take(p:const i64^):i64 { p^ }
let takes(s:const String^):i64 { s^.count as i64 }
let takep(p:const pt^):i64 { p^.x }
let main():int32 {
    var x = 1
    var s = $"ab"
    var xs = $[1, 2]
    var p:pt = {1, 2}
    var q:i64^ := &x
    var l:line = {{1, 2}, {3, 4}}
    let rx := &x
    let el := &xs[0]
    let pmx := &p.x
    let lm := &l.a.y
    let dq := &q^
    let cl := &(pt){5, 6}
    println(take(rx), " ", take(el), " ", take(pmx), " ", take(lm), " ", take(dq), " ", takes(&s))
    println(takes(&name()), " ", takes(&$"xyz"), " ", takep(&p), " ", takep(cl))
    return 0
}
// out: 1 1 1 2 1 2
// out: 1 3 1 5
