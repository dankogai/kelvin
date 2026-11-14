// modules/math+Rational.k - the overlay of math with Rational (#551,
// #552): read where <math> and <Rational> are both imported, and by no
// program that imports one of them alone. cbr is a complex number whose
// parts are bigrats, fractions of any size, also complexBigRat by its
// alias, as c64 is complex64.
//
//     #import <math>
//     #import <Rational>
//     let z = cbr(1n.over(2n), 1n.over(3n))
//     println(z * z, " ", z / z.conj(), " ", norm(z))
//
// It has math's functions of a bigrat too (#553), each to a precision,
// below.
//
// What a cbr offers is what stays rational, and so exact: + - * /, unary -,
// == and !=, with a bigrat, a BigInt or an i64 on either side; conj and
// norm, each a method too; z.i, z rotated a quarter turn, and r.i of a
// bigrat, cbr(0, r). abs, arg, exp and the rest of math's are not
// rational: c64(z) is the nearest c64, which has them. A part may be an
// infinity or a NaN, a bigrat's own (rational.md): z / 0 is infinite, and
// no division by zero.
#import <math>
#import <Rational>

struct cbr {
    real: bigrat
    imag: bigrat
}

// the same by what it is of, as an alias, as complex64 is c64's (#150)
typealias complexBigRat = cbr

// ---------- making one ----------

let cbr(real:lent bigrat, imag:lent bigrat):cbr { (cbr){real.copy(), imag.copy()} }
let cbr(real:lent bigrat):cbr { (cbr){real.copy(), bigrat(0)} }
let cbr(real:lent BigInt, imag:lent BigInt):cbr { (cbr){bigrat(real), bigrat(imag)} }
let cbr(real:lent BigInt):cbr { (cbr){bigrat(real), bigrat(0)} }
let cbr(real:i64, imag:i64):cbr { (cbr){bigrat(real), bigrat(imag)} }
let cbr(real:i64):cbr { (cbr){bigrat(real), bigrat(0)} }

// the nearest c64, each part the f64 of its bigrat
let c64(z:lent cbr):c64 { (c64){z.real.f64, z.imag.f64} }

// ---------- arithmetic ----------

extend cbr {
    static let +(a:Self, b:Self):Self { (Self){a.real + b.real, a.imag + b.imag} }
    static let +(a:Self, b:bigrat):Self { (Self){a.real + b, a.imag.copy()} }
    static let +(a:bigrat, b:Self):Self { (Self){a + b.real, b.imag.copy()} }
    static let +(a:Self, b:BigInt):Self { a + bigrat(b) }
    static let +(a:BigInt, b:Self):Self { bigrat(a) + b }
    static let +(a:Self, b:i64):Self { a + bigrat(b) }
    static let +(a:i64, b:Self):Self { bigrat(a) + b }

    static let -(a:Self):Self { (Self){-a.real, -a.imag} }
    static let -(a:Self, b:Self):Self { (Self){a.real - b.real, a.imag - b.imag} }
    static let -(a:Self, b:bigrat):Self { (Self){a.real - b, a.imag.copy()} }
    static let -(a:bigrat, b:Self):Self { (Self){a - b.real, -b.imag} }
    static let -(a:Self, b:BigInt):Self { a - bigrat(b) }
    static let -(a:BigInt, b:Self):Self { bigrat(a) - b }
    static let -(a:Self, b:i64):Self { a - bigrat(b) }
    static let -(a:i64, b:Self):Self { bigrat(a) - b }

    static let *(a:Self, b:Self):Self {
        (Self){a.real * b.real - a.imag * b.imag, a.real * b.imag + a.imag * b.real}
    }
    static let *(a:Self, b:bigrat):Self { (Self){a.real * b, a.imag * b} }
    static let *(a:bigrat, b:Self):Self { (Self){a * b.real, a * b.imag} }
    static let *(a:Self, b:BigInt):Self { a * bigrat(b) }
    static let *(a:BigInt, b:Self):Self { bigrat(a) * b }
    static let *(a:Self, b:i64):Self { a * bigrat(b) }
    static let *(a:i64, b:Self):Self { bigrat(a) * b }

    // a times b's conjugate, over b's norm, a bigrat; by 0 it is infinite,
    // each part a bigrat's quotient by 0, and by an infinity 0, as c64's is
    static let /(a:Self, b:Self):Self {
        if b.real.isFinite && b.real.num.isZero && b.imag.isFinite && b.imag.num.isZero {
            return (Self){a.real / b.real, a.imag / b.real}
        }
        if b.real.isInfinite || b.imag.isInfinite {
            if !a.real.isFinite || !a.imag.isFinite { return (Self){bigrat(0, 0), bigrat(0, 0)} }
            return (Self){bigrat(0), bigrat(0)}
        }
        let d = b.real * b.real + b.imag * b.imag
        return (Self){(a.real * b.real + a.imag * b.imag) / d, (a.imag * b.real - a.real * b.imag) / d}
    }
    static let /(a:Self, b:bigrat):Self { (Self){a.real / b, a.imag / b} }
    static let /(a:bigrat, b:Self):Self { cbr(a) / b }
    static let /(a:Self, b:BigInt):Self { a / bigrat(b) }
    static let /(a:BigInt, b:Self):Self { cbr(a) / b }
    static let /(a:Self, b:i64):Self { a / bigrat(b) }
    static let /(a:i64, b:Self):Self { cbr(a) / b }

    // a part that is a NaN equals nothing, as a bigrat's
    static let ==(a:Self, b:Self):bool { a.real == b.real && a.imag == b.imag }
    static let !=(a:Self, b:Self):bool { !(a == b) }
}

