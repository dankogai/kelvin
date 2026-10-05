// lib/complex.k - complex numbers, with arithmetic and the elementary
// functions (#43): complex64 has f64 parts and complex32 f32 parts, named
// by the size of each part. complex128 waits for f128.
//
//     #import <lib/complex.k>
//     let z:complex64 = complex64(1.0, 2.0)
//     let w:complex64 = exp(z) * z + 1.0
//     println(`${w} ${abs(w)}`)
//
// The functions overload C's own of the same name (#41): sin(z) of a
// complex64 is this file's, sin(x) of an f64 is math.h's. The operators
// are Kelvin's (#42). C99's _Complex is not used. The inverse functions
// take their principal values, with C99's branch cuts and its signs of
// zero on them. The elementary functions keep their accuracy near 0, ±1
// and ±i, and none of their steps overflows or loses bits where the
// result does not, up to parts of DBL_MAX; division overflows where C's
// does. The special values of C99's Annex G for infinities and NaNs are
// not attempted, except for sqrt and division by an infinity.
#import <math.h> as C

// C's own functions of the names this file overloads, declared, so that a
// number reaches them also where only C sees its type, as in
// tanh(atof(s)) (#41)
exp(x:f64):f64
log(x:f64):f64
sqrt(x:f64):f64
pow(x:f64, y:f64):f64
sin(x:f64):f64
cos(x:f64):f64
tan(x:f64):f64
sinh(x:f64):f64
cosh(x:f64):f64
tanh(x:f64):f64
asin(x:f64):f64
acos(x:f64):f64
atan(x:f64):f64
asinh(x:f64):f64
acosh(x:f64):f64
atanh(x:f64):f64
abs(n:i32):i32

struct complex64 {
    real: f64
    imag: f64
}

struct complex32 {
    real: f32
    imag: f32
}

// ---------- making one ----------

complex64(real:f64, imag:f64):complex64 { (complex64){real, imag} }
complex64(real:f64):complex64 { (complex64){real, 0.0} }
complex64(z:complex32):complex64 { (complex64){z.real, z.imag} }
complex32(real:f32, imag:f32):complex32 { (complex32){real, imag} }
complex32(real:f32):complex32 { (complex32){real, 0.0:f32} }
complex32(z:complex64):complex32 { (complex32){f32(z.real), f32(z.imag)} }

// r (cos θ + i sin θ)
polar(r:f64, theta:f64):complex64 { (complex64){r * cos(theta), r * sin(theta)} }
polar(r:f32, theta:f32):complex32 { complex32(polar(f64(r), f64(theta))) }

// ---------- arithmetic ----------

+(a:complex64, b:complex64):complex64 { (complex64){a.real + b.real, a.imag + b.imag} }
+(a:complex64, b:f64):complex64 { (complex64){a.real + b, a.imag} }
+(a:f64, b:complex64):complex64 { (complex64){a + b.real, b.imag} }
-(a:complex64, b:complex64):complex64 { (complex64){a.real - b.real, a.imag - b.imag} }
-(a:complex64, b:f64):complex64 { (complex64){a.real - b, a.imag} }
-(a:f64, b:complex64):complex64 { (complex64){a - b.real, -b.imag} }
-(a:complex64):complex64 { (complex64){-a.real, -a.imag} }
*(a:complex64, b:complex64):complex64 {
    (complex64){a.real * b.real - a.imag * b.imag, a.real * b.imag + a.imag * b.real}
}
*(a:complex64, b:f64):complex64 { (complex64){a.real * b, a.imag * b} }
*(a:f64, b:complex64):complex64 { (complex64){a * b.real, a * b.imag} }

