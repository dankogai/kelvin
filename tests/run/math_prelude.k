// math is the prelude's (#591): a program that names one of its names
// has it with no import, as it has RegExp and BigInt: the functions of
// math.h for f64 and f32, each a method too, the constants of each type,
// and c64 and c32, complex64 and complex32 by their aliases. The names are
// read from the module itself, wherever the program writes one; what it
// gives f64 and f32 is named after a dot, f64.tau, x.isnan, 1.0.i. A
// program's own function of one of the names, of other types, stands
// beside math's
let log(what:cstr) { println("log: ", what) }
struct vec { x: f64; y: f64 }
let abs(v:vec):f64 { hypot(v.x, v.y) }
let main():int32 {
    // the functions, of an f64 and of an f32
    println(sqrt(2.0), " ", sin(0.5), " ", pow(2.0, 0.5), " ", atan2(1.0, 1.0) * 4.0, " ", floor(2.5), " ", sin(0.5:f32), " ", sqrt(2.0:f32).typename)
    // abs is Kelvin's, of a float and of an i64, where it was C's of an int
    println(abs(-2.5), " ", abs(-3), " ", abs(-3).typename, " ", abs(-9000000000), " ", abs((vec){3.0, 4.0}))
    // each a method, and the constants of a type
    println(2.0.sqrt(), " ", 0.5.sin(), " ", 2.0.pow(10.0), " ", f64.tau, " ", f64.e, " ", f32.epsilon, " ", f64.max > 1e308)
    println((0.0 / 0.0).isnan, " ", (1.0 / 0.0).isinf, " ", 1.5.isfinite)
    // c64 and c32, with their operators, functions and text
    let i = 1.0.i
    let z = c64(1.0, 2.0)
    println(i, " ", z * z, " ", z / i, " ", abs(c64(3.0, 4.0)), " ", conj(z), " ", z.real, " ", z.imag, " ", polar(2.0, 0.0))
    println(abs(exp(i * f64.pi) + 1.0) < 1e-15, " ", sqrt(c64(-4.0, 0.0)), " ", z.exp() == exp(z), " ", c64("(1.5-2.0.i)"), " ", z.hex)
    let w:complex64 = complex64(3.0, 4.0)
    let v:complex32 = c32(1.0, 1.0)
    println(w.typename, " ", norm(w), " ", v * v, " ", v.typename)
    // the program's own log, beside math's
    log("done")
    println(log(f64.e))
    return 0
}
// out: 1.4142135623730951 0.47942553860420301 1.4142135623730951 3.1415926535897931 2.0 0.47942555 f32
// out: 2.5 3 i64 9000000000 5.0
// out: 1.4142135623730951 0.47942553860420301 1024.0 6.2831853071795862 2.7182818284590451 1.1920929e-07 true
// out: true true true
// out: (0.0+1.0.i) (-3.0+4.0.i) (2.0-1.0.i) 5.0 (1.0-2.0.i) 1.0 2.0 (2.0+0.0.i)
// out: true (0.0+2.0.i) true (1.5-2.0.i) (+0x1p+0+0x1p+1.i)
// out: c64 25.0 (0.0+2.0.i) c32
// out: log: done
// out: 1.0
