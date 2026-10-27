// methods of a type nested in a struct (#389), `let shape.size.area()`,
// `static let`, `extend shape.kind { }`; in the methods of shape, and of
// its nested types, the nested ones by their bare names
struct shape {
    enum kind { round; sides: i64 }
    struct size { w:f64, h:f64 }
    k:kind
    s:size
}
let shape.size.area():f64 { return .w * .h }
static let shape.size.unit():shape.size { return {1.0, 1.0} }
let shape.scaled(by:f64):size {
    let z:size = {.s.w * by, .s.h * by}
    return z
}
let shape.isRound():bool { return .k.is(round) }
static let shape.make():shape { return {kind.sides(3), size.unit()} }
extend shape.kind {
    let corners():i64 {
        switch self {
        case round: return 0
        case sides: return self.sides
        }
    }
}
let main():i32 {
    let a = shape.make()
    println(a, " ", a.s.area(), " ", a.scaled(2.0), " ", a.isRound(), " ", a.k.corners())
    println(shape.size.unit(), " ", shape.kind.round.corners())
    return 0
}
// out: {k: sides(3), s: {w: 1.0, h: 1.0}} 1.0 {w: 2.0, h: 2.0} false 3
// out: {w: 1.0, h: 1.0} 0
// c: double shape__size__area(const struct shape__size self)
