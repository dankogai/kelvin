// an enum with values prints as its value is written (#529): the case
// after the enum's name, one inside a struct by its path, so that the
// text pastes back; an Optional and a Result keep some(v), ok(v), err(e)
struct shape {
    w: f64
    enum kind { round; sides: i64 }
    k: kind
}
enum num { n: f64; none }
let main():int32 {
    let a = num.n(1.5)
    let b = num.none
    let c = shape.kind.sides(4)
    let s:shape = {2.0, shape.kind.round}
    println(a, " ", b, " ", c, " ", $[a, b], " ", `${c}`, " ", s)
    println(grapheme(0xD800), " ", String.fromCodepoints())
    let pasted = $[num.n(1.5), num.none]                  // the text printed, pasted back
    let e = grapheme(0xD800)
    if let err(why) = e { println(why == CodepointError.surrogate(55296), " ", why) }
    println(pasted[0] == a, " ", pasted[1] == b, " ", shape.kind.sides(4) == c)
    return 0
}
// out: num.n(1.5) num.none shape.kind.sides(4) [num.n(1.5), num.none] shape.kind.sides(4) {w: 2.0, k: shape.kind.round}
// out: err(CodepointError.surrogate(55296)) err(CodepointError.empty)
// out: true CodepointError.surrogate(55296)
// out: true true true