// ---------- parts ----------

let conj(z:lent cbr):cbr { (cbr){z.real.copy(), -z.imag} }

// |z|², a bigrat: |z| itself is seldom rational
let norm(z:lent cbr):bigrat { z.real * z.real + z.imag * z.imag }

extend cbr {
    let conj():Self { conj(self) }
    let norm():bigrat { norm(self) }
    let i:Self { (Self){-self.imag, self.real.copy()} }   // z rotated a quarter turn: z times i
}

extend bigrat {
    let i:cbr { (cbr){bigrat(0), self.copy()} }           // r rotated a quarter turn: cbr(0, r)
}

// ---------- functions that are not rational, to a precision (#553) ----------
//
// sqrt, exp, log, pow, the trigonometric and hyperbolic functions and
// their inverses, of a bigrat: seldom rational, so each takes a precision,
// a count of bits after the binary point, and gives a bigrat of 2^precision
// parts within one of them of the true value, 2^-precision:
//
//     sqrt(bigrat(2), 64)      // (26087635650665564425n/18446744073709551616n)
//     exp(bigrat(1))           // e, to bigrat.precision, 128 bits
//     bigrat.pi(256)           // pi to 256 bits
//
// With no precision it is bigrat.precision, 128 bits, some 38 decimal
// digits; one below 0 is 0. The precision is absolute: a large result has
// more bits in all, a small one fewer, down to 0. Each is a method too,
// r.exp(), r.exp(64). What a float answers with an infinity or a NaN, a
// bigrat does too: log(0) is (-1n/0n), sqrt(-1) is (0n/0n).
//
// They are reckoned in BigInts, a number x as the integer x * 2^w, of some
// more bits than asked for, which the rounding at the end takes off: sums
// of series after the argument is brought near 0, exp's by ln 2 and
// halvings, log's by a power of 2, the sine's by pi / 2, atan's by its
// half-angle formula.

extend bigrat {
    static let precision:i64 = 128
}

// the bits of |x|: 0 of 0
let fx_bits(x:lent BigInt):i64 { x.isZero ? 0 : x.abs.bits.count as i64 - 1 }

// r as x * 2^w, cut toward 0; r is finite
let fx_of(r:lent bigrat, w:i64):BigInt { (r.num << w) / r.den }

// x * 2^w as a bigrat of 2^p parts, the nearest; w is above p
let fx_round(x:lent BigInt, w:i64, p:i64):bigrat {
    let n = (x + (BigInt(1) << (w - p - 1))) >> (w - p)
    return bigrat_lowest(n, BigInt(1) << p)
}

// the floor of a / b, b above 0, where BigInt's / cuts toward 0
let fx_floor_div(a:lent BigInt, b:lent BigInt):BigInt {
    let q = a / b
    if a.isNegative && q * b != a { return q - 1 }
    return q
}

