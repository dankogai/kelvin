// modules/math.k - math.h and its complex counterpart, as C's math and
// cmath are (#43, #148): the functions of math.h for f64 and f32, the
// constants of each as attributes of the type, f64.pi, and complex
// numbers with arithmetic and the elementary functions, c64 with f64
// parts and c32 with f32 parts, named by the size of each part, also as
// complex64 and complex32, aliases by the size of the whole (#150).
// c128 waits for f128.

//     #import <math>
//     let z:c64 = c64(1.0, 2.0)                  // or complex64(1.0, 2.0)
//     let w:c64 = exp(z) * z + 1.0
//     println(`${w} ${abs(w)} ${f64.pi.sin()} ${1.0.i}`)

// The functions overload C's own of the same name (#41): sin(z) of a
// c64 is this file's, sin(x) of an f64 is math.h's, sin(x) of an
// f32 sinf's. Each is a method too, x.sin(), z.sin(), which says which
// where it matters, and x.i is x rotated a quarter turn, c64(0.0, x). The operators
// are Kelvin's (#42), in extend blocks with Self (#135, #140). C99's
// _Complex is not used. The inverse functions
// take their principal values, with C99's branch cuts and its signs of
// zero on them. The elementary functions keep their accuracy near 0, ±1
// and ±i, and none of their steps overflows or loses bits where the
// result does not, up to parts of DBL_MAX; division overflows where C's
// does. The special values of C99's Annex G for infinities and NaNs are
// not attempted, except for sqrt and division by an infinity.
#import <math.h> as C
#import <float.h> as C

// C's own functions of math.h, declared (#41, #148): a number reaches them
// also where only C sees its type, as in tanh(atof(s)), and an f32 its
// f32 kind, sinf, through the overloads below
let exp(x:float64):float64
let log(x:float64):float64
let sqrt(x:float64):float64
let sin(x:float64):float64
let cos(x:float64):float64
let tan(x:float64):float64
let sinh(x:float64):float64
let cosh(x:float64):float64
let tanh(x:float64):float64
let asin(x:float64):float64
let acos(x:float64):float64
let atan(x:float64):float64
let asinh(x:float64):float64
let acosh(x:float64):float64
let atanh(x:float64):float64
let exp2(x:float64):float64
let expm1(x:float64):float64
let log2(x:float64):float64
let log10(x:float64):float64
let log1p(x:float64):float64
let cbrt(x:float64):float64
let floor(x:float64):float64
let ceil(x:float64):float64
let round(x:float64):float64
let trunc(x:float64):float64
let fabs(x:float64):float64
let erf(x:float64):float64
let erfc(x:float64):float64
let tgamma(x:float64):float64
let lgamma(x:float64):float64
let pow(x:float64, y:float64):float64
let hypot(x:float64, y:float64):float64
let atan2(x:float64, y:float64):float64
let fmod(x:float64, y:float64):float64
let fmin(x:float64, y:float64):float64
let fmax(x:float64, y:float64):float64
let copysign(x:float64, y:float64):float64
let fma(x:float64, y:float64, z:float64):float64
let expf(x:float32):float32
let logf(x:float32):float32
let sqrtf(x:float32):float32
let sinf(x:float32):float32
let cosf(x:float32):float32
let tanf(x:float32):float32
let sinhf(x:float32):float32
let coshf(x:float32):float32
let tanhf(x:float32):float32
let asinf(x:float32):float32
let acosf(x:float32):float32
let atanf(x:float32):float32
let asinhf(x:float32):float32
let acoshf(x:float32):float32
let atanhf(x:float32):float32
let exp2f(x:float32):float32
let expm1f(x:float32):float32
let log2f(x:float32):float32
let log10f(x:float32):float32
let log1pf(x:float32):float32
let cbrtf(x:float32):float32
let floorf(x:float32):float32
let ceilf(x:float32):float32
let roundf(x:float32):float32
let truncf(x:float32):float32
let fabsf(x:float32):float32
let erff(x:float32):float32
let erfcf(x:float32):float32
let tgammaf(x:float32):float32
let lgammaf(x:float32):float32
let powf(x:float32, y:float32):float32
let hypotf(x:float32, y:float32):float32
let atan2f(x:float32, y:float32):float32
let fmodf(x:float32, y:float32):float32
let fminf(x:float32, y:float32):float32
let fmaxf(x:float32, y:float32):float32
let copysignf(x:float32, y:float32):float32
let fmaf(x:float32, y:float32, z:float32):float32
let abs(n:int32):int32

