// == and != on a Result, an Optional and an enum with values (#79): the
// same case, and equal values; a value, none, ok(v) or err(e) on the
// other side is wrapped (an err($"x") made on the spot is not, as nothing
// would free it); Strings by their bytes, nested variants by their own ==
enum json { n: f64; s: String; none }
let parse(s:cstr):Result<i64, String> {
    if s.count == 0 { return err($"empty") }
    return i64(s)
}
let main():i32 {
    var a:i64? = 3
    var b:i64? = 3
    var c:i64? = none
    println(a == b, " ", a != b, " ", a == c, " ", c == none, " ", a == none, " ", a == 3, " ", 4 == a, " ", c != 3)
    var r = parse("42")
    var s = parse("42")
    var e = parse("")
    var f = parse("")
    println(r == s, " ", r == e, " ", e == f, " ", r == 42, " ", r != 42, " ", r == ok(41))
    var t:String? = $"hi"
    var u:String? = $"hi"
    var v:String? = none
    println(t == u, " ", t == v, " ", v == none, " ", t != v)
    var j = json.n(1.5)
    var k = json.n(1.5)
    var l = json.none
    println(j == k, " ", j == l, " ", l == json.none, " ", j != json.n(2.5))
    var nn:i64?? = a
    var mm:i64?? = b
    println(nn == mm, " ", nn == none)
    var p:Result<cstr, i32> = "x"
    var q:Result<cstr, i32> = err(2)
    println(p == q, " ", q == err(2), " ", p != p)
    return 0
}
// out: true false false true false true false true
// out: true false true true false false
// out: true false true true
// out: true false true true
// out: true false
// out: false true false
// c: static inline bool _kv__kv_opt_i64_eq(const struct _kv_opt_i64 a, const struct _kv_opt_i64 b)
// c: case 1: return kv_string_eq(&a.u.some, &b.u.some);
// c: case 1: return _kv__kv_opt_i64_eq(a.u.some, b.u.some);
