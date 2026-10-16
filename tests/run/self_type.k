// Self is the receiver's type (#140), as Swift's: in extend T { } and in
// a method, an attribute, a subscript or a function of T written alone;
// in types, as T itself, Self.f(), Self.x, Self(v), (Self){...}
struct point { x: int64; y: int64 }
extend point {
    static let origin():Self { return {0, 0} }
    static let of(x:int64, y:int64):Self { return {x, y} }
    static let unit:Self = {1, 1}                        // a type attribute
    let moved(dx:int64):Self {
        var p:Self = self                                 // a declaration
        p.x += dx
        return p
    }
    let plus(o:Self):Self { Self.of(.x + o.x, .y + o.y) } // a parameter, a function of the type
    let twice:Self { .plus(self) }                        // an attribute
    let swapped():Self { (Self){.y, .x} }                 // a compound literal
    let wide():bool { sizeof(Self) > 8 }                  // sizeof
    static let +(a:Self, b:Self):Self { a.plus(b) }       // an operator
    let [](i:int64):int64 { i == 0 ? .x : .y }
    var first:int64 {
        get { .x }
        set(v) { .x = v; let u:Self = Self.unit; .y = u.y }
    }
}
let point.tripled():Self { self.plus(self).plus(self) }  // alone
static let point.farthest(ps:Array<Self>^):Self {
    var best = Self.origin()
    for p in ps^ { if p[0] > best[0] { best = p } }
    return best
}
let point.sum():int64                                       // a prototype
let point.sum():int64 { .x + .y }
extend float64 {
    let doubled:Self { self * 2.0 }                       // a built-in type
    let plus2:Self { self + Self(2) }                     // its converter
}
enum { nothing; just: int64 }
extend enum{nothing, just: int64} {
    let orZero():int64 { let s:Self = self; return s.is(just) ? s.just : 0 }   // a type with no tag: a type only
}
let main():int32 {
    let o = point.origin()
    var p = point.of(3, 4)
    println(o, " ", p, " ", point.unit, " ", p.moved(1), " ", p.plus(o))
    println(p.twice, " ", p.swapped(), " ", p.wide(), " ", p + p, " ", p[1], " ", p.sum())
    p.first = 9
    var ps = $[point.of(1, 2), point.of(7, 0)]
    println(p, " ", p.tripled(), " ", point.farthest(&ps), " ", 1.5.doubled, " ", 1.5.plus2)
    let m = just(3)
    var n = nothing
    println(m.orZero(), " ", n.orZero())
    return 0
}
// out: {x: 0, y: 0} {x: 3, y: 4} {x: 1, y: 1} {x: 4, y: 4} {x: 3, y: 4}
// out: {x: 6, y: 8} {x: 4, y: 3} true {x: 6, y: 8} 4 7
// out: {x: 9, y: 1} {x: 27, y: 3} {x: 7, y: 0} 3.0 3.5
// out: 3 0
// c: struct point point__moved(const struct point self, const int64_t dx)
