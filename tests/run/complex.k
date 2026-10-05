// lib/complex.k (#43): complex64 and complex32, their arithmetic and
// elementary functions, which overload C's own of the same names (#41)
// through Kelvin's operators (#42). C's libm may differ in the last bits
// between systems, so results are compared within a tolerance.
#import <lib/complex.k>
#import <math.h> as C
#import <stdlib.h> as C

let PI = 3.141592653589793
var checked:i64 = 0

// got is want, within 1e-12 of want's size
check(what:cstr, got:complex64, want:complex64) {
    checked += 1
    if !(abs(got - want) <= 1e-12 * (1.0 + abs(want))) {
        println(what, ": ", got.cstr, " is not ", want.cstr)
    }
}
check(what:cstr, got:f64, want:f64) { check(what, complex64(got), complex64(want)) }
// a complex32 is within 1e-6
check(what:cstr, got:complex32, want:complex64) {
    checked += 1
    if !(abs(complex64(got) - want) <= 1e-6 * (1.0 + abs(want))) {
        println(what, ": ", got.cstr, " is not ", want.cstr)
    }
}

main():i32 {
    let i:complex64 = complex64(0.0, 1.0)
    let z:complex64 = complex64(1.0, 2.0)
    let w:complex64 = complex64(3.0, -1.0)
    let u:complex64 = complex64(0.5, 0.3)

    // arithmetic, exact for these
    let p:complex64 = z * w
    println((z + w).cstr, " ", (z - w).cstr, " ", p.cstr, " ", (-z).cstr)
    println((z + 1.0).cstr, " ", (2.0 * z).cstr, " ", (z / 2.0).cstr, " ", (1.0 - z).cstr, " ", (i * i).cstr)
    println(z == complex64(1.0, 2.0), " ", z != w, " ", z != complex64(1.0, 3.0), " ", z == complex64(1.0, 3.0), " ", conj(z).cstr, " ", norm(complex64(3.0, 4.0)), " ",
            abs(complex64(3.0, 4.0)))
    check("z / w", z / w, complex64(0.1, 0.7))
    check("z w / w", p / w, z)
    check("1 / i", 1.0 / i, -i)
    check("arg -1", arg(complex64(-1.0)), PI)
    check("polar", polar(2.0, PI / 2.0), 2.0 * i)

    // exponentials and logarithms
    check("Euler", exp(i * PI), complex64(-1.0))
    check("exp", exp(z), exp(1.0) * complex64(cos(2.0), sin(2.0)))
    check("log -1", log(complex64(-1.0)), i * PI)
    check("log exp", log(exp(z)), z)
    check("sqrt -4", sqrt(complex64(-4.0)), 2.0 * i)
    check("sqrt²", sqrt(z) * sqrt(z), z)
    check("2 ^ 10", pow(complex64(2.0), 10.0), complex64(1024.0))
    check("i ^ i", pow(i, i), complex64(exp(-PI / 2.0)))
    check("0 ^ z", pow(complex64(0.0), z), complex64(0.0))
    check("z ^ 0", pow(z, complex64(0.0)), complex64(1.0))
    check("e ^ z", pow(exp(1.0), z), exp(z))

    // trigonometric and hyperbolic functions, and their inverses
    check("sin² + cos²", sin(z) * sin(z) + cos(z) * cos(z), complex64(1.0))
    check("tan", tan(z), sin(z) / cos(z))
    check("sinh", sinh(z), (exp(z) - exp(-z)) / 2.0)
    check("cosh", cosh(z), (exp(z) + exp(-z)) / 2.0)
    check("tanh", tanh(z), sinh(z) / cosh(z))
    check("sin iz", sin(i * z), i * sinh(z))
    check("asin", asin(sin(u)), u)
    check("acos", acos(cos(u)), u)
    check("atan", atan(tan(u)), u)
    check("asinh", asinh(sinh(u)), u)
    check("acosh", acosh(cosh(u)), u)
    check("atanh", atanh(tanh(u)), u)

    // far from 0, near 0, and on the branch cuts, as C's own give them
    check("tanh far", tanh(complex64(400.0, 1.0)), complex64(1.0))
    check("tan far", tan(complex64(1.0, 400.0)), i)
    check("asin far", asin(complex64(1e200, 1e200)), complex64(0.7853981633974483, 461.55673936964905))
    check("atanh far", atanh(complex64(1e200, -1e200)), complex64(0.0, -PI / 2.0))
    check("atanh huge", atanh(complex64(1e308, 1e308)), complex64(0.0, PI / 2.0))
    check("sqrt huge", sqrt(complex64(1e308, 1e308)), complex64(1.09868411346781e154, 4.5508986056222734e153))
    check("sqrt huge -", sqrt(complex64(-1e308, 1e308)), complex64(4.5508986056222734e153, 1.09868411346781e154))
    check("asin 2", asin(complex64(2.0)), complex64(PI / 2.0, 1.3169578969248166))
    check("acosh -2", acosh(complex64(-2.0)), complex64(1.3169578969248166, PI))
    check("atanh near -1", atanh(complex64(-0.9999999999, 1e-10)), complex64(-11.686212239400122, 0.3926990610386323))
    check("atanh 1 + tiny i", atanh(complex64(1.0, 1e-200)), complex64(230.60508288968455, PI / 4.0))
    check("sqrt 0", sqrt(complex64(0.0)), complex64(0.0))
    check("sqrt subnormal", sqrt(complex64(0.0, 5e-324)), complex64(1.5717277847026288e-162, 1.5717277847026285e-162))
    check("0 ^ 0", pow(complex64(0.0), complex64(0.0)), complex64(1.0))
    let wide:complex64 = complex64(1.5e308, 1.5e308)
    check("log wide", log(wide), complex64(709.9482473405542, PI / 4.0))
    check("asin wide", asin(wide), complex64(PI / 4.0, 710.64139452111408))
    check("acos wide", acos(wide), complex64(PI / 4.0, -710.64139452111408))
    check("asinh wide", asinh(wide), complex64(710.64139452111408, PI / 4.0))
    check("acosh wide", acosh(wide), complex64(710.64139452111408, PI / 4.0))
    check("exp 720", complex64(0.0, exp(complex64(720.0, 1e-5)).imag), complex64(0.0, 4.9207009301818045e307))
    println(asin(complex64(1e-20)).real == 1e-20, " ", atanh(complex64(0.0, 1e-20)).imag == 1e-20, " ",
            fabs(log(complex64(1.0, 1e-10)).real - 5e-21) < 1e-35, " ",
            fabs((complex64(1.0, 1.0) / wide).real / 6.6666666666666677e-309 - 1.0) < 1e-12)
    // an infinite part gives what C99 gives, and an infinite power of 0
    let inf:complex64 = sqrt(complex64(INFINITY, 1.0))
    println(isinf(inf.real) != 0 && inf.imag == 0.0, " ", isinf(sqrt(complex64(-INFINITY, -1.0)).imag) != 0, " ",
            isinf(asin(complex64(INFINITY, 1.0)).imag) != 0, " ", isinf(pow(complex64(0.0), -1.0).real) != 0, " ",
            signbit(cosh(complex64(-2.0, 0.0)).imag) != 0, " ", signbit(atan(complex64(1e200, 0.0)).imag) == 0)
    // a real argument too large for cosh gives an infinite part, and no NaN
    let big:complex64 = complex64(1000.0)
    println(exp(big).imag == 0.0, " ", sinh(-big).imag == 0.0, " ", cosh(big).imag == 0.0, " ",
            cos(complex64(0.0, 1000.0)).imag == 0.0, " ", isinf(exp(big).real) != 0)
    println(sqrt(complex64(-4.0, -0.0)).imag, " ", log(complex64(-1.0, -0.0)).imag < 0.0, " ",
            asin(complex64(2.0, -0.0)).imag < 0.0, " ", acos(complex64(2.0, 0.0)).imag < 0.0, " ",
            isinf((z / complex64(0.0)).real) != 0)

    // where e^x alone would overflow, parts that do not; tiny, huge and
    // infinite parts; C's own functions of these names on numbers only C
    // sees, through the prototypes lib/complex.k declares
    let sh:complex64 = sinh(complex64(711.0, 2.0))
    let ch:complex64 = cosh(complex64(-711.0, 2.0))
    let e2:complex64 = exp(complex64(2000.0, 0.0))
    let sech:complex64 = 1.0 / cosh(complex64(800.0, 1.0))
    let byzero:complex64 = complex64(1.0, -2.0) / complex64(0.0)
    println(fabs(sh.real / -1.2635523363859527e308 - 1.0) < 1e-12 && isinf(sh.imag) != 0, " ",
            fabs(ch.real / -1.2635523363859527e308 - 1.0) < 1e-12 && isinf(ch.imag) != 0 && ch.imag < 0.0, " ",
            isinf(e2.real) != 0 && e2.imag == 0.0, " ", sech.real == 0.0 && signbit(sech.imag) != 0, " ",
            isinf(byzero.real) != 0 && byzero.real > 0.0 && isinf(byzero.imag) != 0 && byzero.imag < 0.0)
    check("log tiny", log(complex64(5e-324, 5e-324)), complex64(-744.09349833110127, PI / 4.0))
    println(fabs(acos(complex64(1e301, 1e290)).real / 1e-11 - 1.0) < 1e-12, " ",
            fabs(sqrt(complex64(1e301, 1e-150)).imag / 1.5811388300841897e-301 - 1.0) < 1e-12, " ",
            fabs((complex64(1e-300, 3e20) / complex64(3.0, 1e-320)).real / 6.66662955727561e-301 - 1.0) < 1e-12, " ",
            atanh(complex64(1.0, -1e-200)).imag < 0.0, " ", (z * conj(z)).imag == 0.0 && (complex64(1.1, 2.3) * conj(complex64(1.1, 2.3))).imag == 0.0)
    let s1:complex64 = sqrt(complex64(1.0, INFINITY))
    let s2:complex64 = sqrt(complex64(-0.0, -0.0))
    let s3:complex64 = sqrt(complex64(-INFINITY, -2.0))
    let s4:complex64 = sqrt(complex64(INFINITY, -2.0))
    let s5:complex64 = sqrt(complex64(INFINITY, NAN))
    let s6:complex64 = sqrt(complex64(-INFINITY, NAN))
    println(isinf(s1.real) != 0 && isinf(s1.imag) != 0, " ", s2.real == 0.0 && signbit(s2.imag) != 0, " ",
            s3.real == 0.0 && isinf(s3.imag) != 0 && s3.imag < 0.0, " ", isinf(s4.real) != 0 && signbit(s4.imag) != 0, " ",
            isinf(s5.real) != 0 && isnan(s5.imag) != 0, " ", isnan(s6.real) != 0 && isinf(s6.imag) != 0, " ",
            isnan(pow(complex64(0.0), NAN).real) != 0)
    println(fabs(tanh(atof("0.5")) - 0.46211715726000974) < 1e-15, " ", pow(atof("3"), 2.0), " ", abs(atoi("-5")), " ",
            fabs(atanh(atof("0.5")) - 0.5493061443340549) < 1e-15)

    // the result of a call that C's _Generic chooses is still a complex64
    let x:f64 = 3.0
    let y:f64 = 4.0
    check("polar * 2", polar(hypot(x, y), atan2(y, x)) * 2.0, complex64(6.0, 8.0))
    check("-polar", -polar(hypot(x, y), atan2(y, x)), complex64(-3.0, -4.0))

    // C's own functions of these names take the numbers
    println(sin(0.5).typename, " ", sin(z).typename, " ", sqrt(16.0), " ", fabs(-2.5), " ", sin(0.5) == sin(0.5 as f64))

    // where only C sees a value's type, _Generic chooses
    check("exp(1.0) * i", exp(1.0) * i, complex64(0.0, exp(1.0)))
    check("atan2 + z", atan2(1.0, 1.0) + z, complex64(1.0 + PI / 4.0, 2.0))

    // complex32, through complex64
    let z32:complex32 = complex32(1.0:f32, 2.0:f32)
    let w32:complex32 = complex32(w)
    println((z32 * w32).cstr, " ", (z32 + 1.0:f32).cstr, " ", abs(complex32(3.0:f32, 4.0:f32)), " ",
            abs(z32).typename, " ", complex64(z32) == z, " ", z32 == complex32(z))
    check("exp32", exp(z32), exp(z))
    check("sin32", sin(z32), sin(z))
    check("sqrt32", sqrt(z32), sqrt(z))
    check("pow32", pow(z32, 0.5:f32), sqrt(z))
    check("div32", z32 / w32, z / w)
    check("atanh32", atanh(complex32(u)), atanh(u))
    check("polar32", polar(2.0:f32, PI as f32 / 2.0:f32), complex64(0.0, 2.0))
    check("cos32", cos(z32), complex64(2.0327230070196656, -3.0518977991517997))
    check("log32", log(z32), complex64(0.8047189562170503, 1.1071487177940904))
    check("conj32", conj(z32), conj(z))
    check("real32", complex32(2.5:f32), complex64(2.5))
    check("f32 - z", 1.0:f32 - z32, 1.0 - z)
    check("f32 / z", 1.0:f32 / z32, 1.0 / z)
    check("z / f32", z32 / 2.0:f32, z / 2.0)
    let small:complex32 = complex32(u)
    check("sinh32", sinh(small), complex64(0.4978213596502317, 0.3332362582744821))
    check("cosh32", cosh(small), complex64(1.0772622306471364, 0.15399419236976608))
    check("tanh32", tanh(small), complex64(0.4961970657735076, 0.23840508333812327))
    check("tan32", tan(small), complex64(0.48759231649213874, 0.3689103968255638))
    check("asin32", asin(small), complex64(0.4930392405856184, 0.3342998177749379))
    check("acos32", acos(small), complex64(1.0777570862092782, -0.3342998177749379))
    check("asinh32", asinh(small), complex64(0.49790294283028763, 0.26955564142495025))
    check("acosh32", acosh(small), complex64(0.3342998177749379, 1.0777570862092782))
    check("atan32", atan(small), complex64(0.49371165990052035, 0.2409482664647896))
    check("pow32 z w", pow(z32, complex32(0.5:f32, -0.25:f32)), complex64(1.8510005834756955, 0.6806954081557204))
    check("pow32 x w", pow(1.5:f32, z32), complex64(1.0332365865926958, 1.0873923653062287))
    check("+32", z32 + w32 + 1.0:f32, z + w + 1.0)
    check("-32", z32 - w32 - 1.0:f32, z - w - 1.0)
    check("neg32", -z32, -z)
    check("*32", z32 * 3.0:f32, z * 3.0)
    println(norm(complex32(3.0:f32, 4.0:f32)), " ", arg(complex32(-1.0:f32, 0.0:f32)) > 3.14:f32, " ",
            z32 != complex32(1.0:f32, 3.0:f32), " ", z32 != z32, " ", (z32 - 1.0:f32).cstr, " ", (2.0:f32 * z32).cstr, " ",
            z32 == complex32(1.0:f32, 3.0:f32))

    println(checked, " checked")
    return 0
}
// out: {real: 4, imag: 1} {real: -2, imag: 3} {real: 5, imag: 5} {real: -1, imag: -2}
// out: {real: 2, imag: 2} {real: 2, imag: 4} {real: 0.5, imag: 1} {real: 0, imag: -2} {real: -1, imag: 0}
// out: true true true false {real: 1, imag: -2} 25.0 5.0
// out: true true true true
// out: true true true true true true
// out: true true true true true
// out: -2.0 true true true true
// out: true true true true true
// out: true true true true true
// out: true true true true true true true
// out: true 9.0 5 true
// out: f64 complex64 4.0 2.5 true
// out: {real: 5, imag: 5} {real: 2, imag: 2} 5.0 f32 true true
// out: 25.0 true true false {real: 0, imag: 2} {real: 2, imag: 4} false
// out: 82 checked