// Smith's algorithm, which does not overflow where |b|² would, in Baudin
// and Smith's form where the ratio of b's parts is subnormal; by 0 it is
// infinite, and by an infinity 0, as C's is
/(a:complex64, b:complex64):complex64 {
    if b.real == 0.0 && b.imag == 0.0 {
        return (complex64){a.real / b.real, a.imag / b.real}
    }
    if isinf(b.real) != 0 || isinf(b.imag) != 0 {
        if isfinite(a.real) == 0 || isfinite(a.imag) == 0 {
            return (complex64){NAN, NAN}
        }
        let c:f64 = copysign(isinf(b.real) != 0 ? 1.0 : 0.0, b.real)
        let d:f64 = copysign(isinf(b.imag) != 0 ? 1.0 : 0.0, b.imag)
        return (complex64){0.0 * (a.real * c + a.imag * d), 0.0 * (a.imag * c - a.real * d)}
    }
    if fmax(fabs(b.real), fabs(b.imag)) > 1e300 {
        return a / (b * 7.888609052210118e-31) * 7.888609052210118e-31  // 2^-100, so d cannot overflow
    }
    if fabs(b.real) >= fabs(b.imag) {
        let r:f64 = b.imag / b.real
        let d:f64 = b.real + b.imag * r
        if fabs(r) < 2.2250738585072014e-308 {  // DBL_MIN: r lost bits, or all of them
            return (complex64){(a.real + a.imag * b.imag / b.real) / d, (a.imag - a.real * b.imag / b.real) / d}
        }
        return (complex64){(a.real + a.imag * r) / d, (a.imag - a.real * r) / d}
    }
    let r:f64 = b.real / b.imag
    let d:f64 = b.imag + b.real * r
    if fabs(r) < 2.2250738585072014e-308 {
        return (complex64){(a.real * b.real / b.imag + a.imag) / d, (a.imag * b.real / b.imag - a.real) / d}
    }
    return (complex64){(a.real * r + a.imag) / d, (a.imag * r - a.real) / d}
}
/(a:complex64, b:f64):complex64 { (complex64){a.real / b, a.imag / b} }
/(a:f64, b:complex64):complex64 { complex64(a) / b }

==(a:complex64, b:complex64):bool { a.real == b.real && a.imag == b.imag }
!=(a:complex64, b:complex64):bool { a.real != b.real || a.imag != b.imag }

+(a:complex32, b:complex32):complex32 { (complex32){a.real + b.real, a.imag + b.imag} }
+(a:complex32, b:f32):complex32 { (complex32){a.real + b, a.imag} }
+(a:f32, b:complex32):complex32 { (complex32){a + b.real, b.imag} }
-(a:complex32, b:complex32):complex32 { (complex32){a.real - b.real, a.imag - b.imag} }
-(a:complex32, b:f32):complex32 { (complex32){a.real - b, a.imag} }
-(a:f32, b:complex32):complex32 { (complex32){a - b.real, -b.imag} }
-(a:complex32):complex32 { (complex32){-a.real, -a.imag} }
*(a:complex32, b:complex32):complex32 {
    (complex32){a.real * b.real - a.imag * b.imag, a.real * b.imag + a.imag * b.real}
}
*(a:complex32, b:f32):complex32 { (complex32){a.real * b, a.imag * b} }
*(a:f32, b:complex32):complex32 { (complex32){a * b.real, a * b.imag} }
/(a:complex32, b:complex32):complex32 { complex32(complex64(a) / complex64(b)) }
/(a:complex32, b:f32):complex32 { (complex32){a.real / b, a.imag / b} }
/(a:f32, b:complex32):complex32 { complex32(f64(a) / complex64(b)) }

==(a:complex32, b:complex32):bool { a.real == b.real && a.imag == b.imag }
!=(a:complex32, b:complex32):bool { a.real != b.real || a.imag != b.imag }

// ---------- parts ----------

conj(z:complex64):complex64 { (complex64){z.real, -z.imag} }
conj(z:complex32):complex32 { (complex32){z.real, -z.imag} }

// the magnitude |z|, without overflow where z.real² would
abs(z:complex64):f64 { hypot(z.real, z.imag) }
abs(z:complex32):f32 { f32(abs(complex64(z))) }

// the angle from the positive real axis, from -π (just below the negative
// real axis, where imag is -0) to π
arg(z:complex64):f64 { atan2(z.imag, z.real) }
arg(z:complex32):f32 { f32(arg(complex64(z))) }

