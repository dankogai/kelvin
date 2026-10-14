// print and println show a struct kelvinc sees, an enum with values and
// a union with T.cstr() too, as its .cstr text, as a template does
// (#122): the derived text, or the type's own T.cstr(); f.print too;
// through kelvinc's printer of the type since #123
struct point { x: i64; y: i64 }
struct vector2d { x: f64; y: f64 }
let vector2d.cstr():cstr { `(${self.x}, ${self.y})` }
enum maybe { nothing; just: i64 }
let maybe.orZero():i64 { if let just(n) = self { return n }; return 0 }
let maybe.cstr():cstr { `<${self.orZero()}>` }
enum shape { dot; circle: f64 }
union bits { u: u64; f: f64 }
let bits.cstr():cstr { `bits ${self.u.hex}` }
let origin():point { return {0, 0} }
let main():i32 {
    let p:point = {1, 2}
    let v:vector2d = {1.5, -2.0}
    let pp := &p
    var b:bits = {.f = 1.0}
    println(p)
    println("p = ", p, ", v = ", v, ", n = ", 3)
    println(maybe.nothing, " ", maybe.just(7))
    println(shape.dot, " ", shape.circle(0.5))
    println(b)
    println(origin(), " ", pp^)
    print(p)
    println()
    IO.stdout.println(p, " ", v)
    IO.stdout.print(maybe.just(1))
    IO.stdout.println()
    return 0
}
// out: {x: 1, y: 2}
// out: p = {x: 1, y: 2}, v = (1.5, -2.0), n = 3
// out: <0> <7>
// out: dot circle(0.5)
// out: bits 0x3ff0000000000000
// out: {x: 0, y: 0} {x: 1, y: 2}
// out: {x: 1, y: 2}
// out: {x: 1, y: 2} (1.5, -2.0)
// out: <1>
// c: println(({ __auto_type _kv_sv = (p); _kv_show_point(&(kv_out){.fp = NULL}, &_kv_sv, -1); (const uint8_t *)""; }));
