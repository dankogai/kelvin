// x.hex of a floating-point number has the sign of its value, and its
// exponent has its sign too, +0x1.8p+1 and -0x1.8p-2; an exponent of 0
// has none, +0x1p0, where it was p+0, C's %a (#603). So of an f64, an
// f32, a BigFloat, and the parts of a c64, a c32 and a CBF. Each text
// reads back as the number, written as a literal too, and so does the
// old one, p+0. SION's text of a number is made of it
#import <BigNum>
#import <SION>
let main():int32 {
    let one:f64 = 1.0
    let small:f32 = 0.375
    println(one.hex, " ", 1.5.hex, " ", 3.0.hex, " ", (-0.375).hex, " ", 0.0.hex, " ", (-0.0).hex, " ", 1024.0.hex)
    println(small.hex, " ", (1.0:f32).hex, " ", f64.infinity.hex, " ", (-f64.infinity).hex, " ", f64.nan.hex)
    println(BigFloat(1).hex, " ", BigFloat(3).hex, " ", BigFloat(-1024).hex, " ", BigFloat("0.375").hex, " ", BigFloat(0).hex, " ", BigFloat.infinity.hex)
    println(c64(1.5, -2.0).hex, " ", c32(1.0:f32, 0.5:f32).hex, " ", CBF(c64(1.0, -0.5)).hex)
    println(f64(one.hex) == one, " ", f64("+0x1p+0") == one, " ", +0x1p0 == one, " ", 0x1.8p0 == 1.5, " ", BigFloat("+0x1p0") == BigFloat(1), " ", BigFloat(BigFloat(1).hex) == BigFloat(1))
    println(c64(c64(1.5, -2.0).hex) == c64(1.5, -2.0), " ", (+0x1.8p0-0x1p+1.i) == c64(1.5, -2.0), " ", c64("(+0x1.8p+0-0x1p+1.i)") == c64(1.5, -2.0))
    let s = SION.number(1.0)
    let t = SION.number(-2.5)
    println(SION.stringify(&s), " ", SION.stringify(&t))
    return 0
}
// out: +0x1p0 +0x1.8p0 +0x1.8p+1 -0x1.8p-2 +0x0p0 -0x0p0 +0x1p+10
// out: +0x1.8p-2 +0x1p0 +inf -inf nan
// out: +0x1p0 +0x1.8p+1 -0x1p+10 +0x1.8p-2 +0x0p0 +inf
// out: (+0x1.8p0-0x1p+1.i) (+0x1p0+0x1p-1.i) (+0x1p0-0x1p-1.i)
// out: true true true true true true
// out: true true true
// out: 0x1p0 -0x1.4p+1
