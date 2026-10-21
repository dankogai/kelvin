// the complex functions of modules/math.k as methods (#148), z.exp(),
// z.abs(), z.pow(w), and z.i, z times i
#import <math>
let main():int32 {
    let z = c64(1.0, 2.0)
    let i = c64(0.0, 1.0)
    println(z.conj(), " ", z.abs() * z.abs() - z.norm() < 1e-12, " ", z.arg() == arg(z), " ", z.i, " ", z.i == z * i, " ", i.i)
    println(z.exp() == exp(z), " ", z.log() == log(z), " ", z.sqrt() == sqrt(z), " ", z.pow(c64(2.0)) == pow(z, c64(2.0)))
    println(z.sin() == sin(z), " ", z.cos() == cos(z), " ", z.tan() == tan(z), " ", z.sinh() == sinh(z), " ", z.cosh() == cosh(z), " ", z.tanh() == tanh(z))
    println(z.asin() == asin(z), " ", z.acos() == acos(z), " ", z.atan() == atan(z), " ", z.asinh() == asinh(z), " ", z.acosh() == acosh(z), " ", z.atanh() == atanh(z))
    let w = c32(1.0:float32, 2.0:float32)
    println(w.exp() == exp(w), " ", w.abs() == abs(w), " ", w.i, " ", w.norm().typename, " ", abs(w.sqrt() * w.sqrt() - w) < 1e-6:float32)
    return 0
}
// out: {real: 1.0, imag: -2.0} true true {real: -2.0, imag: 1.0} true {real: -1.0, imag: 0.0}
// out: true true true true
// out: true true true true true true
// out: true true true true true true
// out: true true {real: -2.0, imag: 1.0} f32 true
