// a complex number of its text (#569): c64(text), c32(text) and
// CBR(text) read what the type writes, so T(text) gives the value back:
// z.dec's and z.hex's (a+b.i), print's too (#570), and a struct's text of
// the parts, {real: a, imag: b}, which print wrote before;
// a part alone is read too, and text that is none is a NaN in both parts
#import <BigNum>
let main():int32 {
    // each text of a c64 gives it back
    let z = c64(1.5, -2.0)
    println(c64(z.dec) == z, " ", c64(z.hex) == z, " ", c64(z.cstr) == z, " ", c64("(+1.5-2.0.i)"), " ", c64("(+0x1.8p+0-0x1p+1.i)"))
    println(c64("{real: 1.5, imag: -2.0}"), " ", c64("1.5-2.0.i"), " ", c64(" ( 1.5-2.i ) "), " ", c64(" { real : 1.5 , imag : -2.0 } "))
    // spaces may be about the sign that joins the parts, as c64("1.5 ") + c64("2.0.i\t") is read
    println(c64("1.5 -2.0.i"), " ", c64("1.5 - 2.0.i"), " ", c64("1.5- 2.0.i"), " ", c64("( 1.5\t+\t2.0.i )"), " ", c64("1.5 ") + c64("2.0.i\t"), " ", c64("1 - 0.0.i").dec)
    println(c64("1.5 - -2.0.i"), " ", c64("1.5 -"), " ", c64("1.5 - 2.0"), " ", c64("1.5 .i"), " ", c32("0.5 - 2.0.i"))
    // a part alone: the other is 0
    println(c64("1.5"), " ", c64("2.0.i"), " ", c64("-2.i"), " ", c64("(1.5)"), " ", c64("(-2.0.i)"), " ", c64("1e3"), " ", c64("0x1p+1.i"))
    // the sign of a zero is read, in each form
    println(c64("-0.0"), " ", c64("-0.0.i"), " ", c64("(-0.0-0.0.i)"), " ", c64("{real: -0.0, imag: 0.0}"), " ", c64("(-0x0p+0+0x0p+0.i)"))
    let nz = c64(-0.0, -0.0)
    println(c64(nz.dec), " ", c64(nz.hex), " ", c64(nz.cstr), " ", c64(nz.dec).dec, " ", c64(c64(0.0, -0.0).cstr).dec)
    // an infinity and a NaN, as a float's text has them
    println(c64("(nan+nan.i)"), " ", c64("(+inf-inf.i)"), " ", c64("{real: inf, imag: nan}"), " ", c64("-inf"), " ", c64("Infinity.i"))
    // text that is no complex number is an error, a NaN in both parts
    println(c64("abc"), " ", c64(""), " ", c64("1.5+2.0"), " ", c64("1.5x"), " ", c64("(1.5"), " ", c64("1.5)"), " ", c64("i"), " ", c64("1.5i"))
    println(c64("1.5 2.0.i"), " ", c64("1.5-2.0.i.i"), " ", c64("{real: 1.5}"), " ", c64("{imag: 2.0, real: 1.5}"), " ", c64("abc").real.isnan, " ", c64("abc").imag.isnan)
    // a c32, of f32 parts
    let w:c32 = c32(0.1:f32, -2.0:f32)
    println(c32(w.dec) == w, " ", c32(w.hex) == w, " ", c32(w.cstr) == w, " ", c32("0.1"), " ", c32("(+0.1-2.0.i)"), " ", c32("x"), " ", c32("0.1").typename)
    // of a String by reference
    let s = z.dec
    let h = z.hex
    println(c64(&s), " ", c64(&h), " ", c32(&s), " ", c64(&s) == z)
    // a CBR: its .hex, .oct and .bin with their base, what print writes, and a struct's text of the parts
    let q = CBR(1n.over(2n), (-1n).over(3n))
    println(CBR(q.hex, 16) == q, " ", CBR(q.oct, 8) == q, " ", CBR(q.bin, 2) == q, " ", CBR(q.cstr) == q, " ", CBR(q.hex, 16))
    println(CBR("((1n/2n)+(-1n/3n).i)"), " ", CBR("{real: (1n/2n), imag: (-1n/3n)}"), " ", CBR("(1/2)-(1/3).i"), " ", CBR("1/2-1/3.i"))
    // a part is a BigRat's text, read exactly; a part alone, and parentheses about the whole or about none
    println(CBR("(1.5+2.5.i)"), " ", CBR("0.1"), " ", CBR("1e2+1e-2.i"), " ", CBR("ff+0x10.i", 16))
    println(CBR("(1/2)"), " ", CBR("((1/2))"), " ", CBR("3"), " ", CBR("2.i"), " ", CBR("(1/3).i"), " ", CBR("-(1/3).i"))
    // spaces about the sign that joins the parts
    println(CBR("1 +2.i"), " ", CBR("(1/2) - (1/3).i") == q, " ", CBR("1/2 - 1/3.i") == q, " ", CBR("( 1 / 2 + 3.i )"), " ", CBR("1 - -2.i"), " ", CBR("(1/2) + -(1/3).i"))
    // an infinity and a NaN of a part, and text that is no CBR
    println(CBR("(1/0)+(0/0).i"), " ", CBR("abc"), " ", CBR(""), " ", CBR("1+2"), " ", CBR("1x"))
    println(CBR("((1/2)"), " ", CBR("(1/2))"), " ", CBR("1 2.i"), " ", CBR("1", 99), " ", CBR("abc").real.isNaN, " ", CBR("abc").imag.isNaN)
    let t = q.hex
    println(CBR(&t, 16), " ", CBR(&t), " ", CBR("3").typename)
    // the constructors of numbers are as they were
    println(c64(1.5), " ", c64(1.5, 2.0), " ", c32(z), " ", CBR(3), " ", CBR(1, 2), " ", CBR(1n.over(2n)))
    return 0
}
// out: true true true (1.5-2.0.i) (1.5-2.0.i)
// out: (1.5-2.0.i) (1.5-2.0.i) (1.5-2.0.i) (1.5-2.0.i)
// out: (1.5-2.0.i) (1.5-2.0.i) (1.5-2.0.i) (1.5+2.0.i) (1.5+2.0.i) (+1.0-0.0.i)
// out: (nan+nan.i) (nan+nan.i) (nan+nan.i) (nan+nan.i) (0.5-2.0.i)
// out: (1.5+0.0.i) (0.0+2.0.i) (0.0-2.0.i) (1.5+0.0.i) (0.0-2.0.i) (1000.0+0.0.i) (0.0+2.0.i)
// out: (-0.0+0.0.i) (0.0-0.0.i) (-0.0-0.0.i) (-0.0+0.0.i) (-0.0+0.0.i)
// out: (-0.0-0.0.i) (-0.0-0.0.i) (-0.0-0.0.i) (-0.0-0.0.i) (+0.0-0.0.i)
// out: (nan+nan.i) (inf-inf.i) (inf+nan.i) (-inf+0.0.i) (0.0+inf.i)
// out: (nan+nan.i) (nan+nan.i) (nan+nan.i) (nan+nan.i) (nan+nan.i) (nan+nan.i) (nan+nan.i) (nan+nan.i)
// out: (nan+nan.i) (nan+nan.i) (nan+nan.i) (nan+nan.i) true true
// out: true true true (0.100000001+0.0.i) (0.100000001-2.0.i) (nan+nan.i) c32
// out: (1.5-2.0.i) (1.5-2.0.i) (1.5-2.0.i) true
// out: true true true true ((1n/2n)+(-1n/3n).i)
// out: ((1n/2n)+(-1n/3n).i) ((1n/2n)+(-1n/3n).i) ((1n/2n)+(-1n/3n).i) ((1n/2n)+(-1n/3n).i)
// out: ((3n/2n)+(5n/2n).i) ((1n/10n)+(0n/1n).i) ((100n/1n)+(1n/100n).i) ((255n/1n)+(16n/1n).i)
// out: ((1n/2n)+(0n/1n).i) ((1n/2n)+(0n/1n).i) ((3n/1n)+(0n/1n).i) ((0n/1n)+(2n/1n).i) ((0n/1n)+(1n/3n).i) ((0n/1n)+(-1n/3n).i)
// out: ((1n/1n)+(2n/1n).i) true true ((1n/2n)+(3n/1n).i) ((0n/0n)+(0n/0n).i) ((0n/0n)+(0n/0n).i)
// out: ((1n/0n)+(0n/0n).i) ((0n/0n)+(0n/0n).i) ((0n/0n)+(0n/0n).i) ((0n/0n)+(0n/0n).i) ((0n/0n)+(0n/0n).i)
// out: ((0n/0n)+(0n/0n).i) ((0n/0n)+(0n/0n).i) ((0n/0n)+(0n/0n).i) ((0n/0n)+(0n/0n).i) true true
// out: ((1n/2n)+(-1n/3n).i) ((0n/0n)+(0n/0n).i) CBR
// out: (1.5+0.0.i) (1.5+2.0.i) (1.5-2.0.i) ((3n/1n)+(0n/1n).i) ((1n/1n)+(2n/1n).i) ((1n/2n)+(0n/1n).i)
