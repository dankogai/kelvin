// Optional<T>, T? (#72): none and some, a T wrapped where a T? is expected,
// .some checked, ??, .is, .case, switch, results, members, elements,
// entries, owners, Optional<T>(), T??
struct point { x: i32; y: i32 }
let find(xs:$[i64]^, v:i64):i64? {
    for i in 0..<xs^.count { if xs^[i] == v { return i } }
    return none
}
let first(names:$[String]^):String? {
    if names^.count == 0 { return none }
    return names^[0].copy()
}
let main():i32 {
    var a:i64? = 3
    var b:i64? = none
    println(a.is(some), " ", b.is(none), " ", a.some, " ", a ?? 0, " ", b ?? -1, " ", a.typename, " ", a.cstr, " ", b.cstr)
    a = none
    b = 9
    b.some += 1
    println(a.is(none), " ", b.some, " ", a.case, " ", b.case)
    var xs = $[5, 6, 7]
    var i = find(&xs, 7)
    var j = find(&xs, 8)
    switch i {
    case some: println("at ", i.some)
    case none: println("absent")
    }
    println(j.is(none), " ", (i ?? -1) + (j ?? -1))
    var names = $[$"ann"]
    var n = first(&names)
    var e:$[String] = $[]
    var m = first(&e)
    println(n.is(some), " ", n.some, " ", m.is(none), " ", n.typename)
    n.some += "!"
    n = $"bob"
    println(n.some, " ", n.cstr)
    var p:point? = {1, 2}
    var q = Optional<point>()
    var r = Optional<i64>(4)
    println(p.some.x, " ", q.is(none), " ", r.some, " ", r.typename, " ", p.typename)
    var opts:$[i64?] = $[1, none, 3]
    var cnt:i64 = 0
    for o in opts { if o.is(some) { cnt += o.some } }
    println(opts.count, " ", cnt, " ", opts.typename)
    var d:${String: i64?} = ${"a": 1, "b": none}
    println(d["a"] ?? 0, " ", d["b"] ?? 0, " ", d.typename)
    var nested:i64?? = 5
    println(nested.some.some, " ", nested.typename)
    return 0
}
// out: true true 3 3 -1 i64? some(3) none
// out: true 10 0 1
// out: at 2
// out: true 1
// out: true ann true String?
// out: bob some(bob)
// out: 1 true 4 i64? point?
// out: 3 4 Array<i64?>
// out: 1 0 Dictionary<String, i64?>
// out: 5 i64??
// c: /* i64? */
// c: struct _kv_opt_i64 a = _kv__kv_opt_i64_make_some(3);
// c: a = _kv__kv_opt_i64_make_none();
// c: struct _kv_opt_i64 find(_kv_array_i64 *const xs, const int64_t v)
