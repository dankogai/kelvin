// modules/math.k (#148): the functions of math.h for f64 and f32, their
// constants as attributes of the type, each function as a method, the
// tests isnan, isinf and isfinite, and x.i, x rotated a quarter turn
#import <math>
let main():i32 {
    println(f64.pi, " ", f64.tau == 2.0 * f64.pi, " ", f64.e, " ", f64.ln2.exp() == 2.0, " ", f64.sqrt2 * f64.sqrt2 - 2.0 < 1e-15)
    println(f32.pi, " ", f32.e, " ", f32.epsilon < f64.epsilon, " ", f32.max < f64.max, " ", f64.min > 0.0)
    println(f64.nan.isnan, " ", f64.infinity.isinf, " ", (-f64.infinity).isinf, " ", 1.0.isfinite, " ", f64.nan.isfinite, " ", f32.infinity.isinf)
    println(2.0.sqrt(), " ", 4.0.sqrt() == sqrt(4.0), " ", 8.0.cbrt(), " ", 3.7.floor(), " ", 3.2.ceil(), " ", 2.5.round(), " ", (-2.5).trunc())
    println(2.0.pow(10.0), " ", 7.0.fmod(3.0), " ", 3.0.hypot(4.0), " ", 1.0.atan2(1.0) == f64.pi / 4.0, " ", 1.0.fmin(2.0), " ", 1.0.fmax(2.0), " ", 2.0.fma(3.0, 1.0))
    println(abs(-2.5), " ", (-2.5).abs(), " ", abs(-2.5:f32), " ", (-2.5:f32).abs(), " ", abs(-2.5).typename, " ", abs(-2.5:f32).typename)
    let x:float32 = 0.5
    println(sin(x) == x.sin(), " ", sin(x).typename, " ", x.exp().typename, " ", sin(0.5).typename, " ", exp(1.0:f32) == f32.e, " ", x.pow(2.0:f32))
    println(0.0.sin(), " ", 1.0.log(), " ", 0.0.exp(), " ", 8.0.log2(), " ", 100.0.log10(), " ", 0.0.erf())
    println(1.0.tgamma(), " ", (-1.0).copysign(1.0), " ", abs(-3), " ", abs(-3:i64), " ", abs(-3).typename, " ", abs(-3:i64).typename)
    println(1.0.i, " ", (0.5:f32).i, " ", 1.0.i.i, " ", 1.0.i.i.i.i, " ", (-1.0).i)
    return 0
}
// out: 3.141592653589793 true 2.718281828459045 true true
// out: 3.1415927 2.7182817 false true true
// out: true true true true false true
// out: 1.4142135623730951 true 2.0 3.0 4.0 3.0 -2.0
// out: 1024.0 1.0 5.0 true 1.0 2.0 7.0
// out: 2.5 2.5 2.5 2.5 f64 f32
// out: true f32 f32 f64 true 0.25
// out: 0.0 0.0 1.0 3.0 2.0 0.0
// out: 1.0 1.0 3 3 i64 i64
// out: {real: 0, imag: 1} {real: 0, imag: 0.5} {real: -1, imag: 0} {real: 1, imag: 0} {real: 0, imag: -1}
