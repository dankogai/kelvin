// if let err(e) = r (#78): the case by its name binds its value: a
// Result's ok and err, an Optional's some, and an enum with values'
// case, of a place or of a value a call gives, chained with else if
enum json { n: f64; s: String; none }
let parse(s:cstr):Result<i64, String> {
    if s.count == 0 { return err($"empty") }
    for c in s { if c < '0' || c > '9' { return err($`not a number: ${s}`) } }
    return i64(s)
}
let main():i32 {
    var r = parse("")
    var k = parse("42")
    if let err(e) = r { println("err ", e) } else { println("ok") }
    if let err(e) = k { println("err ", e) } else { println("ok ", k.ok) }
    if let ok(v) = k { println("ok ", v + 1) }
    if let err(e) = parse("x") { println("call err ", e, " ", e.count) }
    if let ok(v) = r { println(v) } else if let err(e) = r { println("chained ", e) }
    var o:i64? = 3
    if let some(v) = o { println("some ", v) }
    var j = json.s($"txt")
    if let s(t) = j { println("s ", t, " ", t.count) } else { println("not s") }
    if let n(x) = j { println(x) } else { println("not n") }
    j = json.n(1.5)
    if let n(x) = j { println("n ", x) }
    return 0
}
// out: err empty
// out: ok 42
// out: ok 43
// out: call err not a number: x 15
// out: chained empty
// out: some 3
// out: s txt 3
// out: not n
// out: n 1.5
// c: if (_kv_e_opt->tag == 1)
// c: if (_kv_t_opt->tag == 1)