// -x where minus is, else x
let fx_signed(x:lent BigInt, minus:bool):BigInt {
    if minus { return 0 - x }
    return x.copy()
}

let fx_nan():bigrat { (bigrat){BigInt(0), BigInt(0)} }
let fx_inf(sign:i64):bigrat { (bigrat){BigInt(sign), BigInt(0)} }

// atan(1 / n) * 2^w, of an integer n of 2 or more: its series
let fx_atan_inv(n:i64, w:i64):BigInt {
    var term = (BigInt(1) << w) / n
    var sum = term.copy()
    var k:i64 = 1
    var minus = true
    while !term.isZero {
        term = term / (n * n)
        let t = term / (2 * k + 1)
        if minus { sum -= t } else { sum += t }
        minus = !minus
        k += 1
    }
    return sum
}

// atanh(1 / n) * 2^w
let fx_atanh_inv(n:i64, w:i64):BigInt {
    var term = (BigInt(1) << w) / n
    var sum = term.copy()
    var k:i64 = 1
    while !term.isZero {
        term = term / (n * n)
        sum += term / (2 * k + 1)
        k += 1
    }
    return sum
}

// pi * 2^w, by Machin's formula, 16 atan(1/5) - 4 atan(1/239)
let fx_pi(w:i64):BigInt {
    let g:i64 = w + 32
    return (fx_atan_inv(5, g) * 16 - fx_atan_inv(239, g) * 4) >> 32
}

// ln 2 * 2^w: 18 atanh(1/26) - 2 atanh(1/4801) + 8 atanh(1/8749)
let fx_ln2(w:i64):BigInt {
    let g:i64 = w + 32
    return (fx_atanh_inv(26, g) * 18 - fx_atanh_inv(4801, g) * 2 + fx_atanh_inv(8749, g) * 8) >> 32
}

// e^x * 2^w of a finite x: x = k ln 2 + r, e^r by its series of r halved
// 12 times and squared back, then shifted by k; the bits a large result
// needs are added, and one below 2^-w is 0. limit says x is past any
// result a BigInt holds, which the caller answers
let fx_exp(x:lent bigrat, w:i64):BigInt {
    let l64 = fx_ln2(64)
    let kb = fx_floor_div((x.num << 65) + x.den * l64, x.den * l64 * 2)   // the nearest k to x / ln 2
    let k:i64 = kb.exactI64 ?? 0
    if k < 0 - w - 2 { return BigInt(0) }
    let g:i64 = w + (k > 0 ? k : 0) + 48
    let r = fx_of(x, g) - ((fx_ln2(g + 64) * k) >> 64)
    let y = r >> 12
    var term = BigInt(1) << g
    var sum = term.copy()
    var n:i64 = 1
    while !term.isZero {
        term = ((term * y) >> g) / n
        sum += term
        n += 1
    }
    for _ in 0..<12 { sum = (sum * sum) >> g }
    return k > 0 ? sum >> 48 : sum >> (48 - k)           // times 2^k, from 2^g parts to 2^w: g is w + k + 48 of a k above 0
}

// whether e^x is past what is reckoned: 2^(2^32) and more, an infinity's
let fx_exp_over(x:lent bigrat):bool { x > bigrat(4294967296) }

// ln x * 2^w of a finite x above 0: x = m 2^e, m from 3/4 to 3/2, and
// ln m = 2 atanh((m - 1) / (m + 1)), its series
let fx_log(x:lent bigrat, w:i64):BigInt {
    let g:i64 = w + 32
    var e:i64 = fx_bits(x.num) - fx_bits(x.den)
    var m = e >= 0 ? (x.num << g) / (x.den << e) : (x.num << (g - e)) / x.den
    let one = BigInt(1) << g
    if m > one + (one >> 1) {
        m = m >> 1
        e += 1
    }
    let below = m < one                                  // atanh is odd: the series of |t|, whose terms end at 0,
    let t = ((below ? one - m : m - one) << g) / (m + one)   // where a negative one's >> would stay at -1
    let t2 = (t * t) >> g
    var term = t.copy()
    var sum = t.copy()
    var k:i64 = 1
    while !term.isZero {
        term = (term * t2) >> g
        sum += term / (2 * k + 1)
        k += 1
    }
    let lm = below ? 0 - (sum << 1) : sum << 1
    return (lm + ((fx_ln2(g + 64) * e) >> 64)) >> 32
}