// |z|²
norm(z:complex64):f64 { z.real * z.real + z.imag * z.imag }
norm(z:complex32):f32 { z.real * z.real + z.imag * z.imag }

// ---------- exponentials and logarithms ----------

// exp(z) = exp(z.real) (cos z.imag + i sin z.imag)
exp(z:complex64):complex64 {
    if z.imag == 0.0 {
        return (complex64){exp(z.real), z.imag}  // not ∞ × 0 for a large real one
    }
    if z.real > 709.0 {
        // exp(z.real) overflows where a part need not: its half, twice
        let h:f64 = exp(z.real / 2.0)
        return (complex64){h * cos(z.imag) * h, h * sin(z.imag) * h}
    }
    return exp(z.real) * (complex64){cos(z.imag), sin(z.imag)}
}

// the principal value, log|z| + i arg z, with log1p where a part is near
// ±1, and |z| scaled where it would overflow or lose bits
log(z:complex64):complex64 {
    let a:f64 = fmax(fabs(z.real), fabs(z.imag))
    let b:f64 = fmin(fabs(z.real), fabs(z.imag))
    if a > 0.5 && a < 2.0 {
        return (complex64){0.5 * log1p((a - 1.0) * (a + 1.0) + b * b), arg(z)}
    }
    if a > 1e300 {
        return (complex64){log(abs(z * 0.25)) + 1.3862943611198906, arg(z)}  // + log 4
    }
    if a > 0.0 && a < 1e-300 {
        return (complex64){log(abs(z * 2.028240960365167e31)) - 72.0873067782343, arg(z)}  // 2^104
    }
    return (complex64){log(abs(z)), arg(z)}
}

// the principal square root, whose real part is never negative
sqrt(z:complex64):complex64 {
    if z.real == 0.0 && z.imag == 0.0 {
        return (complex64){0.0, z.imag}
    }
    // an infinite part, as C99 gives it, also beside a NaN
    if isinf(z.imag) != 0 {
        return (complex64){INFINITY, z.imag}
    }
    if isinf(z.real) != 0 {
        if z.real > 0.0 {
            return (complex64){z.real, isnan(z.imag) != 0 ? z.imag : copysign(0.0, z.imag)}
        }
        return (complex64){isnan(z.imag) != 0 ? z.imag : 0.0, copysign(INFINITY, z.imag)}
    }
    // t = √((|z.real| + |z|) / 2), its sum scaled by an even power of 2
    // where it would overflow or lose bits; the other part from z itself
    let big:f64 = fmax(fabs(z.real), fabs(z.imag))
    var t:f64 = 0.0
    if big > 1e300 {
        let s:complex64 = z * 7.888609052210118e-31  // 2^-100
        t = sqrt((fabs(s.real) + abs(s)) / 2.0) * 1125899906842624.0  // 2^50
    } else if big < 1e-300 {
        let s:complex64 = z * 2.028240960365167e31  // 2^104
        t = sqrt((fabs(s.real) + abs(s)) / 2.0) * 2.220446049250313e-16  // 2^-52
    } else {
        t = sqrt((fabs(z.real) + abs(z)) / 2.0)
    }
    if z.real >= 0.0 {
        return (complex64){t, z.imag / (2.0 * t)}
    }
    return (complex64){fabs(z.imag) / (2.0 * t), copysign(t, z.imag)}
}

// z to the power w: exp(w log z); 0 to a power whose real part is
// positive is 0, and to a negative real power infinite, as 1 / 0 is
pow(z:complex64, w:complex64):complex64 {
    if z.real == 0.0 && z.imag == 0.0 {
        if w.real == 0.0 && w.imag == 0.0 {
            return complex64(1.0)
        }
        if w.real > 0.0 {
            return complex64(0.0)
        }
        if w.real < 0.0 && w.imag == 0.0 {
            return complex64(1.0) / z
        }
    }
    return exp(w * log(z))
}
pow(z:complex64, x:f64):complex64 { pow(z, complex64(x)) }
pow(x:f64, w:complex64):complex64 { pow(complex64(x), w) }