// ---------- f32: the functions of math.h by the f32 kind ----------

let exp(x:float32):float32 { expf(x) }
let log(x:float32):float32 { logf(x) }
let sqrt(x:float32):float32 { sqrtf(x) }
let sin(x:float32):float32 { sinf(x) }
let cos(x:float32):float32 { cosf(x) }
let tan(x:float32):float32 { tanf(x) }
let sinh(x:float32):float32 { sinhf(x) }
let cosh(x:float32):float32 { coshf(x) }
let tanh(x:float32):float32 { tanhf(x) }
let asin(x:float32):float32 { asinf(x) }
let acos(x:float32):float32 { acosf(x) }
let atan(x:float32):float32 { atanf(x) }
let asinh(x:float32):float32 { asinhf(x) }
let acosh(x:float32):float32 { acoshf(x) }
let atanh(x:float32):float32 { atanhf(x) }
let exp2(x:float32):float32 { exp2f(x) }
let expm1(x:float32):float32 { expm1f(x) }
let log2(x:float32):float32 { log2f(x) }
let log10(x:float32):float32 { log10f(x) }
let log1p(x:float32):float32 { log1pf(x) }
let cbrt(x:float32):float32 { cbrtf(x) }
let floor(x:float32):float32 { floorf(x) }
let ceil(x:float32):float32 { ceilf(x) }
let round(x:float32):float32 { roundf(x) }
let trunc(x:float32):float32 { truncf(x) }
let fabs(x:float32):float32 { fabsf(x) }
let erf(x:float32):float32 { erff(x) }
let erfc(x:float32):float32 { erfcf(x) }
let tgamma(x:float32):float32 { tgammaf(x) }
let lgamma(x:float32):float32 { lgammaf(x) }
let pow(x:float32, y:float32):float32 { powf(x, y) }
let hypot(x:float32, y:float32):float32 { hypotf(x, y) }
let atan2(x:float32, y:float32):float32 { atan2f(x, y) }
let fmod(x:float32, y:float32):float32 { fmodf(x, y) }
let fmin(x:float32, y:float32):float32 { fminf(x, y) }
let fmax(x:float32, y:float32):float32 { fmaxf(x, y) }
let copysign(x:float32, y:float32):float32 { copysignf(x, y) }
let fma(x:float32, y:float32, z:float32):float32 { fmaf(x, y, z) }

// |x| of a float, and of an i64, as abs(n) of an i32 is C's; not llabs,
// whose long long is not int64_t everywhere
let abs(x:float64):float64 { fabs(x) }
let abs(x:float32):float32 { fabsf(x) }
let abs(n:int64):int64 { n < 0 ? -n : n }

struct c64 {
    real: float64
    imag: float64
}

struct c32 {
    real: float32
    imag: float32
}

// the same by the size of the whole, as aliases (#149, #150)
typealias complex64 = c64
typealias complex32 = c32

// ---------- making one ----------

let c64(real:float64, imag:float64):c64 { (c64){real, imag} }
let c64(real:float64):c64 { (c64){real, 0.0} }
let c64(z:c32):c64 { (c64){z.real, z.imag} }
let c32(real:float32, imag:float32):c32 { (c32){real, imag} }
let c32(real:float32):c32 { (c32){real, 0.0:float32} }
let c32(z:c64):c32 { (c32){float32(z.real), float32(z.imag)} }

// r (cos θ + i sin θ)
let polar(r:float64, theta:float64):c64 { (c64){r * cos(theta), r * sin(theta)} }
let polar(r:float32, theta:float32):c32 { c32(polar(float64(r), float64(theta))) }

// ---------- arithmetic ----------