// sin x * 2^w, or cos x: x = k pi/2 + r, r within pi/4 of 0, and the
// series of sin r and cos r, one of which it is, by k
let fx_sin_cos(x:lent bigrat, w:i64, cosine:bool):BigInt {
    let g:i64 = w + 32
    let e:i64 = fx_bits(x.num) - fx_bits(x.den)
    let eb:i64 = (e > 0 ? e : 0) + 8                     // the bits of k, and some: pi to that many more
    let half = fx_pi(g + eb) >> 1                        // pi / 2
    let xs = fx_of(x, g + eb)
    let k = fx_floor_div((xs << 1) + half, half << 1)
    let r = (xs - k * half) >> eb
    let r2 = (r * r) >> g
    let turn:i64 = (((k % 4) + 4) % 4).exactI64 ?? 0
    let odd = turn == 1 || turn == 3
    var term = cosine == odd ? r.copy() : BigInt(1) << g   // sin r's first term, or cos r's
    var sum = term.copy()
    var n:i64 = cosine == odd ? 2 : 1
    while !term.isZero {
        term = 0 - ((term * r2) >> g) / (n * (n + 1))
        sum += term
        n += 2
    }
    let minus = cosine ? (turn == 1 || turn == 2) : (turn == 2 || turn == 3)
    return minus ? 0 - (sum >> 32) : sum >> 32
}

// atan x * 2^w of a finite x: of -x, of 1 / x where x is above 1, then x
// halved three times, atan x = 2 atan(x / (1 + sqrt(1 + x^2))), its series
let fx_atan(x:lent bigrat, w:i64):BigInt {
    if x.num.isNegative { return 0 - fx_atan(-x, w) }
    if x.num > x.den { return (fx_pi(w + 1) >> 2) - fx_atan(bigrat(x.den, x.num), w) }
    let g:i64 = w + 32
    let one = BigInt(1) << g
    var y = fx_of(x, g)
    for _ in 0..<3 {
        y = (y << g) / (one + (one * one + y * y).isqrt())
    }
    let y2 = (y * y) >> g
    var term = y.copy()
    var sum = y.copy()
    var k:i64 = 1
    var minus = true
    while !term.isZero {
        term = (term * y2) >> g
        let t = term / (2 * k + 1)
        if minus { sum -= t } else { sum += t }
        minus = !minus
        k += 1
    }
    return sum >> 29                                     // times 8, from 2^g parts
}

// the angle of the point (x, y) from the positive x axis, * 2^w, from
// -pi to pi, as C's atan2(y, x); an infinite one counts as 1 beside a
// finite one's 0, so (1/0, 1/0) is pi / 4
let fx_atan2(y0:lent bigrat, x0:lent bigrat, w:i64):BigInt {
    let far = x0.isInfinite || y0.isInfinite
    let x:bigrat = far ? bigrat(x0.isInfinite ? x0.num.sign : 0) : x0.copy()
    let y:bigrat = far ? bigrat(y0.isInfinite ? y0.num.sign : 0) : y0.copy()
    if x.num.isZero {
        if y.num.isZero { return BigInt(0) }
        return y.num.isNegative ? 0 - (fx_pi(w + 1) >> 2) : fx_pi(w + 1) >> 2
    }
    let a = fx_atan(y / x, w)
    if x.num.isNegative { return y.num.isNegative ? a - fx_pi(w) : a + fx_pi(w) }
    return a
}

extend bigrat {
    // pi to a precision
    static let pi(precision:i64):Self {
        let p:i64 = precision > 0 ? precision : 0
        return fx_round(fx_pi(p + 8), p + 8, p)
    }
    static let pi():Self { bigrat.pi(bigrat.precision) }
}

let sqrt(x:lent bigrat, precision:i64):bigrat {
    if x.isNaN || x.num.isNegative { return fx_nan() }
    if x.isInfinite { return fx_inf(1) }
    let p:i64 = precision > 0 ? precision : 0
    return fx_round(((x.num << (2 * p + 16)) / x.den).isqrt(), p + 8, p)
}

