// x.isInfinite and x.isFinite of a floating-point number (#384), Swift's,
// beside x.isNaN (#382): +inf and -inf are infinite, and neither they nor
// NaN finite
let main():int32 {
    let x:float64 = -2.5
    let f:float32 = 3.0
    let big:float64 = 1e308
    println(inf.isInfinite, " ", (-inf).isInfinite, " ", x.isInfinite, " ", nan.isInfinite, " ", (big * 10.0).isInfinite, " ", f.isInfinite)
    println(x.isFinite, " ", f.isFinite, " ", inf.isFinite, " ", nan.isFinite, " ", 0.0.isFinite, " ", (1.0 / 0.0).isFinite)
    if !x.isInfinite && x.isFinite { println("finite") }
    var g:float32 = 1.0
    g.exponent = 255
    println(g.isInfinite, " ", g.isFinite, " ", g.isNaN)
    return 0
}
// out: true true false false true false
// out: true true false false true false
// out: finite
// out: true false false
