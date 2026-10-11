// x.map(f), x.map { ... } and r.mapErr(g) (#80): a U? or a Result<U, E>
// of f's result, of the value when that is the case, else the other
// case carried over; f a function by name, a function value, or an
// anonymous function whose result kelvinc sees or which writes it; of
// a call that gives an owner, or of a copy, and chained
let twice(n:i64):i64 { return n * 2 }
let text(n:i64):String { return $`#${n}` }
let parse(s:cstr):Result<i64, String> {
    if s.count == 0 { return err($"empty") }
    for c in s { if c < '0' || c > '9' { return err($`not a number: ${s}`) } }
    return i64(s)
}
let code(s:String):i32 { return s.count as i32 }
let main():i32 {
    var a:i64? = 3
    var n:i64? = none
    var b = a.map(twice)
    var c = n.map(twice)
    println(b.cstr, " ", c.cstr, " ", b.typename)
    var d = a.map { $0 > 2 }
    var e = a.map { i64($0 * 10) }
    var g = a.map { (v:i64):f64 in v / 2.0 }
    var h = a.map({ $0 == 3 })
    println(d.cstr, " ", e.cstr, " ", g.cstr, " ", h.cstr)
    var s = a.map(text)
    println(s.cstr, " ", s.some.count, " ", s.typename)
    var r = parse("21").map(twice)
    var f = parse("x").map(twice)
    println(r.cstr, " ", f.cstr)
    var k = parse("x").mapErr(code)
    var l = parse("8").mapErr(code)
    println(k.cstr, " ", l.cstr, " ", k.typename)
    var t = parse("7").map(text)
    println(t.cstr, " ", t.typename)
    var p:Result<i64, i32> = 5
    var q = p.map(twice)
    var q2 = p.map { $0 > 4 }
    println(q.cstr, " ", q2.cstr, " ", p.cstr)
    var w = r.copy().map(twice)
    var w2 = parse("5").map(twice).map(twice)
    println(w.cstr, " ", w2.cstr)
    let inc:(i64):i64 := { $0 + 1 }
    var i = a.map(inc)
    println(i.cstr)
    return 0
}
// out: some(6) none i64?
// out: some(true) some(30) some(1.5) some(true)
// out: some(#3) 2 String?
// out: ok(42) err(not a number: x)
// out: err(15) ok(8) Result<i64, i32>
// out: ok(#7) Result<String, String>
// out: ok(10) ok(true) ok(5)
// out: ok(84) ok(20)
// out: some(4)
// c: _kv_t.tag == 1 ? _kv__kv_opt_i64_make_some(twice(_kv_t.u.some)) : _kv__kv_opt_i64_make_none();
// c: __attribute__((cleanup(_kv__kv_res_i64_String_free))) struct _kv_res_i64_String _kv_t = parse("21");