let exp(x:lent bigrat, precision:i64):bigrat {
    if x.isNaN { return fx_nan() }
    if x.isInfinite { return x.num.isNegative ? bigrat(0) : fx_inf(1) }
    if fx_exp_over(x) { return fx_inf(1) }
    let p:i64 = precision > 0 ? precision : 0
    return fx_round(fx_exp(x, p + 8), p + 8, p)
}

let log(x:lent bigrat, precision:i64):bigrat {
    if x.isNaN || x.num.isNegative { return fx_nan() }
    if x.isInfinite { return fx_inf(1) }
    if x.num.isZero { return fx_inf(-1) }
    let p:i64 = precision > 0 ? precision : 0
    return fx_round(fx_log(x, p + 8), p + 8, p)
}

let sin(x:lent bigrat, precision:i64):bigrat {
    if !x.isFinite { return fx_nan() }
    let p:i64 = precision > 0 ? precision : 0
    return fx_round(fx_sin_cos(x, p + 8, false), p + 8, p)
}

let cos(x:lent bigrat, precision:i64):bigrat {
    if !x.isFinite { return fx_nan() }
    let p:i64 = precision > 0 ? precision : 0
    return fx_round(fx_sin_cos(x, p + 8, true), p + 8, p)
}

// sin x / cos x, with the bits a cosine near 0 takes: it is reckoned
// anew with twice as many more as the cosine has zeros after its point
let tan(x:lent bigrat, precision:i64):bigrat {
    if !x.isFinite { return fx_nan() }
    let p:i64 = precision > 0 ? precision : 0
    var g:i64 = p + 40
    while true {
        let c = fx_sin_cos(x, g, true)
        let zeros:i64 = g - fx_bits(c)
        if g >= p + 2 * zeros + 16 {
            return fx_round((fx_sin_cos(x, g, false) << g) / c, g, p)
        }
        g = p + 2 * zeros + 48
    }
    return fx_nan()
}

let atan(x:lent bigrat, precision:i64):bigrat {
    if x.isNaN { return fx_nan() }
    let p:i64 = precision > 0 ? precision : 0
    if x.isInfinite {
        let h = fx_pi(p + 9) >> 2                        // pi / 2
        return fx_round(fx_signed(h, x.num.isNegative), p + 8, p)
    }
    return fx_round(fx_atan(x, p + 8), p + 8, p)
}

let atan2(y:lent bigrat, x:lent bigrat, precision:i64):bigrat {
    if x.isNaN || y.isNaN { return fx_nan() }
    let p:i64 = precision > 0 ? precision : 0
    return fx_round(fx_atan2(y, x, p + 8), p + 8, p)
}

// asin x * 2^w, x from -1 to 1: the angle of (sqrt(1 - x^2), x)
let fx_asin(x:lent bigrat, w:i64):BigInt {
    let g:i64 = w + 16
    let rest = bigrat(1) - x * x
    let s = bigrat(((rest.num << (2 * g)) / rest.den).isqrt(), BigInt(1) << g)
    return fx_atan2(x, s, w)
}

let asin(x:lent bigrat, precision:i64):bigrat {
    if !x.isFinite || x.num.abs > x.den { return fx_nan() }
    let p:i64 = precision > 0 ? precision : 0
    return fx_round(fx_asin(x, p + 8), p + 8, p)
}

let acos(x:lent bigrat, precision:i64):bigrat {
    if !x.isFinite || x.num.abs > x.den { return fx_nan() }
    let p:i64 = precision > 0 ? precision : 0
    return fx_round((fx_pi(p + 9) >> 2) - fx_asin(x, p + 8), p + 8, p)   // pi / 2, less it
}

// (e^x - e^-x) / 2 and (e^x + e^-x) / 2, by e^|x|
let sinh(x:lent bigrat, precision:i64):bigrat {
    if x.isNaN { return fx_nan() }
    if x.isInfinite || fx_exp_over(x) || fx_exp_over(-x) { return fx_inf(x.num.sign) }
    let p:i64 = precision > 0 ? precision : 0
    let g:i64 = p + 8
    let e = fx_exp(x.num.isNegative ? -x : x.copy(), g)
    let h = (e - (BigInt(1) << (2 * g)) / e) >> 1
    return fx_round(fx_signed(h, x.num.isNegative), g, p)
}

