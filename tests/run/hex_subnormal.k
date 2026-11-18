// x.hex of a floating-point number is Kelvin's own text (#607), where it
// was the C library's %a: a subnormal is written as any other number, by
// its first 1 and that 1's power of 2, +0x1p-1074, as a BigFloat's is,
// on every system, where glibc's %a writes 0x0.0000000000001p-1022 and
// macOS's 0x1p-1074. Each text reads back as the number
#import <BigNum>
let main():int32 {
    let least:f64 = 5e-324
    let most:f64 = f64(1, -1074, 4503599627370495)       // the greatest subnormal, 2^52 - 1 of the least
    let mid:f64 = f64(-1, -1051, 3)
    let normal:f64 = 2.2250738585072014e-308             // the least that is not one
    println(least.hex, " ", most.hex, " ", mid.hex, " ", normal.hex)
    println(f64(least.hex) == least, " ", f64(most.hex) == most, " ", f64(mid.hex) == mid, " ", f64("0x0.0000000000001p-1022") == least)
    println(BigFloat(least).hex == least.hex, " ", BigFloat(most).hex == most.hex, " ", BigFloat(mid).hex == mid.hex)
    println(1.7976931348623157e308.hex, " ", 0.1.hex, " ", (0.1:f32).hex, " ", f32(1, -149, 1).hex, " ", (-0.0).hex)
    return 0
}
// out: +0x1p-1074 +0x1.ffffffffffffep-1023 -0x1.8p-1050 +0x1p-1022
// out: true true true true
// out: true true true
// out: +0x1.fffffffffffffp+1023 +0x1.999999999999ap-4 +0x1.99999ap-4 +0x1p-149 -0x0p0