exp(z:complex32):complex32 { complex32(exp(complex64(z))) }
log(z:complex32):complex32 { complex32(log(complex64(z))) }
sqrt(z:complex32):complex32 { complex32(sqrt(complex64(z))) }
pow(z:complex32, w:complex32):complex32 { complex32(pow(complex64(z), complex64(w))) }
pow(z:complex32, x:f32):complex32 { complex32(pow(complex64(z), f64(x))) }
pow(x:f32, w:complex32):complex32 { complex32(pow(f64(x), complex64(w))) }

// ---------- hyperbolic and trigonometric functions ----------
//
// The inverses take their principal values, with C's branch cuts and signs
// of zero on them. The trigonometric functions are the hyperbolic ones at
// iz, as C99 defines them: sin z = -i sinh(iz), cos z = cosh(iz),
// tan z = -i tanh(iz), asin z = -i asinh(iz), atan z = -i atanh(iz).

// sinh(a + ib) = sinh a cos b + i cosh a sin b; where e^|a| overflows,
// sinh a and cosh a are ±e^|a| / 2, which is split in two halves
sinh(z:complex64):complex64 {
    if z.imag == 0.0 {
        return (complex64){sinh(z.real), z.imag}
    }
    if fabs(z.real) > 709.0 {
        let h:f64 = exp(fabs(z.real) / 2.0)
        return (complex64){copysign(1.0, z.real) * (h * cos(z.imag) * 0.5) * h, h * sin(z.imag) * 0.5 * h}
    }
    return (complex64){sinh(z.real) * cos(z.imag), cosh(z.real) * sin(z.imag)}
}

// cosh(a + ib) = cosh a cos b + i sinh a sin b
cosh(z:complex64):complex64 {
    if z.imag == 0.0 {
        return (complex64){cosh(z.real), copysign(1.0, z.real) * z.imag}
    }
    if fabs(z.real) > 709.0 {
        let h:f64 = exp(fabs(z.real) / 2.0)
        return (complex64){h * cos(z.imag) * 0.5 * h, copysign(1.0, z.real) * (h * sin(z.imag) * 0.5) * h}
    }
    return (complex64){cosh(z.real) * cos(z.imag), sinh(z.real) * sin(z.imag)}
}

// by Kahan's algorithm, which neither overflows for a large a nor loses
// accuracy near the poles
tanh(z:complex64):complex64 {
    if fabs(z.real) > 22.0 {
        // tanh a is ±1 to the last bit, and the rest falls as e^-2|a|
        let e:f64 = exp(-fabs(z.real))
        return (complex64){copysign(1.0, z.real), 4.0 * sin(z.imag) * cos(z.imag) * e * e}
    }
    let t:f64 = tan(z.imag)
    let beta:f64 = 1.0 + t * t  // 1 / cos² b
    let s:f64 = sinh(z.real)
    let rho:f64 = sqrt(1.0 + s * s)  // cosh a
    let d:f64 = 1.0 + beta * s * s
    return (complex64){beta * rho * s / d, t / d}
}

sin(z:complex64):complex64 {
    let w:complex64 = sinh((complex64){-z.imag, z.real})
    return (complex64){w.imag, -w.real}
}

cos(z:complex64):complex64 { cosh((complex64){-z.imag, z.real}) }

tan(z:complex64):complex64 {
    let w:complex64 = tanh((complex64){-z.imag, z.real})
    return (complex64){w.imag, -w.real}
}

asinh(z:complex64):complex64

// asin and acos by Kahan's formulas, which neither cancel near 0 and ±1
// nor overflow for a large |z|; beyond 1e300 by asinh's, as -i asinh(iz),
// and for acos its angle and -asin z's imaginary part
asin(z:complex64):complex64 {
    if fmax(fabs(z.real), fabs(z.imag)) > 1e300 {
        let w:complex64 = asinh((complex64){-z.imag, z.real})
        return (complex64){w.imag, -w.real}
    }
    let s:complex64 = sqrt(1.0 - z)
    let t:complex64 = sqrt(1.0 + z)
    return (complex64){atan2(z.real, (s * t).real), asinh((conj(s) * t).imag)}
}

