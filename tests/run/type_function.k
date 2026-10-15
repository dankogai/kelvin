// a function of a type (#111): static let T.name(params):R { }, Swift's
// static func, with no self, called as T.name(...); T a struct, union or
// enum with values of the program; the overloads of one name by their
// parameter types, as any function's; one may call another
struct point { x: i64; y: i64 }
static let point.origin():Self { (Self){0, 0} }
static let point.of(x:i64, y:i64):Self { (Self){x, y} }
static let point.of(s:cstr):Self { Self.of(i64(s), i64(s) * 2) }
static let point.sum(a:Self^, b:Self^):Self { Self.of(a^.x + b^.x, a^.y + b^.y) }
let point.dist2():i64 { .x * .x + .y * .y }      // a method, with self, beside them
enum shape { none; dot: point; name: String }
static let shape.parse(s:cstr):Self {
    if s.count == 0 { return shape.none }
    if s[0] >= '0' && s[0] <= '9' { return shape.dot(point.of(s)) }
    return shape.name(String(s))
}
let main():i32 {
    let o = point.origin()
    var p = point.of(3, 4)
    var q = point.of("5")
    let r = point.sum(&p, &q)
    println(o.cstr, " ", p.cstr, " ", q.cstr, " ", r.cstr, " ", p.dist2())
    var a = shape.parse("")
    var b = shape.parse("7")
    var c = shape.parse("seven")
    println(a.cstr, " ", b.cstr, " ", c.cstr)
    return 0
}
// out: {x: 0, y: 0} {x: 3, y: 4} {x: 5, y: 10} {x: 8, y: 14} 25
// out: none dot({x: 7, y: 14}) name("seven")
// c: point__origin()
// c: point__of__i64__i64(3, 4)
// c: point__of__cstr("5")