extend c64 {
    // Self is c64 (#140): each operator is a function of the type (#135)
    static let +(a:Self, b:Self):Self { (Self){a.real + b.real, a.imag + b.imag} }
    static let +(a:Self, b:float64):Self { (Self){a.real + b, a.imag} }
    static let +(a:float64, b:Self):Self { (Self){a + b.real, b.imag} }
    static let -(a:Self, b:Self):Self { (Self){a.real - b.real, a.imag - b.imag} }
    static let -(a:Self, b:float64):Self { (Self){a.real - b, a.imag} }
    static let -(a:float64, b:Self):Self { (Self){a - b.real, -b.imag} }
    static let -(a:Self):Self { (Self){-a.real, -a.imag} }
    static let *(a:Self, b:Self):Self {
        (Self){a.real * b.real - a.imag * b.imag, a.real * b.imag + a.imag * b.real}
    }
    static let *(a:Self, b:float64):Self { (Self){a.real * b, a.imag * b} }
    static let *(a:float64, b:Self):Self { (Self){a * b.real, a * b.imag} }

    // Smith's algorithm, which does not overflow where |b|² would, in Baudin
    // and Smith's form where the ratio of b's parts is subnormal; by 0 it is
    // infinite, and by an infinity 0, as C's is
    static let /(a:Self, b:Self):Self {
        if b.real == 0.0 && b.imag == 0.0 {
            return (Self){a.real / b.real, a.imag / b.real}
        }
        if isinf(b.real) != 0 || isinf(b.imag) != 0 {
            if isfinite(a.real) == 0 || isfinite(a.imag) == 0 {
                return (Self){NAN, NAN}
            }
            let c:float64 = copysign(isinf(b.real) != 0 ? 1.0 : 0.0, b.real)
            let d:float64 = copysign(isinf(b.imag) != 0 ? 1.0 : 0.0, b.imag)
            return (Self){0.0 * (a.real * c + a.imag * d), 0.0 * (a.imag * c - a.real * d)}
        }
        if fmax(fabs(b.real), fabs(b.imag)) > 1e300 {
            return a / (b * 7.888609052210118e-31) * 7.888609052210118e-31  // 2^-100, so d cannot overflow
        }
        if fabs(b.real) >= fabs(b.imag) {
            let r:float64 = b.imag / b.real
            let d:float64 = b.real + b.imag * r
            if fabs(r) < 2.2250738585072014e-308 {  // DBL_MIN: r lost bits, or all of them
                return (Self){(a.real + a.imag * b.imag / b.real) / d, (a.imag - a.real * b.imag / b.real) / d}
            }
            return (Self){(a.real + a.imag * r) / d, (a.imag - a.real * r) / d}
        }
        let r:float64 = b.real / b.imag
        let d:float64 = b.imag + b.real * r
        if fabs(r) < 2.2250738585072014e-308 {
            return (Self){(a.real * b.real / b.imag + a.imag) / d, (a.imag * b.real / b.imag - a.real) / d}
        }
        return (Self){(a.real * r + a.imag) / d, (a.imag * r - a.real) / d}
    }
    static let /(a:Self, b:float64):Self { (Self){a.real / b, a.imag / b} }
    static let /(a:float64, b:Self):Self { Self(a) / b }

    static let ==(a:Self, b:Self):bool { a.real == b.real && a.imag == b.imag }
    static let !=(a:Self, b:Self):bool { a.real != b.real || a.imag != b.imag }
}

extend c32 {
    // Self is c32 (#140): each operator is a function of the type (#135)
    static let +(a:Self, b:Self):Self { (Self){a.real + b.real, a.imag + b.imag} }
    static let +(a:Self, b:float32):Self { (Self){a.real + b, a.imag} }
    static let +(a:float32, b:Self):Self { (Self){a + b.real, b.imag} }
    static let -(a:Self, b:Self):Self { (Self){a.real - b.real, a.imag - b.imag} }
    static let -(a:Self, b:float32):Self { (Self){a.real - b, a.imag} }
    static let -(a:float32, b:Self):Self { (Self){a - b.real, -b.imag} }
    static let -(a:Self):Self { (Self){-a.real, -a.imag} }
    static let *(a:Self, b:Self):Self {
        (Self){a.real * b.real - a.imag * b.imag, a.real * b.imag + a.imag * b.real}
    }
    static let *(a:Self, b:float32):Self { (Self){a.real * b, a.imag * b} }
    static let *(a:float32, b:Self):Self { (Self){a * b.real, a * b.imag} }
    static let /(a:Self, b:Self):Self { Self(c64(a) / c64(b)) }
    static let /(a:Self, b:float32):Self { (Self){a.real / b, a.imag / b} }
    static let /(a:float32, b:Self):Self { Self(float64(a) / c64(b)) }

    static let ==(a:Self, b:Self):bool { a.real == b.real && a.imag == b.imag }
    static let !=(a:Self, b:Self):bool { a.real != b.real || a.imag != b.imag }
}

