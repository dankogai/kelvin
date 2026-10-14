// a switch that binds the case's value (#119): case n(x): runs its body
// with x bound to the value, a let the enum still owns, as if let n(x)
// binds it; of an Optional, a Result, an enum with values; the same
// name may serve several cases; a value no place holds is read once
enum shape { none; dot: i64; name: String; pair: {x: i64, y: i64} }
let half(v:i64):i64? { v % 2 == 0 ? v / 2 : none }
let show(s:const shape^) {
    switch s^ {
    case none: println("none")
    case dot(n): println("dot ", n)
    case name(t): println("name ", t, " ", t.count)
    case pair(p): println("pair ", p.x, ",", p.y)
    }
}
let main():i32 {
    var a = half(8)
    var b = half(7)
    switch a {
    case some(v): println("some ", v, " ", v + 1)
    case none: println("none")
    }
    switch b {
    case some(v): println("some ", v)
    case none: println("none")
    }
    switch half(10) {                            // no place holds it: read once
    case some(v): println("of a call ", v)
    case none: println("none")
    }
    var r:Result<i64, String> = ok(3)
    switch r {
    case ok(v): println("ok ", v)
    case err(e): println("err ", e)
    }
    r = err($"bad")
    switch r {
    case ok(v): println("ok ", v)
    case err(e): println("err ", e, " ", e.count)
    }
    var s = shape.name($"kelvin")
    show(&s)
    s = shape.dot(7)
    show(&s)
    s = shape.pair({1, 2})
    show(&s)
    s = shape.none
    show(&s)
    var xs = $[shape.dot(1), shape.name($"two")]
    for x in xs {
        switch x {
        case dot(n): print("[", n, "]")
        case name(t): print("[", t, "]")
        default: print("[other]")
        }
    }
    println()
    return 0
}
// out: some 4 5
// out: none
// out: of a call 5
// out: ok 3
// out: err bad 3
// out: name kelvin 6
// out: dot 7
// out: pair 1,2
// out: none
// out: [1][two]
// c: __attribute__((unused)) const int64_t v = a.u.some;
// c: __attribute__((unused)) const kv_string e = r.u.err;