let cosh(x:lent bigrat, precision:i64):bigrat {
    if x.isNaN { return fx_nan() }
    if x.isInfinite || fx_exp_over(x) || fx_exp_over(-x) { return fx_inf(1) }
    let p:i64 = precision > 0 ? precision : 0
    let g:i64 = p + 8
    let e = fx_exp(x.num.isNegative ? -x : x.copy(), g)
    return fx_round((e + (BigInt(1) << (2 * g)) / e) >> 1, g, p)
}

// (1 - t) / (1 + t) of t = e^(-2|x|), which is 1 at most
let tanh(x:lent bigrat, precision:i64):bigrat {
    if x.isNaN { return fx_nan() }
    if x.isInfinite { return bigrat(x.num.sign) }
    let p:i64 = precision > 0 ? precision : 0
    let g:i64 = p + 8
    let one = BigInt(1) << g
    let t = fx_exp((x.num.isNegative ? x.copy() : -x) * 2, g)
    let h = ((one - t) << g) / (one + t)
    return fx_round(fx_signed(h, x.num.isNegative), g, p)
}

// ln(|x| + sqrt(x^2 + 1)), with x's sign
let asinh(x:lent bigrat, precision:i64):bigrat {
    if x.isNaN { return fx_nan() }
    if x.isInfinite { return fx_inf(x.num.sign) }
    let p:i64 = precision > 0 ? precision : 0
    let g:i64 = p + 16
    let a:bigrat = x.num.isNegative ? -x : x.copy()
    let sq = a * a + 1
    let u = bigrat(fx_of(a, g) + ((sq.num << (2 * g)) / sq.den).isqrt(), BigInt(1) << g)
    let h = fx_log(u, p + 8)
    return fx_round(fx_signed(h, x.num.isNegative), p + 8, p)
}

// ln(x + sqrt(x^2 - 1)), of x of 1 or more
let acosh(x:lent bigrat, precision:i64):bigrat {
    if x.isNaN || x < bigrat(1) { return fx_nan() }
    if x.isInfinite { return fx_inf(1) }
    let p:i64 = precision > 0 ? precision : 0
    let g:i64 = p + 16
    let sq = x * x - 1
    let u = bigrat(fx_of(x, g) + ((sq.num << (2 * g)) / sq.den).isqrt(), BigInt(1) << g)
    return fx_round(fx_log(u, p + 8), p + 8, p)
}

// ln((1 + x) / (1 - x)) / 2, of x between -1 and 1; of 1 and -1 infinite
let atanh(x:lent bigrat, precision:i64):bigrat {
    if !x.isFinite || x.num.abs > x.den { return fx_nan() }
    if x.num.abs == x.den { return fx_inf(x.num.sign) }
    let p:i64 = precision > 0 ? precision : 0
    return fx_round(fx_log((bigrat(1) + x) / (bigrat(1) - x), p + 9) >> 2, p + 8, p)
}

// x to the y: of a whole y the power itself, rounded; else e^(y ln x), of
// x above 0, with the bits a large power takes; 0 to a y above 0 is 0, to
// 0 it is 1, and below 0 infinite; a negative x to a y not whole is a NaN
let pow(x:lent bigrat, y:lent bigrat, precision:i64):bigrat {
    if x.isNaN || y.isNaN { return fx_nan() }
    let p:i64 = precision > 0 ? precision : 0
    if y.num.isZero { return bigrat(1) }
    if x.num.isZero && x.isFinite { return y.num.isNegative ? fx_inf(1) : bigrat(0) }
    if y.isFinite && x.isFinite && y.den == 1 {
        if let n = y.num.abs.exactI64 {
            if n <= 65536 {
                let up:bigrat = (bigrat){x.num ** n, x.den ** n}
                let v:bigrat = y.num.isNegative ? bigrat(1) / up : up.copy()
                return fx_round(fx_of(v, p + 2), p + 2, p)
            }
        }
    }
    if x.num.isNegative { return fx_nan() }
    if x.isInfinite { return y.num.isNegative ? bigrat(0) : fx_inf(1) }
    if y.isInfinite {
        let grows = (x > bigrat(1)) == !y.num.isNegative
        return x == bigrat(1) ? bigrat(1) : grows ? fx_inf(1) : bigrat(0)
    }
    let rough = y * bigrat(fx_log(x, 64), BigInt(1) << 64)   // y ln x, about: how large the power is
    if fx_exp_over(rough) { return fx_inf(1) }
    let size:i64 = (rough.num / rough.den).exactI64 ?? 0
    let wl:i64 = p + (size > 0 ? 2 * size : 0) + fx_bits(y.num) + 64
    return exp(y * bigrat(fx_log(x, wl), BigInt(1) << wl), p)
}

