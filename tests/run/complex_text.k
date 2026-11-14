// z.hex and z.dec of a c64 or a c32 (#559): its parts' texts and .i, in
// parentheses, (+0x1.8p+0-0x1p+1.i); each part's own sign joins them,
// so the text pastes back as the number. Of a cbr, with <Rational>,
// z.hex, z.oct and z.bin: its parts are bigrats, each in its own
// parentheses, with a + between
#import <math>
#import <Rational>
let main():int32 {
    let z = c64(1.5, -2.0)
    println(z.hex, " ", z.dec, " ", z.conj().hex, " ", z.conj().dec, " ", z.hex.typename)
    // as its parts': every digit, a zero's sign, and a + before a nan, which has none
    println(c64(0.1, 1e22).dec, " ", c64(-0.0, 0.0).hex, " ", c64(0.0, -0.0).dec, " ", (z * z).dec)
    let zero = 0.0
    println(c64(zero / zero, zero / zero).hex, " ", c64(1.0 / zero, -1.0 / zero).dec, " ", c64(1.0, zero / zero).dec)
    // a c32's parts are f32s
    let w:c32 = c32(0.1:f32, -2.0:f32)
    println(w.hex, " ", w.dec, " ", 1.0.i.hex, " ", (2.0:f32).i.dec, " ", w.dec.typename)
    // it pastes back: +a-b.i is a less b.i, a c64
    println((+0x1.8p+0-0x1p+1.i) == z, " ", (+1.5-2.0.i) == z, " ", (+0x1.8p+0+0x1p+1.i) == z.conj(), " ", (+0.10000000000000001+1e+22.i) == c64(0.1, 1e22))
    println((+1.5-2.0.i), " ", (+1.5-2.0.i).typename, " ", (+0.0-0.0.i), " ", (-0x0p+0-0x0p+0.i))
    // a String, as a bigrat's: in a template, and kept
    let s:String = z.hex
    println(`${z.dec}!`, " ", s.count, " ", s, " ", z.hex == s)
    // a cbr: (real.hex+imag.hex.i), and base 8 and base 2
    let b = cbr(1n.over(2n), -1n.over(3n))
    println(b.hex, " ", b.oct, " ", b.bin, " ", b.hex.typename)
    println(cbr(255, 16).hex, " ", cbr(3, -4).i.bin, " ", (b / 0).oct, " ", 1n.over(7n).i.hex)
    return 0
}
// out: (+0x1.8p+0-0x1p+1.i) (+1.5-2.0.i) (+0x1.8p+0+0x1p+1.i) (+1.5+2.0.i) String
// out: (+0.10000000000000001+1e+22.i) (-0x0p+0+0x0p+0.i) (+0.0-0.0.i) (-1.75-6.0.i)
// out: (nan+nan.i) (+inf-inf.i) (+1.0+nan.i)
// out: (+0x1.99999ap-4-0x1p+1.i) (+0.100000001-2.0.i) (+0x0p+0+0x1p+0.i) (+0.0+2.0.i) String
// out: true true true true
// out: {real: 1.5, imag: -2.0} c64 {real: 0.0, imag: -0.0} {real: -0.0, imag: -0.0}
// out: (+1.5-2.0.i)! 20 (+0x1.8p+0-0x1p+1.i) true
// out: ((+0x1n/+0x2n)+(-0x1n/+0x3n).i) ((+0o1n/+0o2n)+(-0o1n/+0o3n).i) ((+0b1n/+0b10n)+(-0b1n/+0b11n).i) String
// out: ((+0xffn/+0x1n)+(+0x10n/+0x1n).i) ((+0b100n/+0b1n)+(+0b11n/+0b1n).i) ((+0o1n/+0o0n)+(-0o1n/+0o0n).i) ((+0x0n/+0x1n)+(+0x1n/+0x7n).i)