acos(z:complex64):complex64 {
    if fmax(fabs(z.real), fabs(z.imag)) > 1e300 {
        // the angle itself, as π/2 - asin z would lose it near the real axis
        let w:complex64 = asin(z)
        return (complex64){atan2(fabs(z.imag), z.real), -w.imag}
    }
    let s:complex64 = sqrt(1.0 - z)
    let t:complex64 = sqrt(1.0 + z)
    return (complex64){2.0 * atan2(s.real, t.real), asinh((conj(t) * s).imag)}
}

// asinh z = -i asin(iz), as asin z = -i asinh(iz) and asin is odd;
// beyond 1e300 it is log 2z, for z.real ≥ 0, and odd
asinh(z:complex64):complex64 {
    if fmax(fabs(z.real), fabs(z.imag)) > 1e300 {
        if signbit(z.real) != 0 {
            return -asinh(-z)
        }
        let w:complex64 = log(z)
        return (complex64){w.real + 0.6931471805599453, w.imag}
    }
    let w:complex64 = asin((complex64){-z.imag, z.real})
    return (complex64){w.imag, -w.real}
}

// Kahan's formula, as for acos; beyond 1e300, log 2z
acosh(z:complex64):complex64 {
    if fmax(fabs(z.real), fabs(z.imag)) > 1e300 {
        let w:complex64 = log(z)
        return (complex64){w.real + 0.6931471805599453, w.imag}
    }
    let s:complex64 = sqrt(z - 1.0)
    let t:complex64 = sqrt(z + 1.0)
    return (complex64){asinh((conj(s) * t).real), 2.0 * atan2(s.imag, t.real)}
}

// atanh z = (log(1 + z) - log(1 - z)) / 2, written so that it neither
// cancels near 0 and -1 nor overflows for a large |z|
atanh(z:complex64):complex64 {
    if signbit(z.real) != 0 {
        return -atanh(-z)  // atanh is odd
    }
    let x:f64 = z.real
    let y:f64 = z.imag
    if x > 1e150 || fabs(y) > 1e150 {
        // 1/z + iπ/2, its sign that of y
        let h:f64 = abs(z)
        return (complex64){x / h / h, copysign(1.5707963267948966, y)}
    }
    if x == 1.0 && y != 0.0 && fabs(y) < 1e-150 {
        // y² would underflow: log(2 / |y|) / 2 + iπ/4, its sign that of y
        return (complex64){0.5 * (0.6931471805599453 - log(fabs(y))), copysign(0.7853981633974483, y)}
    }
    let d:f64 = (1.0 - x) * (1.0 - x) + y * y
    return (complex64){0.25 * log1p(4.0 * x / d), 0.5 * atan2(2.0 * y, (1.0 - x) * (1.0 + x) - y * y)}
}

// atan z = -i atanh(iz)
atan(z:complex64):complex64 {
    let w:complex64 = atanh((complex64){-z.imag, z.real})
    return (complex64){w.imag, -w.real}
}

sinh(z:complex32):complex32 { complex32(sinh(complex64(z))) }
cosh(z:complex32):complex32 { complex32(cosh(complex64(z))) }
tanh(z:complex32):complex32 { complex32(tanh(complex64(z))) }
sin(z:complex32):complex32 { complex32(sin(complex64(z))) }
cos(z:complex32):complex32 { complex32(cos(complex64(z))) }
tan(z:complex32):complex32 { complex32(tan(complex64(z))) }
asin(z:complex32):complex32 { complex32(asin(complex64(z))) }
acos(z:complex32):complex32 { complex32(acos(complex64(z))) }
asinh(z:complex32):complex32 { complex32(asinh(complex64(z))) }
acosh(z:complex32):complex32 { complex32(acosh(complex64(z))) }
atanh(z:complex32):complex32 { complex32(atanh(complex64(z))) }
atan(z:complex32):complex32 { complex32(atan(complex64(z))) }
