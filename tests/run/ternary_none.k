// none as an arm of ?: (#116): c ? v : none where a T? is expected, in a
// return, a declaration with the type written, or a one-expression body,
// wraps each arm on its own; c ? Optional<i64>(v) : none infers the type
// from the arm that has one; a Result's arms take ok(v) and err(e), or a
// value, the same way
let half(v:i64):i64? { return v % 2 == 0 ? v / 2 : none }
let third(v:i64):i64? { v % 3 == 0 ? v / 3 : none }
let parse(s:cstr):Result<i64, cstr> { return s.count > 0 ? ok(i64(s)) : err("empty") }
let pick(s:cstr):Result<i64, cstr> { s.count > 0 ? i64(s) : err("empty") }
let main():i32 {
    var a = half(8)
    var b = half(7)
    var c = third(9)
    var d = third(8)
    println(a.cstr, " ", b.cstr, " ", c.cstr, " ", d.cstr)
    let n:i64 = 5
    var e = n > 2 ? Optional<i64>(n) : none
    var f = n > 9 ? none : Optional<i64>(n)
    var g:i64? = n > 9 ? n : none
    println(e.cstr, " ", f.cstr, " ", g.cstr, " ", e.typename)
    var p = parse("42")
    var q = parse("")
    var r = pick("7")
    var s = pick("")
    println(p.cstr, " ", q.cstr, " ", r.cstr, " ", s.cstr)
    let twice := { (v:i64):i64? in v > 2 ? v * 2 : none }
    var t = twice(3)
    var u = twice(1)
    println(t.cstr, " ", u.cstr)
    var w:String? = n > 2 ? $"text" : none
    println(w.cstr)
    return 0
}
// out: some(4) none some(3) none
// out: some(5) some(5) none i64?
// out: ok(42) err(empty) ok(7) err(empty)
// out: some(6) none
// out: some(text)