// ---------- parts ----------

let conj(z:c64):c64 { (c64){z.real, -z.imag} }
let conj(z:c32):c32 { (c32){z.real, -z.imag} }

// the magnitude |z|, without overflow where z.real² would
let abs(z:c64):float64 { hypot(z.real, z.imag) }
let abs(z:c32):float32 { float32(abs(c64(z))) }

// the angle from the positive real axis, from -π (just below the negative
// real axis, where imag is -0) to π
let arg(z:c64):float64 { atan2(z.imag, z.real) }
let arg(z:c32):float32 { float32(arg(c64(z))) }

// |z|²
let norm(z:c64):float64 { z.real * z.real + z.imag * z.imag }
let norm(z:c32):float32 { z.real * z.real + z.imag * z.imag }

// ---------- exponentials and logarithms ----------

// exp(z) = exp(z.real) (cos z.imag + i sin z.imag)
let exp(z:c64):c64 {
    if z.imag == 0.0 {
        return (c64){exp(z.real), z.imag}  // not ∞ × 0 for a large real one
    }
    if z.real > 709.0 {
        // exp(z.real) overflows where a part need not: its half, twice
        let h:float64 = exp(z.real / 2.0)
        return (c64){h * cos(z.imag) * h, h * sin(z.imag) * h}
    }
    return exp(z.real) * (c64){cos(z.imag), sin(z.imag)}
}

// the principal value, log|z| + i arg z, with log1p where a part is near
// ±1, and |z| scaled where it would overflow or lose bits
let log(z:c64):c64 {
    let a:float64 = fmax(fabs(z.real), fabs(z.imag))
    let b:float64 = fmin(fabs(z.real), fabs(z.imag))
    if a > 0.5 && a < 2.0 {
        return (c64){0.5 * log1p((a - 1.0) * (a + 1.0) + b * b), arg(z)}
    }
    if a > 1e300 {
        return (c64){log(abs(z * 0.25)) + 1.3862943611198906, arg(z)}  // + log 4
    }
    if a > 0.0 && a < 1e-300 {
        return (c64){log(abs(z * 2.028240960365167e31)) - 72.0873067782343, arg(z)}  // 2^104
    }
    return (c64){log(abs(z)), arg(z)}
}

// the principal square root, whose real part is never negative
let sqrt(z:c64):c64 {
    if z.real == 0.0 && z.imag == 0.0 {
        return (c64){0.0, z.imag}
    }
    // an infinite part, as C99 gives it, also beside a NaN
    if isinf(z.imag) != 0 {
        return (c64){INFINITY, z.imag}
    }
    if isinf(z.real) != 0 {
        if z.real > 0.0 {
            return (c64){z.real, isnan(z.imag) != 0 ? z.imag : copysign(0.0, z.imag)}
        }
        return (c64){isnan(z.imag) != 0 ? z.imag : 0.0, copysign(INFINITY, z.imag)}
    }
    // t = √((|z.real| + |z|) / 2), its sum scaled by an even power of 2
    // where it would overflow or lose bits; the other part from z itself
    let big:float64 = fmax(fabs(z.real), fabs(z.imag))
    var t:float64 = 0.0
    if big > 1e300 {
        let s:c64 = z * 7.888609052210118e-31  // 2^-100
        t = sqrt((fabs(s.real) + abs(s)) / 2.0) * 1125899906842624.0  // 2^50
    } else if big < 1e-300 {
        let s:c64 = z * 2.028240960365167e31  // 2^104
        t = sqrt((fabs(s.real) + abs(s)) / 2.0) * 2.220446049250313e-16  // 2^-52
    } else {
        t = sqrt((fabs(z.real) + abs(z)) / 2.0)
    }
    if z.real >= 0.0 {
        return (c64){t, z.imag / (2.0 * t)}
    }
    return (c64){fabs(z.imag) / (2.0 * t), copysign(t, z.imag)}
}

