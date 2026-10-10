// |, & and ~ on Sets (#73): the union, the intersection and the symmetric
// difference, new Sets; |=, &= and ~= in place
let main():i32 {
    var s = ${1, 2, 3}
    var t = ${3, 4}
    var u = s | t
    var i = s & t
    var x = s ~ t
    for e in u { print(e, " ") }
    println(u.count, " ", i.count, " ", i.has(3), " ", x.count, " ", x.has(3), " ", x.has(1), " ", x.has(4))
    s |= t
    println(s.count)
    s &= t
    println(s.count, " ", s.has(1))
    var v = ${4, 5}
    s ~= v
    println(s.count, " ", s.has(3), " ", s.has(5))
    var wa = ${"a", "b"}
    var wb = ${"c"}
    var w = wa | wb
    println(w.count)
    return 0
}
// out: 1 2 3 4 4 1 true 3 false true true
// out: 4
// out: 2 false
// out: 2 true true
// out: 3
// c: _kv_set_i64 u = _kv_set_i64_union(&s, &t);
// c: _kv_set_i64 x = _kv_set_i64_symdiff(&s, &t);
// c: _kv_set_i64_intersect_with(&s, &t);
