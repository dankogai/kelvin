// try x (#76): x's value when its case is ok (some), else the function
// returns the err (none) as it is: of a call and of a place, in an
// Optional, with owners as the value and as the err, in an expression,
// and alone as a statement
struct point { x: int32; y: int32 }
let parse(s:cstr):Result<int64, String> {
    if s.count == 0 { return err($"empty") }
    for c in s { if c < '0' || c > '9' { return err($`not a number: ${s}`) } }
    return int64(s)
}
let twice(s:cstr):Result<int64, String> {
    let n = try parse(s)                 // the value, or the err passed up
    return n * 2
}
let sum(a:cstr, b:cstr):Result<int64, String> {
    return try parse(a) + try parse(b)   // (try parse(a)) + (try parse(b))
}
let fromPlace(s:cstr):Result<int64, String> {
    var r = parse(s)
    let n = try r                        // of a place: the err moves out of r
    return n + 1
}
let find(xs:$[int64]^, v:int64):int64? {
    for i in 0..<xs^.count { if xs^[i] == v { return i } }
    return none
}
let after(xs:$[int64]^, v:int64):int64? {      // an Optional passes none up
    let i = try find(xs, v)
    if i + 1 >= xs^.count as int64 { return none }
    return xs^[i + 1]
}
let name(n:int64):Result<String, int32> {
    if n < 0 { return err(1) }
    return $`#${n}`
}
let greet(n:int64):Result<String, int32> {
    var s = try name(n)                  // an owner value moves out of the call
    s += "!"
    return s
}
let check(n:int64):Result<int64, int32> {
    try name(n)                          // alone: the value is dropped, the err passed up
    return n
}
let origin(ok:bool):Result<point, cstr> {
    if !ok { return err("no") }
    return (point){0, 0}
}
let shifted(ok:bool):Result<point, cstr> {
    var p = try origin(ok)
    p.x += 1
    return p
}
let main():int32 {
    var d1 = twice("21")
    var d2 = twice("x")
    var d3 = twice("")
    println(d1.ok, " ", d2.err, " ", d3.err)
    var s1 = sum("1", "2")
    var s2 = sum("1", "y")
    println(s1.ok, " ", s2.err)
    var p1 = fromPlace("41")
    var p2 = fromPlace("z")
    println(p1.ok, " ", p2.err)
    var xs = $[5, 6, 7]
    var a = after(&xs, 5)
    var b = after(&xs, 7)
    var c = after(&xs, 9)
    println(a.some, " ", b.is(none), " ", c.is(none))
    var g1 = greet(3)
    var g2 = greet(-1)
    println(g1.ok, " ", g2.err)
    var c1 = check(2)
    var c2 = check(-2)
    println(c1.ok, " ", c2.err)
    var t1 = shifted(true)
    var t2 = shifted(false)
    println(t1.ok.x, " ", t2.err)
    return 0
}
// out: 42 not a number: x empty
// out: 3 not a number: y
// out: 42 not a number: z
// out: 6 true true
// out: #3! 1
// out: 2 1
// out: 1 no
// c: if (_kv_t.tag != 0) return _kv__kv_res_i64_String_make_err(_kv__kv_res_i64_String_take(&_kv_t).u.err);
// c: if (_kv_p->tag != 0) return
// c: if (_kv_t.tag != 1) return _kv__kv_opt_i64_make_none();