// z to the power w: exp(w log z); 0 to a power whose real part is
// positive is 0, and to a negative real power infinite, as 1 / 0 is
let pow(z:c64, w:c64):c64 {
    if z.real == 0.0 && z.imag == 0.0 {
        if w.real == 0.0 && w.imag == 0.0 {
            return c64(1.0)
        }
        if w.real > 0.0 {
            return c64(0.0)
        }
        if w.real < 0.0 && w.imag == 0.0 {
            return c64(1.0) / z
        }
    }
    return exp(w * log(z))
}
let pow(z:c64, x:float64):c64 { pow(z, c64(x)) }
let pow(x:float64, w:c64):c64 { pow(c64(x), w) }

let exp(z:c32):c32 { c32(exp(c64(z))) }
let log(z:c32):c32 { c32(log(c64(z))) }
let sqrt(z:c32):c32 { c32(sqrt(c64(z))) }
let pow(z:c32, w:c32):c32 { c32(pow(c64(z), c64(w))) }
let pow(z:c32, x:float32):c32 { c32(pow(c64(z), float64(x))) }
let pow(x:float32, w:c32):c32 { c32(pow(float64(x), c64(w))) }

// ---------- hyperbolic and trigonometric functions ----------

// The inverses take their principal values, with C's branch cuts and signs
// of zero on them. The trigonometric functions are the hyperbolic ones at
// iz, as C99 defines them: sin z = -i sinh(iz), cos z = cosh(iz),
// tan z = -i tanh(iz), asin z = -i asinh(iz), atan z = -i atanh(iz).

// sinh(a + ib) = sinh a cos b + i cosh a sin b; where e^|a| overflows,
// sinh a and cosh a are ±e^|a| / 2, which is split in two halves
let sinh(z:c64):c64 {
    if z.imag == 0.0 {
        return (c64){sinh(z.real), z.imag}
    }
    if fabs(z.real) > 709.0 {
        let h:float64 = exp(fabs(z.real) / 2.0)
        return (c64){copysign(1.0, z.real) * (h * cos(z.imag) * 0.5) * h, h * sin(z.imag) * 0.5 * h}
    }
    return (c64){sinh(z.real) * cos(z.imag), cosh(z.real) * sin(z.imag)}
}

// cosh(a + ib) = cosh a cos b + i sinh a sin b
let cosh(z:c64):c64 {
    if z.imag == 0.0 {
        return (c64){cosh(z.real), copysign(1.0, z.real) * z.imag}
    }
    if fabs(z.real) > 709.0 {
        let h:float64 = exp(fabs(z.real) / 2.0)
        return (c64){h * cos(z.imag) * 0.5 * h, copysign(1.0, z.real) * (h * sin(z.imag) * 0.5) * h}
    }
    return (c64){cosh(z.real) * cos(z.imag), sinh(z.real) * sin(z.imag)}
}

// by Kahan's algorithm, which neither overflows for a large a nor loses
// accuracy near the poles
let tanh(z:c64):c64 {
    if fabs(z.real) > 22.0 {
        // tanh a is ±1 to the last bit, and the rest falls as e^-2|a|
        let e:float64 = exp(-fabs(z.real))
        return (c64){copysign(1.0, z.real), 4.0 * sin(z.imag) * cos(z.imag) * e * e}
    }
    let t:float64 = tan(z.imag)
    let beta:float64 = 1.0 + t * t  // 1 / cos² b
    let s:float64 = sinh(z.real)
    let rho:float64 = sqrt(1.0 + s * s)  // cosh a
    let d:float64 = 1.0 + beta * s * s
    return (c64){beta * rho * s / d, t / d}
}

