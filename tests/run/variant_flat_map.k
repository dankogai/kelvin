// x.flatMap(f) (#81): f's own U? or Result<U, E> of the value when that
// is the case, else none or the err carried over; chained, mixed with
// map, of a call that gives an owner, by name and as a trailing function
let half(n:i64):i64? {
    if n % 2 != 0 { return none }
    return n / 2
}
let parse(s:cstr):Result<i64, String> {
    if s.count == 0 { return err($"empty") }
    for c in s { if c < '0' || c > '9' { return err($`not a number: ${s}`) } }
    return i64(s)
}
let positive(n:i64):Result<i64, String> {
    if n == 0 { return err($"zero") }
    return n
}
let twice(n:i64):i64 { return n * 2 }
let keep(n:i64):Result<i64, i32> {
    if n > 9 { return err(9) }
    return n
}
let main():i32 {
    var a:int64? = 12
    var b:i64? = 3
    var c:i64? = none
    var a1 = a.flatMap(half)
    var a2 = a.flatMap(half).flatMap(half).flatMap(half)
    var b1 = b.flatMap(half)
    var c1 = c.flatMap(half)
    println(a1.cstr, " ", a2.cstr, " ", b1.cstr, " ", c1.cstr, " ", a1.typename)
    var a3 = a.flatMap { half($0) }
    var a4 = a.map(twice).flatMap(half)
    println(a3.cstr, " ", a4.cstr)
    var r1 = parse("42").flatMap(positive)
    var r2 = parse("0").flatMap(positive)
    var r3 = parse("x").flatMap(positive)
    println(r1.cstr, " ", r2.cstr, " ", r3.cstr, " ", r1.typename)
    var r4 = parse("21").map(twice).flatMap(positive).map(twice)
    var r5 = parse("0").flatMap { positive($0) }
    println(r4.cstr, " ", r5.cstr)
    var p:Result<i64, i32> = 5
    var p1 = p.flatMap(keep)
    println(p1.cstr, " ", p.cstr)
    return 0
}
// out: some(6) none none none i64?
// out: some(6) some(12)
// out: ok(42) err("zero") err("not a number: x") Result<i64, String>
// out: ok(84) err("zero")
// out: ok(5) ok(5)
// c: _kv_t.tag == 1 ? half(_kv_t.u.some) : _kv__kv_opt_i64_make_none();
// c: _kv_t.tag == 0 ? positive(_kv__kv_res_i64_String_take(&_kv_t).u.ok) : _kv__kv_res_i64_String_make_err(_kv__kv_res_i64_String_take(&_kv_t).u.err);
