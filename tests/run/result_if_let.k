// Result<T, U> (#75) and if let (#74): ok and err, a T wrapped as ok where
// a Result is expected, ok(v) and err(e) as words, .ok and .err checked,
// ??, switch, if let binding the value of an Optional or a Result, with an
// else, of a place or of a value a call gives, owners included
struct point { x: i32; y: i32 }
let parse(s:cstr):Result<i64, String> {
    if s.count == 0 { return err($"empty") }
    if s[0] == '-' { return Result<i64, String>.err($"negative") }
    return i64(s)
}
let first(xs:$[String]^):String? {
    if xs^.count == 0 { return none }
    return xs^[0].copy()
}
let find(xs:$[i64]^, v:i64):i64? {
    for i in 0..<xs^.count { if xs^[i] == v { return i } }
    return none
}
let main():i32 {
    var r = parse("42")
    var e = parse("")
    println(r.is(ok), " ", r.ok, " ", e.is(err), " ", e.err, " ", r.typename, " ", r.cstr, " ", e.cstr)
    if let v = r { println("ok ", v + 1) } else { println("not ok") }
    if let v = e { println("ok ", v) } else { println("err ", e.err) }
    if let v = parse("7") { println("direct ", v) }
    if let w = parse("-1") { println(w) } else { println("else") }
    println(r ?? -1, " ", e ?? -1)
    switch e {
    case ok: println(e.ok)
    case err: println("E:", e.err)
    }
    var names = $[$"ann"]
    if let n = first(&names) { println(n, " ", n.count) }
    var none_names:$[String] = $[]
    if let n = first(&none_names) { println(n) } else { println("none") }
    var xs = $[5, 6, 7]
    var i = find(&xs, 6)
    if let k = i { println("at ", k, " ", xs[k]) }
    if let k = find(&xs, 9) { println(k) } else if let k2 = find(&xs, 5) { println("first at ", k2) }
    var q:Result<point, i32> = {1, 2}
    var bad:Result<point, i32> = err(404)
    println(q.ok.y, " ", bad.err, " ", q.typename)
    var o = Optional<i64>.some(3)
    var z = Optional<i64>.none
    var w = Result<i64, cstr>.ok(5)
    println(o.some, " ", z.is(none), " ", w.ok, " ", w.typename)
    var rs:$[Result<i64, String>] = $[1, err($"x"), ok(3)]
    var sum:i64 = 0
    for x in rs { if let v = x { sum += v } }
    println(rs.count, " ", sum)
    e = 5
    e.err = $"later"
    println(e.cstr)
    return 0
}
// out: true 42 true empty Result<i64, String> ok(42) err(empty)
// out: ok 43
// out: err empty
// out: direct 7
// out: else
// out: 42 -1
// out: E:empty
// out: ann 3
// out: none
// out: at 1 6
// out: first at 0
// out: 2 404 Result<point, i32>
// out: 3 true 5 Result<i64, cstr>
// out: 3 4
// out: err(later)
// c: /* Result<i64, String> */
// c: struct _kv_res_i64_String parse(const uint8_t *const s)
// c: __auto_type _kv_v_opt = &(r);
// c: __attribute__((cleanup(_kv__kv_opt_String_free))) struct _kv_opt_String _kv_n_opt = first(&names);