let sin(z:c64):c64 {
    let w:c64 = sinh((c64){-z.imag, z.real})
    return (c64){w.imag, -w.real}
}

let cos(z:c64):c64 { cosh((c64){-z.imag, z.real}) }

let tan(z:c64):c64 {
    let w:c64 = tanh((c64){-z.imag, z.real})
    return (c64){w.imag, -w.real}
}

let asinh(z:c64):c64

// asin and acos by Kahan's formulas, which neither cancel near 0 and ±1
// nor overflow for a large |z|; beyond 1e300 by asinh's, as -i asinh(iz),
// and for acos its angle and -asin z's imaginary part
let asin(z:c64):c64 {
    if fmax(fabs(z.real), fabs(z.imag)) > 1e300 {
        let w:c64 = asinh((c64){-z.imag, z.real})
        return (c64){w.imag, -w.real}
    }
    let s:c64 = sqrt(1.0 - z)
    let t:c64 = sqrt(1.0 + z)
    return (c64){atan2(z.real, (s * t).real), asinh((conj(s) * t).imag)}
}

let acos(z:c64):c64 {
    if fmax(fabs(z.real), fabs(z.imag)) > 1e300 {
        // the angle itself, as π/2 - asin z would lose it near the real axis
        let w:c64 = asin(z)
        return (c64){atan2(fabs(z.imag), z.real), -w.imag}
    }
    let s:c64 = sqrt(1.0 - z)
    let t:c64 = sqrt(1.0 + z)
    return (c64){2.0 * atan2(s.real, t.real), asinh((conj(t) * s).imag)}
}

// asinh z = -i asin(iz), as asin z = -i asinh(iz) and asin is odd;
// beyond 1e300 it is log 2z, for z.real ≥ 0, and odd
let asinh(z:c64):c64 {
    if fmax(fabs(z.real), fabs(z.imag)) > 1e300 {
        if signbit(z.real) != 0 {
            return -asinh(-z)
        }
        let w:c64 = log(z)
        return (c64){w.real + 0.6931471805599453, w.imag}
    }
    let w:c64 = asin((c64){-z.imag, z.real})
    return (c64){w.imag, -w.real}
}

// Kahan's formula, as for acos; beyond 1e300, log 2z
let acosh(z:c64):c64 {
    if fmax(fabs(z.real), fabs(z.imag)) > 1e300 {
        let w:c64 = log(z)
        return (c64){w.real + 0.6931471805599453, w.imag}
    }
    let s:c64 = sqrt(z - 1.0)
    let t:c64 = sqrt(z + 1.0)
    return (c64){asinh((conj(s) * t).real), 2.0 * atan2(s.imag, t.real)}
}

// atanh z = (log(1 + z) - log(1 - z)) / 2, written so that it neither
// cancels near 0 and -1 nor overflows for a large |z|
let atanh(z:c64):c64 {
    if signbit(z.real) != 0 {
        return -atanh(-z)  // atanh is odd
    }
    let x:float64 = z.real
    let y:float64 = z.imag
    if x > 1e150 || fabs(y) > 1e150 {
        // 1/z + iπ/2, its sign that of y
        let h:float64 = abs(z)
        return (c64){x / h / h, copysign(1.5707963267948966, y)}
    }
    if x == 1.0 && y != 0.0 && fabs(y) < 1e-150 {
        // y² would underflow: log(2 / |y|) / 2 + iπ/4, its sign that of y
        return (c64){0.5 * (0.6931471805599453 - log(fabs(y))), copysign(0.7853981633974483, y)}
    }
    let d:float64 = (1.0 - x) * (1.0 - x) + y * y
    return (c64){0.25 * log1p(4.0 * x / d), 0.5 * atan2(2.0 * y, (1.0 - x) * (1.0 + x) - y * y)}
}

// atan z = -i atanh(iz)
let atan(z:c64):c64 {
    let w:c64 = atanh((c64){-z.imag, z.real})
    return (c64){w.imag, -w.real}
}