// each with bigrat.precision where none is written
let sqrt(x:lent bigrat):bigrat { sqrt(x, bigrat.precision) }
let exp(x:lent bigrat):bigrat { exp(x, bigrat.precision) }
let log(x:lent bigrat):bigrat { log(x, bigrat.precision) }
let sin(x:lent bigrat):bigrat { sin(x, bigrat.precision) }
let cos(x:lent bigrat):bigrat { cos(x, bigrat.precision) }
let tan(x:lent bigrat):bigrat { tan(x, bigrat.precision) }
let asin(x:lent bigrat):bigrat { asin(x, bigrat.precision) }
let acos(x:lent bigrat):bigrat { acos(x, bigrat.precision) }
let atan(x:lent bigrat):bigrat { atan(x, bigrat.precision) }
let atan2(y:lent bigrat, x:lent bigrat):bigrat { atan2(y, x, bigrat.precision) }
let sinh(x:lent bigrat):bigrat { sinh(x, bigrat.precision) }
let cosh(x:lent bigrat):bigrat { cosh(x, bigrat.precision) }
let tanh(x:lent bigrat):bigrat { tanh(x, bigrat.precision) }
let asinh(x:lent bigrat):bigrat { asinh(x, bigrat.precision) }
let acosh(x:lent bigrat):bigrat { acosh(x, bigrat.precision) }
let atanh(x:lent bigrat):bigrat { atanh(x, bigrat.precision) }
let pow(x:lent bigrat, y:lent bigrat):bigrat { pow(x, y, bigrat.precision) }

extend bigrat {
    // each function as a method, r.exp(), r.exp(64)
    let sqrt():Self { sqrt(self) }
    let sqrt(precision:i64):Self { sqrt(self, precision) }
    let exp():Self { exp(self) }
    let exp(precision:i64):Self { exp(self, precision) }
    let log():Self { log(self) }
    let log(precision:i64):Self { log(self, precision) }
    let sin():Self { sin(self) }
    let sin(precision:i64):Self { sin(self, precision) }
    let cos():Self { cos(self) }
    let cos(precision:i64):Self { cos(self, precision) }
    let tan():Self { tan(self) }
    let tan(precision:i64):Self { tan(self, precision) }
    let asin():Self { asin(self) }
    let asin(precision:i64):Self { asin(self, precision) }
    let acos():Self { acos(self) }
    let acos(precision:i64):Self { acos(self, precision) }
    let atan():Self { atan(self) }
    let atan(precision:i64):Self { atan(self, precision) }
    let atan2(x:lent Self):Self { atan2(self, x) }
    let atan2(x:lent Self, precision:i64):Self { atan2(self, x, precision) }
    let sinh():Self { sinh(self) }
    let sinh(precision:i64):Self { sinh(self, precision) }
    let cosh():Self { cosh(self) }
    let cosh(precision:i64):Self { cosh(self, precision) }
    let tanh():Self { tanh(self) }
    let tanh(precision:i64):Self { tanh(self, precision) }
    let asinh():Self { asinh(self) }
    let asinh(precision:i64):Self { asinh(self, precision) }
    let acosh():Self { acosh(self) }
    let acosh(precision:i64):Self { acosh(self, precision) }
    let atanh():Self { atanh(self) }
    let atanh(precision:i64):Self { atanh(self, precision) }
    let pow(y:lent Self):Self { pow(self, y) }
    let pow(y:lent Self, precision:i64):Self { pow(self, y, precision) }
}
