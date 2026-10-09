// an enum with values (#61): a union that knows its case; made by {.n = x},
// T.n(x) and T.none, set by v.n = x, read checked, tested with .is() and
// .case, switched on by name; its text; without a tag; in an Array
enum shape { none; circle: f64; rect: {w:f64, h:f64} }
let area(s:shape):f64 {
    switch (s) {
    case circle: return 3.0 * s.circle * s.circle
    case rect: return s.rect.w * s.rect.h
    default: return 0.0
    }
}
let main():i32 {
    var s:shape = {.circle = 2.0}
    println(s.cstr, " ", s.case, " ", s.is(circle), " ", s.is(none), " ", area(s))
    s.rect = {3.0, 4.0}
    println(s.cstr, " ", s.case, " ", area(s), " ", s.rect.w)
    s.rect.w += 1.0
    println(s.rect.w)
    var t = shape.circle(1.0)
    var n = shape.none
    println(t.cstr, " ", n.cstr, " ", n.typename, " ", t.size)
    var a:enum{i:i32, f:f32} = {.f = 1.5}
    println(a.cstr, " ", a.typename, " ", a.f)
    a.i = 7
    println(a.cstr, " ", a.i)
    var e:shape
    println(e.cstr)
    var xs = Array([shape.circle(1.0), shape.none])
    for x in xs { print(x.cstr, " ") }
    println(xs.count)
    return 0
}
// out: circle(2) 1 true false 12.0
// out: rect({w: 3, h: 4}) 2 12.0 3.0
// out: 4.0
// out: circle(1) none shape 24
// out: f(1.5) enum{i: i32, f: f32} 1.5
// out: i(7) 7
// out: none
// out: circle(1) none 2
// c: struct shape
// c: uint8_t tag;
// c: struct shape s = {.tag = 1, .u.circle = 2.0};
// c: _kv_shape_set_rect(&s, (struct _kv_anon1){3.0, 4.0});
// c: (*_kv_shape_at_rect(&s)).w += 1.0;
// c: struct shape t = _kv_shape_make_circle(1.0);
// c: case 1: /* circle */