let sinh(z:c32):c32 { c32(sinh(c64(z))) }
let cosh(z:c32):c32 { c32(cosh(c64(z))) }
let tanh(z:c32):c32 { c32(tanh(c64(z))) }
let sin(z:c32):c32 { c32(sin(c64(z))) }
let cos(z:c32):c32 { c32(cos(c64(z))) }
let tan(z:c32):c32 { c32(tan(c64(z))) }
let asin(z:c32):c32 { c32(asin(c64(z))) }
let acos(z:c32):c32 { c32(acos(c64(z))) }
let asinh(z:c32):c32 { c32(asinh(c64(z))) }
let acosh(z:c32):c32 { c32(acosh(c64(z))) }
let atanh(z:c32):c32 { c32(atanh(c64(z))) }
let atan(z:c32):c32 { c32(atan(c64(z))) }

// ---------- methods and constants (#148) ----------

extend float64 {
    // the constants of math.h, as attributes of the type (#148): f64.pi, f64.infinity
    static let pi:Self = 3.141592653589793
    static let tau:Self = 6.283185307179586
    static let e:Self = 2.718281828459045
    static let ln2:Self = 0.6931471805599453
    static let ln10:Self = 2.302585092994046
    static let log2e:Self = 1.4426950408889634
    static let log10e:Self = 0.4342944819032518
    static let sqrt2:Self = 1.4142135623730951
    static let infinity:Self = INFINITY
    static let nan:Self = NAN
    static let epsilon:Self = DBL_EPSILON
    static let max:Self = DBL_MAX
    static let min:Self = DBL_MIN

    // each function of math.h as a method, x.sin(): the function by another name
    let exp():Self { exp(self) }
    let log():Self { log(self) }
    let sqrt():Self { sqrt(self) }
    let sin():Self { sin(self) }
    let cos():Self { cos(self) }
    let tan():Self { tan(self) }
    let sinh():Self { sinh(self) }
    let cosh():Self { cosh(self) }
    let tanh():Self { tanh(self) }
    let asin():Self { asin(self) }
    let acos():Self { acos(self) }
    let atan():Self { atan(self) }
    let asinh():Self { asinh(self) }
    let acosh():Self { acosh(self) }
    let atanh():Self { atanh(self) }
    let exp2():Self { exp2(self) }
    let expm1():Self { expm1(self) }
    let log2():Self { log2(self) }
    let log10():Self { log10(self) }
    let log1p():Self { log1p(self) }
    let cbrt():Self { cbrt(self) }
    let floor():Self { floor(self) }
    let ceil():Self { ceil(self) }
    let round():Self { round(self) }
    let trunc():Self { trunc(self) }
    let erf():Self { erf(self) }
    let erfc():Self { erfc(self) }
    let tgamma():Self { tgamma(self) }
    let lgamma():Self { lgamma(self) }
    let abs():Self { fabs(self) }
    let pow(y:Self):Self { pow(self, y) }
    let hypot(y:Self):Self { hypot(self, y) }
    let fmod(y:Self):Self { fmod(self, y) }
    let fmin(y:Self):Self { fmin(self, y) }
    let fmax(y:Self):Self { fmax(self, y) }
    let copysign(y:Self):Self { copysign(self, y) }
    let atan2(x:Self):Self { atan2(self, x) }
    let fma(y:Self, z:Self):Self { fma(self, y, z) }

    let isnan:bool { self != self }
    let isinf:bool { self == Self.infinity || self == -Self.infinity }
    let isfinite:bool { !.isnan && !.isinf }
    let i:c64 { c64(0.0, self) }                 // x rotated a quarter turn: c64(0, x)
}

