// the constants of a floating-point type (#546), Swift's FloatingPoint's,
// with no import: radix, an i64, and nan, signalingNaN, infinity,
// greatestFiniteMagnitude, pi, ulpOfOne, leastNormalMagnitude and
// leastNonzeroMagnitude, each of its type, a constant; <math>'s own
// f64.pi, f64.infinity and f64.nan are the same values. A subnormal's
// .hex is C's %a, which glibc and macOS write differently, 0x0.0000000000001p-1022
// and 0x1p-1074, so the least number above 0 is compared, not shown
#import <math>
let big:f64 = f64.greatestFiniteMagnitude
let none = f32.nan
static_assert(f64.radix == 2, "radix")
static_assert(f64.ulpOfOne > 0.0 && f64.infinity > f64.greatestFiniteMagnitude, "constants")
let main():int32 {
    println(f64.radix, " ", f64.nan, " ", f64.signalingNaN, " ", f64.infinity, " ", -f64.infinity, " ", f64.pi)
    println(f64.greatestFiniteMagnitude, " ", f64.ulpOfOne, " ", f64.leastNormalMagnitude, " ", f64.leastNonzeroMagnitude)
    println(f32.radix, " ", f32.nan, " ", f32.signalingNaN, " ", f32.infinity, " ", f32.pi)
    println(f32.greatestFiniteMagnitude, " ", f32.ulpOfOne, " ", f32.leastNormalMagnitude, " ", f32.leastNonzeroMagnitude)
    println(f64.pi.typename, " ", f32.pi.typename, " ", f64.radix.typename, " ", float64.infinity.isInfinite, " ", f64.nan.isNaN, " ", f64.signalingNaN.isNaN)
    println(f64.leastNonzeroMagnitude == 0x1p-1074, " ", f64.leastNormalMagnitude.hex, " ", f64.greatestFiniteMagnitude.hex, " ", f32.leastNonzeroMagnitude == (0x1p-149 as f32))
    println((f64.ulpOfOne * 2.0), " ", 1.0 + f64.ulpOfOne > 1.0, " ", 1.0 + f64.ulpOfOne / 2.0 > 1.0, " ", f64.leastNonzeroMagnitude / 2.0, " ", big, " ", none)
    let x = f32.ulpOfOne
    println(x.typename, " ", f64.greatestFiniteMagnitude * 2.0, " ", f64.nan == f64.nan)
    println(f64.greatestFiniteMagnitude == f64.max, " ", f64.leastNormalMagnitude == f64.min, " ", f64.ulpOfOne == f64.epsilon, " ", f32.greatestFiniteMagnitude == f32.max)
    return 0
}
// out: 2 nan nan inf -inf 3.1415926535897931
// out: 1.7976931348623157e+308 2.2204460492503131e-16 2.2250738585072014e-308 4.9406564584124654e-324
// out: 2 nan nan inf 3.14159274
// out: 3.40282347e+38 1.1920929e-07 1.17549435e-38 1.40129846e-45
// out: f64 f32 i64 true true true
// out: true +0x1p-1022 +0x1.fffffffffffffp+1023 true
// out: 4.4408920985006262e-16 true false 0.0 1.7976931348623157e+308 nan
// out: f32 inf false
// out: true true true true
