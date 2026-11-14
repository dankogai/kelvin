// x.dec of a float is the text print shows, every digit with a point,
// after its sign (#558): +2.0, where C's %+.17g wrote +2, which pastes
// back as an integer; the plain range and the exponents are print's
// (#259), and a NaN has no sign
let main():int32 {
    let f:f32 = 0.1
    let g:f32 = 3.0
    // a whole number keeps its point, and a zero its sign
    println(2.0.dec, " ", (-2.0).dec, " ", 0.0.dec, " ", (-0.0).dec, " ", 123456.0.dec, " ", g.dec)
    // every digit the type holds, as before
    println(1.5.dec, " ", 0.1.dec, " ", f.dec, " ", 3.141592653589793.dec)
    // plain decimal from 0.0001 up to 2^53, and 2^24 of an f32
    println(0.0001.dec, " ", 9007199254740992.0.dec, " ", (16777216.0:f32).dec)
    println(1e22.dec, " ", 1e-5.dec, " ", 1e16.dec, " ", (1e10:f32).dec, " ", (-5e-324).dec)
    let zero = 0.0
    println((zero / zero).dec, " ", (1.0 / zero).dec, " ", (-1.0 / zero).dec)
    // it pastes back as the float: + is unary
    println(+2.0, " ", (+2.0).typename, " ", -0.0, " ", +1e+22 == 1e22, " ", +0.10000000000000001 == 0.1)
    // and float64 reads it back, as it reads x.hex
    println(float64(2.0.dec), " ", float64((-0.0).dec), " ", float64(0.1.dec) == 0.1, " ", float64(1e22.dec) == 1e22)
    // in a template, and an integer's is as it was
    println(`${2.0.dec}|${g.dec}|${3.dec}`, " ", 2.0.dec.typename)
    return 0
}
// out: +2.0 -2.0 +0.0 -0.0 +123456.0 +3.0
// out: +1.5 +0.10000000000000001 +0.100000001 +3.1415926535897931
// out: +0.0001 +9007199254740992.0 +16777216.0
// out: +1e+22 +1.0000000000000001e-05 +1e+16 +1e+10 -4.9406564584124654e-324
// out: nan +inf -inf
// out: 2.0 f64 -0.0 true true
// out: 2.0 -0.0 true true
// out: +2.0|+3.0|+3 cstr