extend float32 {
    // the constants of math.h, as attributes of the type (#148): f32.pi, f32.infinity
    static let pi:Self = 3.141592653589793:Self
    static let tau:Self = 6.283185307179586:Self
    static let e:Self = 2.718281828459045:Self
    static let ln2:Self = 0.6931471805599453:Self
    static let ln10:Self = 2.302585092994046:Self
    static let log2e:Self = 1.4426950408889634:Self
    static let log10e:Self = 0.4342944819032518:Self
    static let sqrt2:Self = 1.4142135623730951:Self
    static let infinity:Self = INFINITY
    static let nan:Self = NAN
    static let epsilon:Self = FLT_EPSILON
    static let max:Self = FLT_MAX
    static let min:Self = FLT_MIN

    // each function of math.h as a method, x.sin(): the function by another name
    let exp():Self { exp(self) }
    let log():Self { log(self) }
    let sqrt():Self { sqrt(self) }
    let sin():Self { sin(self) }
    let cos():Self { cos(self) }
    let tan():Self { tan(self) }
    let sinh():Self { sinh(self) }
    let cosh():Self { cosh(self) }
    let tanh():Self { tanh(self) }
    let asin():Self { asin(self) }
    let acos():Self { acos(self) }
    let atan():Self { atan(self) }
    let asinh():Self { asinh(self) }
    let acosh():Self { acosh(self) }
    let atanh():Self { atanh(self) }
    let exp2():Self { exp2(self) }
    let expm1():Self { expm1(self) }
    let log2():Self { log2(self) }
    let log10():Self { log10(self) }
    let log1p():Self { log1p(self) }
    let cbrt():Self { cbrt(self) }
    let floor():Self { floor(self) }
    let ceil():Self { ceil(self) }
    let round():Self { round(self) }
    let trunc():Self { trunc(self) }
    let erf():Self { erf(self) }
    let erfc():Self { erfc(self) }
    let tgamma():Self { tgamma(self) }
    let lgamma():Self { lgamma(self) }
    let abs():Self { fabs(self) }
    let pow(y:Self):Self { pow(self, y) }
    let hypot(y:Self):Self { hypot(self, y) }
    let fmod(y:Self):Self { fmod(self, y) }
    let fmin(y:Self):Self { fmin(self, y) }
    let fmax(y:Self):Self { fmax(self, y) }
    let copysign(y:Self):Self { copysign(self, y) }
    let atan2(x:Self):Self { atan2(self, x) }
    let fma(y:Self, z:Self):Self { fma(self, y, z) }

    let isnan:bool { self != self }
    let isinf:bool { self == Self.infinity || self == -Self.infinity }
    let isfinite:bool { !.isnan && !.isinf }
    let i:c32 { c32(0.0:Self, self) }                 // x rotated a quarter turn: c32(0, x)
}

extend c64 {
    // the functions as methods, z.exp(), and z.i, z rotated a quarter turn:
    // z times i, (-imag, real), 0 - imag so that no zero turns negative
    let exp():Self { exp(self) }
    let log():Self { log(self) }
    let sqrt():Self { sqrt(self) }
    let sin():Self { sin(self) }
    let cos():Self { cos(self) }
    let tan():Self { tan(self) }
    let sinh():Self { sinh(self) }
    let cosh():Self { cosh(self) }
    let tanh():Self { tanh(self) }
    let asin():Self { asin(self) }
    let acos():Self { acos(self) }
    let atan():Self { atan(self) }
    let asinh():Self { asinh(self) }
    let acosh():Self { acosh(self) }
    let atanh():Self { atanh(self) }
    let conj():Self { conj(self) }
    let abs():float64 { abs(self) }
    let arg():float64 { arg(self) }
    let norm():float64 { norm(self) }
    let pow(w:Self):Self { pow(self, w) }
    let i:Self { Self(0.0 - .imag, .real) }
}

extend c32 {
    // the functions as methods, z.exp(), and z.i, z rotated a quarter turn
    let exp():Self { exp(self) }
    let log():Self { log(self) }
    let sqrt():Self { sqrt(self) }
    let sin():Self { sin(self) }
    let cos():Self { cos(self) }
    let tan():Self { tan(self) }
    let sinh():Self { sinh(self) }
    let cosh():Self { cosh(self) }
    let tanh():Self { tanh(self) }
    let asin():Self { asin(self) }
    let acos():Self { acos(self) }
    let atan():Self { atan(self) }
    let asinh():Self { asinh(self) }
    let acosh():Self { acosh(self) }
    let atanh():Self { atanh(self) }
    let conj():Self { conj(self) }
    let abs():float32 { abs(self) }
    let arg():float32 { arg(self) }
    let norm():float32 { norm(self) }
    let pow(w:Self):Self { pow(self, w) }
    let i:Self { Self(0.0:float32 - .imag, .real) }
}
