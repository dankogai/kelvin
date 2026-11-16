// modules/math+BigFloat.k - the overlay of math with BigFloat (#580): read
// where <math> and <BigFloat> are both imported, and by no program that
// imports one of them alone. math's functions take a BigFloat:
//
//     #import <math>
//     #import <BigFloat>
//     println(sqrt(BigFloat(2)), " ", exp(BigFloat(1)), " ", BigFloat.pi())
//
// sqrt, exp, log, pow, sin, cos, tan, asin, acos, atan, atan2, sinh, cosh,
// tanh, asinh, acosh and atanh, each a method too, x.exp(), and
// BigFloat.pi(). A result has BigFloat.precision significant bits, as
// every BigFloat's, or the precision written after the argument,
// exp(x, 256): the nearest to the true value, or where that is all but
// midway between two, one of them. sqrt's is always the nearest.
//
// They are a BigRat's (math+Rational.k), which are within 2^-w of the true
// value for a w of bits after the point: w is taken so that the bits
// asked for are good, and 8 more, whatever the size of the result. An
// infinity and a NaN come where a BigRat's function gives one, which is
// where a float's does: log(0) is -inf, sqrt(-1) a NaN.
//
// And CBF, a complex number of two BigFloats, also complexBigFloat by
// its alias (#581), below: its + - * /, each part the exact one's rounded
// once, conj, norm, z.i and x.i, z.round, and its text, a c64's; and
// math's functions of a CBF (#582), last.
#import <math>
#import <Rational>
#import <math+Rational>         // a BigRat's functions, read before this whichever import a program writes first
#import <BigFloat>

// ---------- by a BigRat's function ----------

// the function numbered f of a BigRat, and of y where it takes two,
// within 2^-w
let BigFloat_function(f:i64, x:lent BigRat, y:lent BigRat, w:i64):BigRat {
    if f == 1 { return exp(x, w) }
    if f == 2 { return log(x, w) }
    if f == 3 { return sin(x, w) }
    if f == 4 { return cos(x, w) }
    if f == 5 { return tan(x, w) }
    if f == 6 { return asin(x, w) }
    if f == 7 { return acos(x, w) }
    if f == 8 { return atan(x, w) }
    if f == 9 { return atan2(x, y, w) }
    if f == 10 { return sinh(x, w) }
    if f == 11 { return cosh(x, w) }
    if f == 12 { return tanh(x, w) }
    if f == 13 { return asinh(x, w) }
    if f == 14 { return acosh(x, w) }
    if f == 15 { return atanh(x, w) }
    return pow(x, y, w)
}

// a rational within 2^-w of a value, as a BigFloat of bits bits where
// that many of its bits are good and 8 more; else what w would make them
// so, in again. A 0 says the value is below 2^-w: w is doubled
let BigFloat_good(r:lent BigRat, w:i64, bits:i64, again:i64^):BigFloat {
    again^ = 0
    if !r.isFinite { return BigFloat(r, bits) }
    if r.num.isZero {
        again^ = w * 2
        return BigFloat_zero()
    }
    let top:i64 = BigFloat_length(r.num) - BigFloat_length(r.den)    // |r| is 2^(top - 1) at the least
    if w + top - 1 >= bits + 8 { return BigFloat(r, bits) }
    again^ = bits + 16 - top
    return BigFloat_zero()
}

// f of x, and of y, to bits significant bits. exact says a 0 is the
// value itself, as of an infinity's function, and no value below 2^-w
let BigFloat_by(f:i64, x:lent BigFloat, y:lent BigFloat, bits:i64, exact:bool):BigFloat {
    let rx = BigRat(x)
    let ry = BigRat(y)
    var w:i64 = bits + 32
    var again:i64 = 0
    var r = BigFloat_good(BigFloat_function(f, rx, ry, w), w, bits, &again)
    while again != 0 && !exact && again < 67108864 {
        w = again
        r = BigFloat_good(BigFloat_function(f, rx, ry, w), w, bits, &again)
    }
    return r
}

// the power of 2 above |x|: |x| is below 2^top, and 2^(top - 1) at the
// least; x is finite and not 0
let BigFloat_top(x:lent BigFloat):i128 { x.exponent as i128 + BigFloat_length(x.mantissa) as i128 }

// sin, tan, asin, atan, sinh, tanh, asinh and atanh of an x near 0 are
// x, less or more a part of it below x^2: where that is below the last
// bit by 2 places it is x, rounded
let BigFloat_small(x:lent BigFloat, bits:i64):bool {
    return x.special == 0 && (x.mantissa.isZero || 2 * BigFloat_top(x) < 0 - bits as i128 - 2)
}

// one of them, numbered f
let BigFloat_odd(f:i64, x:lent BigFloat, bits:i64):BigFloat {
    if BigFloat_small(x, bits) { return BigFloat_make(x.mantissa, x.exponent as i128, bits, 0) }
    return BigFloat_by(f, x, x, bits, x.special != 0)
}

// ---------- numbers no rational is made of (#583) ----------
//
// A function is a BigRat's of BigRat(x), which is as long as x's
// exponent is large: of 2^-1000000000000 it has that many bits. So no
// function makes one of a number far from 1. Near 0 a function is its
// first term, x or 1, and far out its limit, half of pi, or a log; out
// of its domain it is a NaN. A sine, a cosine and a tangent have no
// limit, and pi is not had to as many bits as the number has: of a
// number of 2^67108864 and more they are NaNs, past reckoning.

// whether x is 2^67108864 and more in size
let BigFloat_past(x:lent BigFloat):bool {
    return x.special == 0 && !x.mantissa.isZero && BigFloat_top(x) > 67108864
}

// whether |x| is 2 and more
let BigFloat_two_up(x:lent BigFloat):bool {
    return x.special == 0 && !x.mantissa.isZero && BigFloat_top(x) > 1
}

// a number that stands for x where only its sign, whether it is above
// 1 in size and whether it is whole matter, as beside a 0 or an
// infinity: 2 or a half with x's sign, of an x past 2^64 or below 2^-64
let BigFloat_stand(x:lent BigFloat):BigFloat {
    if x.special != 0 || x.mantissa.isZero { return x.copy() }
    let top:i128 = BigFloat_top(x)
    if top > 64 { return (BigFloat){BigInt(x.mantissa.sign), 1, 0} }
    if top < 0 - 64 { return (BigFloat){BigInt(x.mantissa.sign), 0 - 1, 0} }
    return x.copy()
}

// pi times 2^shift to bits bits, or less it
let BigFloat_pi_times(shift:i64, bits:i64, minus:bool):BigFloat {
    let p = BigFloat(BigRat.pi(bits + 8), bits)
    let r:BigFloat = (BigFloat){p.mantissa.copy(), p.exponent + shift, 0}
    if minus { return -r }
    return r
}

// ln(2|x|), which asinh and acosh of a large x are, less or more a
// part below 1 / x^2
let BigFloat_log_twice(x:lent BigFloat, bits:i64):BigFloat {
    return BigFloat_log((BigFloat){x.mantissa.abs, x.exponent + 1, 0}, bits)
}

// ---------- sqrt, exp, log and pow ----------

// the square root, the nearest: the mantissa shifted so that the
// exponent is even and its whole root has bits + 2 bits, and one bit more
// below them where the root is not whole, which the rounding reads
let BigFloat_sqrt(x:lent BigFloat, bits:i64):BigFloat {
    if x.special == 2 || x.mantissa.isNegative { return BigFloat_nan() }
    if x.special == 1 { return BigFloat_inf(1) }
    if x.mantissa.isZero { return BigFloat_zero() }
    var s:i64 = 2 * bits + 4 - BigFloat_length(x.mantissa)
    if s < 0 { s = 0 }
    var e:i128 = x.exponent as i128 - s as i128
    if e % 2 != 0 {
        s += 1
        e -= 1
    }
    let big = x.mantissa << s
    var r = big.isqrt()
    var half:i128 = e / 2
    if r * r != big {
        r = (r << 1) + 1
        half -= 1
    }
    return BigFloat_make(r, half, bits, 0)
}

// e^x: x is k times ln 2 and a rest of no more than half of ln 2, so
// e^x is e^rest, near 1, times 2^k; no bits are spent on its size, and
// one past any exponent is an infinity, or 0
let BigFloat_exp(x:lent BigFloat, bits:i64):BigFloat {
    if x.special != 0 { return BigFloat_by(1, x, x, bits, true) }
    if x.mantissa.isZero { return BigFloat(1, bits) }
    let top = BigFloat_top(x)
    if top > 62 {
        if x.mantissa.isNegative { return BigFloat_zero() }
        return BigFloat_inf(1)
    }
    if top < 0 - bits as i128 - 2 { return BigFloat(1, bits) }   // 1 + x rounds to 1
    let w:i64 = bits + 32
    let ln2 = log(BigRat(2), w + 70)
    let rx = BigRat(x)
    let q = rx / ln2
    let k = fx_floor_div(q.num * 2 + q.den, q.den * 2)      // the nearest whole number to x / ln 2
    let rest = rx - BigRat(k) * ln2
    let m = BigFloat(exp(rest, w), bits)
    return BigFloat_make(m.mantissa, m.exponent as i128 + k.i64 as i128, bits, 0)
}

// ln of m * 2^e, m above 0 and odd: it is s * 2^t, s from 1 up to 2,
// so its log is ln s and t times ln 2; near 1 the two all but cancel, and
// more bits are taken. e is of any size, as a norm's is, which is of the
// square of a part (#586)
let BigFloat_log_of(m:lent BigInt, e:i128, bits:i64):BigFloat {
    let n = BigFloat_length(m)
    let t:i128 = e + n as i128 - 1
    if n == 1 && t == 0 { return BigFloat_zero() }
    let s:BigRat = (BigRat){m.copy(), BigInt(1) << (n - 1)}
    var w:i64 = bits + 32
    var again:i64 = 0
    var r = BigFloat_zero()
    while true {
        var sum = log(s, w + 2)
        if t != 0 { sum = sum + BigRat(BigInt(t)) * log(BigRat(2), w + 70) }
        r = BigFloat_good(sum, w, bits, &again)
        if again == 0 || again >= 67108864 { break }
        w = again
    }
    return r
}

// ln x
let BigFloat_log(x:lent BigFloat, bits:i64):BigFloat {
    if x.special == 0 && x.mantissa.isNegative { return BigFloat_nan() }
    if x.special != 0 || x.mantissa.isZero { return BigFloat_by(2, x, x, bits, true) }
    return BigFloat_log_of(x.mantissa, x.exponent as i128, bits)
}

// x to the y: e^(y ln x) of an x above 0; of a negative x and a whole
// y it is of |x|, with the sign where y is odd, and of one not whole a
// NaN; of a 0, an infinity or a NaN, a BigRat's, which reads no more of
// the other than its sign, its size beside 1 and whether it is whole
let BigFloat_pow(x:lent BigFloat, y:lent BigFloat, bits:i64):BigFloat {
    if x.special != 0 || y.special != 0 || x.mantissa.isZero || y.mantissa.isZero {
        return BigFloat_by(16, BigFloat_stand(x), BigFloat_stand(y), bits, true)
    }
    if x.mantissa.isNegative {
        if y.exponent < 0 { return BigFloat_nan() }         // a mantissa is odd: whole is an exponent of 0 or more
        let r = BigFloat_pow(-x, y, bits)
        if y.exponent == 0 { return -r }
        return r
    }
    let p:i64 = bits + 80
    let l = BigFloat_log(x, p)
    if l.mantissa.isZero { return BigFloat(1, bits) }
    let z = BigFloat_make(y.mantissa * l.mantissa, y.exponent as i128 + l.exponent as i128, p, 0)
    return BigFloat_exp(z, bits)
}

// sinh, cosh and tanh, numbered 10, 11 and 12: of an x from 1 up by
// e^|x| and what it is 1 over, with no bits spent on its size; below 1 a
// BigRat's, which does not lose the bits that cancel
let BigFloat_hyper(f:i64, x:lent BigFloat, bits:i64):BigFloat {
    if x.special != 0 { return BigFloat_by(f, x, x, bits, true) }
    if x.mantissa.isZero || BigFloat_top(x) < 1 {
        if f == 11 {
            if BigFloat_small(x, bits) { return BigFloat(1, bits) }     // cosh x is 1 and a part below x^2
            return BigFloat_by(f, x, x, bits, false)
        }
        return BigFloat_odd(f, x, bits)
    }
    let negative = x.mantissa.isNegative
    let p:i64 = bits + 16
    let size:BigFloat = (BigFloat){x.mantissa.abs, x.exponent, 0}
    let e = BigFloat_exp(size, p)
    if e.special == 1 {
        if f == 12 { return BigFloat_make(BigInt(negative ? -1 : 1), 0, bits, 0) }
        return BigFloat_inf(negative && f == 10 ? -1 : 1)
    }
    let inv = BigFloat_quotient(BigInt(1), e.mantissa, 0 - e.exponent as i128, p, 0)
    let less = BigFloat_sum(e, -inv, p)
    let more = BigFloat_sum(e, inv, p)
    if f == 11 { return BigFloat_make(more.mantissa, more.exponent as i128 - 1, bits, 0) }
    if f == 10 {
        let half = BigFloat_make(less.mantissa, less.exponent as i128 - 1, bits, 0)
        if negative { return -half }
        return half
    }
    let t = BigFloat_quotient(less.mantissa, more.mantissa, less.exponent as i128 - more.exponent as i128, bits, 0)
    if negative { return -t }
    return t
}

// ---------- the functions, to a precision ----------

let sqrt(x:lent BigFloat, precision:i64):BigFloat { BigFloat_sqrt(x, precision < 1 ? 1 : precision) }
let exp(x:lent BigFloat, precision:i64):BigFloat { BigFloat_exp(x, precision < 1 ? 1 : precision) }
let log(x:lent BigFloat, precision:i64):BigFloat { BigFloat_log(x, precision < 1 ? 1 : precision) }
let pow(x:lent BigFloat, y:lent BigFloat, precision:i64):BigFloat { BigFloat_pow(x, y, precision < 1 ? 1 : precision) }
let sin(x:lent BigFloat, precision:i64):BigFloat {
    if BigFloat_past(x) { return BigFloat_nan() }
    return BigFloat_odd(3, x, precision < 1 ? 1 : precision)
}
// cos x is 1 and a part below x^2
let cos(x:lent BigFloat, precision:i64):BigFloat {
    let bits:i64 = precision < 1 ? 1 : precision
    if BigFloat_past(x) { return BigFloat_nan() }
    if BigFloat_small(x, bits) { return BigFloat(1, bits) }
    return BigFloat_by(4, x, x, bits, x.special != 0)
}
let tan(x:lent BigFloat, precision:i64):BigFloat {
    if BigFloat_past(x) { return BigFloat_nan() }
    return BigFloat_odd(5, x, precision < 1 ? 1 : precision)
}
// asin, acos and atanh are of -1 to 1
let asin(x:lent BigFloat, precision:i64):BigFloat {
    if BigFloat_two_up(x) { return BigFloat_nan() }
    return BigFloat_odd(6, x, precision < 1 ? 1 : precision)
}
// acos(1) is 0, and so is acosh(1); acos of an x near 0 is half of pi
// less x
let acos(x:lent BigFloat, precision:i64):BigFloat {
    let bits:i64 = precision < 1 ? 1 : precision
    if BigFloat_two_up(x) { return BigFloat_nan() }
    if x.special == 0 && !x.mantissa.isZero && BigFloat_top(x) < 0 - bits as i128 - 8 { return BigFloat_pi_times(0 - 1, bits, false) }
    return BigFloat_by(7, x, x, bits, x.special != 0 || x == BigFloat(1))
}
// atan of a large x is half of pi, with its sign, less 1 / x
let atan(x:lent BigFloat, precision:i64):BigFloat {
    let bits:i64 = precision < 1 ? 1 : precision
    if x.special == 0 && !x.mantissa.isZero && BigFloat_top(x) > bits as i128 + 8 { return BigFloat_pi_times(0 - 1, bits, x.mantissa.isNegative) }
    return BigFloat_odd(8, x, bits)
}
// of a y that is 0 it is 0 or pi, by the sign of x. It is of y over
// x: where that is far below 1 it is the quotient, right of 0, and pi
// with y's sign left of it; where far above, half of pi; else the two
// are brought near 1 together, which the angle does not see. Beside a
// 0, an infinity or a NaN the other is read for its sign alone
let atan2(y:lent BigFloat, x:lent BigFloat, precision:i64):BigFloat {
    let bits:i64 = precision < 1 ? 1 : precision
    if y.special != 0 || x.special != 0 || y.mantissa.isZero || x.mantissa.isZero {
        let exact = y.special != 0 || x.special != 0 || (y.mantissa.isZero && !x.mantissa.isNegative)
        return BigFloat_by(9, BigFloat_stand(y), BigFloat_stand(x), bits, exact)
    }
    let apart:i128 = BigFloat_top(y) - BigFloat_top(x)
    if apart > bits as i128 + 8 { return BigFloat_pi_times(0 - 1, bits, y.mantissa.isNegative) }
    if apart < 0 - bits as i128 - 8 {
        if x.mantissa.isNegative { return BigFloat_pi_times(0, bits, y.mantissa.isNegative) }
        return BigFloat_quotient(y.mantissa, x.mantissa, y.exponent as i128 - x.exponent as i128, bits, 0)
    }
    let yy:BigFloat = (BigFloat){y.mantissa.copy(), (y.exponent as i128 - x.exponent as i128) as i64, 0}
    let xx:BigFloat = (BigFloat){x.mantissa.copy(), 0, 0}
    return BigFloat_by(9, yy, xx, bits, false)
}
let sinh(x:lent BigFloat, precision:i64):BigFloat { BigFloat_hyper(10, x, precision < 1 ? 1 : precision) }
let cosh(x:lent BigFloat, precision:i64):BigFloat { BigFloat_hyper(11, x, precision < 1 ? 1 : precision) }
let tanh(x:lent BigFloat, precision:i64):BigFloat { BigFloat_hyper(12, x, precision < 1 ? 1 : precision) }
// asinh of a large x is ln(2|x|), with its sign
let asinh(x:lent BigFloat, precision:i64):BigFloat {
    let bits:i64 = precision < 1 ? 1 : precision
    if x.special == 0 && !x.mantissa.isZero && 2 * BigFloat_top(x) > bits as i128 + 8 {
        let l = BigFloat_log_twice(x, bits)
        if x.mantissa.isNegative { return -l }
        return l
    }
    return BigFloat_odd(13, x, bits)
}
// acosh is of 1 and more, and of a large x ln(2x)
let acosh(x:lent BigFloat, precision:i64):BigFloat {
    let bits:i64 = precision < 1 ? 1 : precision
    if x.special == 0 && !x.mantissa.isZero {
        if x.mantissa.isNegative || BigFloat_top(x) < 1 { return BigFloat_nan() }
        if 2 * BigFloat_top(x) > bits as i128 + 8 { return BigFloat_log_twice(x, bits) }
    }
    return BigFloat_by(14, x, x, bits, x.special != 0 || x == BigFloat(1))
}
let atanh(x:lent BigFloat, precision:i64):BigFloat {
    if BigFloat_two_up(x) { return BigFloat_nan() }
    return BigFloat_odd(15, x, precision < 1 ? 1 : precision)
}

// each with BigFloat.precision where none is written
let sqrt(x:lent BigFloat):BigFloat { sqrt(x, BigFloat.precision) }
let exp(x:lent BigFloat):BigFloat { exp(x, BigFloat.precision) }
let log(x:lent BigFloat):BigFloat { log(x, BigFloat.precision) }
let pow(x:lent BigFloat, y:lent BigFloat):BigFloat { pow(x, y, BigFloat.precision) }
let sin(x:lent BigFloat):BigFloat { sin(x, BigFloat.precision) }
let cos(x:lent BigFloat):BigFloat { cos(x, BigFloat.precision) }
let tan(x:lent BigFloat):BigFloat { tan(x, BigFloat.precision) }
let asin(x:lent BigFloat):BigFloat { asin(x, BigFloat.precision) }
let acos(x:lent BigFloat):BigFloat { acos(x, BigFloat.precision) }
let atan(x:lent BigFloat):BigFloat { atan(x, BigFloat.precision) }
let atan2(y:lent BigFloat, x:lent BigFloat):BigFloat { atan2(y, x, BigFloat.precision) }
let sinh(x:lent BigFloat):BigFloat { sinh(x, BigFloat.precision) }
let cosh(x:lent BigFloat):BigFloat { cosh(x, BigFloat.precision) }
let tanh(x:lent BigFloat):BigFloat { tanh(x, BigFloat.precision) }
let asinh(x:lent BigFloat):BigFloat { asinh(x, BigFloat.precision) }
let acosh(x:lent BigFloat):BigFloat { acosh(x, BigFloat.precision) }
let atanh(x:lent BigFloat):BigFloat { atanh(x, BigFloat.precision) }

extend BigFloat {
    // pi to a precision: its bits after the point are 2 fewer
    static let pi(precision:i64):Self {
        let p:i64 = precision < 1 ? 1 : precision
        return BigFloat(BigRat.pi(p + 8), p)
    }
    static let pi():Self { BigFloat.pi(BigFloat.precision) }

    // each function as a method, x.exp(), x.exp(64)
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

// ---------- CBF, a complex number of BigFloats (#581) ----------
//
// CBF is a complex number whose parts are BigFloats, also
// complexBigFloat by its alias, as CBR is complexBigRat:
//
//     let z = CBF(1, 2) / CBF(3, 4)        // (0.44+0.08.i), each part to 128 bits
//
// Each part of a result of + - * / is the exact one's, rounded to
// BigFloat.precision bits, the nearest and of two as near the even one,
// as a BigFloat's is: nothing is lost where the products all but cancel,
// and z * w is CBF(CBR(z) * CBR(w)). An infinity and a NaN in a part are
// as a CBR's (#571 to #574): z / 0 is infinite, a part that is 0 staying 0.
struct CBF {
    real: BigFloat
    imag: BigFloat
}

// the same by what it is of, as an alias, as complexBigRat is CBR's
typealias complexBigFloat = CBF

// ---------- making one ----------

let CBF(real:lent BigFloat, imag:lent BigFloat):CBF { (CBF){real.copy(), imag.copy()} }
let CBF(real:lent BigFloat):CBF { (CBF){real.copy(), BigFloat_zero()} }
let CBF(real:lent BigInt, imag:lent BigInt):CBF { (CBF){BigFloat(real), BigFloat(imag)} }
let CBF(real:lent BigInt):CBF { (CBF){BigFloat(real), BigFloat_zero()} }
let CBF(real:i64, imag:i64):CBF { (CBF){BigFloat(real), BigFloat(imag)} }
let CBF(real:i64):CBF { (CBF){BigFloat(real), BigFloat_zero()} }
let CBF(real:f64, imag:f64):CBF { (CBF){BigFloat(real), BigFloat(imag)} }
let CBF(real:f64):CBF { (CBF){BigFloat(real), BigFloat_zero()} }

// of a c64 and of a CBR, each part the nearest of BigFloat.precision bits,
// or of the precision written
let CBF(z:c64, precision:i64):CBF { (CBF){BigFloat(z.real, precision), BigFloat(z.imag, precision)} }
let CBF(z:c64):CBF { (CBF){BigFloat(z.real), BigFloat(z.imag)} }
let CBF(z:lent CBR, precision:i64):CBF { (CBF){BigFloat(z.real, precision), BigFloat(z.imag, precision)} }
let CBF(z:lent CBR):CBF { (CBF){BigFloat(z.real), BigFloat(z.imag)} }

// a CBF as a CBR, exactly, and the nearest c64
let CBR(z:lent CBF):CBR { (CBR){BigRat(z.real), BigRat(z.imag)} }
let c64(z:lent CBF):c64 { (c64){z.real.f64, z.imag.f64} }

// ---------- of text ----------

// the part at text[at], which complex_float found: inf, infinity or
// nan in either case, with a sign or none, or what BigFloat(text) reads,
// a decimal or a hex float
let CBF_piece(text:cstr, at:i64, precision:i64):BigFloat {
    var i:i64 = at
    var negative = false
    if text[i] == '+' as u8 || text[i] == '-' as u8 {
        negative = text[i] == '-' as u8
        i += 1
    }
    if complex_word(text, i, "inf", true) { return BigFloat_inf(negative ? -1 : 1) }
    if complex_word(text, i, "nan", true) { return BigFloat_nan() }
    let end = complex_float(text, at)
    var s = $""
    for j in at..<end { s += text[j] }
    return BigFloat_read(s.cstr, precision)
}

// whether the part at text[at] is a nan written so
let CBF_nan_at(text:cstr, at:i64):bool {
    var i:i64 = at
    if text[i] == '+' as u8 || text[i] == '-' as u8 { i += 1 }
    return complex_word(text, i, "nan", true)
}

// a CBF of its text, to precision bits in each part: what print writes,
// (0.1-0.2.i), z.dec's, (+0.1-0.2.i), and z.hex's, (+0x1.8p+0-0x1p+1.i), as
// a c64's is laid out and read (#569): with the parentheses or with none,
// a part alone, 1.5 or 2.0.i, spaces about the sign that joins. A part is
// read as BigFloat(text) reads it. Text that is none is an error, a NaN
// in both parts
let CBF_read(text:cstr, precision:i64):CBF {
    let at = complex_layout(text)
    if at.end < 0 { return (CBF){BigFloat_nan(), BigFloat_nan()} }
    var real = BigFloat_zero()
    var imag = BigFloat_zero()
    if at.real >= 0 {
        real = CBF_piece(text, at.real, precision)
        if real.special == 2 && !CBF_nan_at(text, at.real) { return (CBF){BigFloat_nan(), BigFloat_nan()} }
    }
    if at.imag >= 0 {
        let v = CBF_piece(text, at.imag, precision)
        if v.special == 2 && !CBF_nan_at(text, at.imag) { return (CBF){BigFloat_nan(), BigFloat_nan()} }
        if at.negative {
            imag = -v
        } else {
            imag = v.copy()
        }
    }
    return (CBF){real.copy(), imag.copy()}
}
let CBF(text:cstr, precision:i64):CBF { CBF_read(text, precision < 1 ? 1 : precision) }
let CBF(text:cstr):CBF { CBF_read(text, BigFloat_bits()) }
let CBF(text:const String^, precision:i64):CBF { CBF_read(text^.cstr, precision < 1 ? 1 : precision) }
let CBF(text:const String^):CBF { CBF_read(text^.cstr, BigFloat_bits()) }

// ---------- sums of products, exactly ----------

// m * 2^e, exactly: a product of two parts, which no BigFloat need hold
struct CBF_term {
    m: BigInt
    e: i128
}

let CBF_none():CBF_term { (CBF_term){BigInt(0), 0} }

// x times y, or less it
let CBF_times(x:lent BigFloat, y:lent BigFloat, minus:bool):CBF_term {
    let m = x.mantissa * y.mantissa
    if minus { return (CBF_term){0 - m, x.exponent as i128 + y.exponent as i128} }
    return (CBF_term){m.copy(), x.exponent as i128 + y.exponent as i128}
}

// the one numbered i of four
let CBF_pick(i:i64, a:lent CBF_term, b:lent CBF_term, c:lent CBF_term, d:lent CBF_term):CBF_term {
    if i == 0 { return (CBF_term){a.m.copy(), a.e} }
    if i == 1 { return (CBF_term){b.m.copy(), b.e} }
    if i == 2 { return (CBF_term){c.m.copy(), c.e} }
    return (CBF_term){d.m.copy(), d.e}
}

// a + b + c + d, exactly where they are near in size: the greatest
// first, each next one added to the sum. Where all that is left is below
// the sum's last bit by keep places and more, it tells only which side of
// the sum the whole is: a bit below those places stands for its sign,
// which is found the same way, so that no shift is as long as the
// exponents are apart. What is given rounds to keep - 2 bits and fewer
// as the whole does, and has its sign
let CBF_total(a:lent CBF_term, b:lent CBF_term, c:lent CBF_term, d:lent CBF_term, keep:i64):CBF_term {
    var m = BigInt(0)                    // what is summed, m * 2^e
    var e:i128 = 0
    var held = BigInt(0)                 // the sum above, once what is left is far below it
    var held_e:i128 = 0
    var cut = false
    var used:i64 = 0
    while true {
        var j:i64 = 0 - 1
        var top:i128 = 0
        for i in 0..<4 {
            if (used >> i) % 2 == 1 { continue }
            let t = CBF_pick(i, a, b, c, d)
            if t.m.isZero {
                used += 1 << i
                continue
            }
            let ti:i128 = t.e + BigFloat_length(t.m) as i128
            if j < 0 || ti > top {
                j = i
                top = ti
            }
        }
        if j < 0 { break }
        if !m.isZero && top + 2 < e - (cut ? 0 : keep) as i128 {
            if cut { break }             // what is left is below the last bit of m: m has the sign
            held = m.copy()
            held_e = e
            cut = true
            m = BigInt(0)
        }
        let t = CBF_pick(j, a, b, c, d)
        used += 1 << j
        if m.isZero {
            m = t.m.copy()
            e = t.e
        } else {
            let low:i128 = t.e < e ? t.e : e
            m = (m << (e - low) as i64) + (t.m << (t.e - low) as i64)
            e = low
        }
    }
    if !cut { return (CBF_term){m.copy(), e} }
    return (CBF_term){(held << (keep + 1)) + m.sign, held_e - keep as i128 - 1}
}

// (n1 + n2) / (d1 + d2) to bits bits, the nearest: the quotient of the
// two sums, each to 64 bits more, cut to bits + 2 bits is t, within a
// unit of the true one; t is then put where |n| - t d is 0 or more and
// |n| - (t + 1) d less than 0, each sign found exactly, and a bit below t
// says whether anything is left, which the rounding reads. d1 + d2 is
// above 0
let CBF_ratio(n1:lent CBF_term, n2:lent CBF_term, d1:lent CBF_term, d2:lent CBF_term, bits:i64):BigFloat {
    let none = CBF_none()
    let n = CBF_total(n1, n2, none, none, bits + 64)
    if n.m.isZero { return BigFloat_zero() }
    let d = CBF_total(d1, d2, none, none, bits + 64)
    let negative = n.m.isNegative
    let a = n.m.abs
    var s:i64 = bits + 3 + BigFloat_length(d.m) - BigFloat_length(a)
    if s < 0 { s = 0 }
    var t = (a << s) / d.m
    var x:i128 = n.e - d.e - s as i128
    let over:i64 = BigFloat_length(t) - bits - 2
    if over > 0 {
        t = t >> over
        x += over as i128
    }
    // |n| as two terms, and the sign of |n| - t * 2^x * (d1 + d2)
    let p1:CBF_term = (CBF_term){negative ? 0 - n1.m : n1.m.copy(), n1.e}
    let p2:CBF_term = (CBF_term){negative ? 0 - n2.m : n2.m.copy(), n2.e}
    var left:i64 = CBF_total(p1, p2, (CBF_term){0 - t * d1.m, x + d1.e}, (CBF_term){0 - t * d2.m, x + d2.e}, 0).m.sign
    while left < 0 {
        t = t - 1
        left = CBF_total(p1, p2, (CBF_term){0 - t * d1.m, x + d1.e}, (CBF_term){0 - t * d2.m, x + d2.e}, 0).m.sign
    }
    while left > 0 {
        let u = t + 1
        let next:i64 = CBF_total(p1, p2, (CBF_term){0 - u * d1.m, x + d1.e}, (CBF_term){0 - u * d2.m, x + d2.e}, 0).m.sign
        if next < 0 { break }
        t = u.copy()
        left = next
    }
    var q = t.copy()
    if left > 0 {
        q = (t << 1) + 1
        x -= 1
    }
    if negative { return BigFloat_make(0 - q, x, bits, 0) }
    return BigFloat_make(q, x, bits, 0)
}

// ---------- arithmetic ----------

// whether x is 0, and whether a part of z is an infinity or a NaN
let CBF_zero(x:lent BigFloat):bool { x.special == 0 && x.mantissa.isZero }
let CBF_wild(z:lent CBF):bool { z.real.special != 0 || z.imag.special != 0 }

// a times b, both finite: each part a sum of two products, exactly,
// rounded once to bits bits
let CBF_product(a:lent CBF, b:lent CBF, bits:i64):CBF {
    let none = CBF_none()
    let re = CBF_total(CBF_times(a.real, b.real, false), CBF_times(a.imag, b.imag, true), none, none, bits + 4)
    let im = CBF_total(CBF_times(a.real, b.imag, false), CBF_times(a.imag, b.real, false), none, none, bits + 4)
    return (CBF){BigFloat_make(re.m, re.e, bits, 0), BigFloat_make(im.m, im.e, bits, 0)}
}

// z / 0, as a CBR's (#571): each part an infinity of the part's sign,
// but a part that is 0 stays 0 beside one that is none; 0 / 0 is NaNs,
// and a NaN part makes no 0 of the other
let CBF_by_zero(z:lent CBF, zero:lent BigFloat):CBF {
    let real = CBF_zero(z.real)
    let imag = CBF_zero(z.imag)
    if real && !imag && z.imag.special != 2 { return (CBF){BigFloat_zero(), z.imag / zero} }
    if imag && !real && z.real.special != 2 { return (CBF){z.real / zero, BigFloat_zero()} }
    return (CBF){z.real / zero, z.imag / zero}
}

// z times a real number r, as a CBR's (#573): each part times r, but
// times an infinity a part that is 0 stays 0 beside one that is none; 0
// times an infinity is NaNs in both parts, whichever of the two is the 0
let CBF_scaled(z:lent CBF, r:lent BigFloat):CBF {
    let real = CBF_zero(z.real)
    let imag = CBF_zero(z.imag)
    if r.special == 1 {
        if real && imag { return (CBF){BigFloat_nan(), BigFloat_nan()} }
        if real && z.imag.special != 2 { return (CBF){BigFloat_zero(), z.imag * r} }
        if imag && z.real.special != 2 { return (CBF){z.real * r, BigFloat_zero()} }
    }
    if CBF_zero(r) && (z.real.special == 1 || z.imag.special == 1) {
        return (CBF){BigFloat_nan(), BigFloat_nan()}
    }
    return (CBF){z.real * r, z.imag * r}
}

extend CBF {
    static let +(a:Self, b:Self):Self { (Self){a.real + b.real, a.imag + b.imag} }
    // with a real number the imaginary part is rounded too, as every result
    static let +(a:Self, b:BigFloat):Self { (Self){a.real + b, a.imag.round(BigFloat_bits())} }
    static let +(a:BigFloat, b:Self):Self { (Self){a + b.real, b.imag.round(BigFloat_bits())} }
    static let +(a:Self, b:BigInt):Self { a + BigFloat(b) }
    static let +(a:BigInt, b:Self):Self { BigFloat(a) + b }
    static let +(a:Self, b:i64):Self { a + BigFloat(b) }
    static let +(a:i64, b:Self):Self { BigFloat(a) + b }

    static let -(a:Self):Self { (Self){-a.real, -a.imag} }
    static let -(a:Self, b:Self):Self { (Self){a.real - b.real, a.imag - b.imag} }
    static let -(a:Self, b:BigFloat):Self { (Self){a.real - b, a.imag.round(BigFloat_bits())} }
    static let -(a:BigFloat, b:Self):Self { (Self){a - b.real, (-b.imag).round(BigFloat_bits())} }
    static let -(a:Self, b:BigInt):Self { a - BigFloat(b) }
    static let -(a:BigInt, b:Self):Self { BigFloat(a) - b }
    static let -(a:Self, b:i64):Self { a - BigFloat(b) }
    static let -(a:i64, b:Self):Self { BigFloat(a) - b }

    // by a real number, one with an imaginary part of 0, it is the other
    // scaled, and by an imaginary one too, with a quarter turn, as a
    // CBR's; else each part is a sum of two products, exactly, rounded
    // once. With an infinity or a NaN in a part it is by the parts'
    // arithmetic
    static let *(a:Self, b:Self):Self {
        if CBF_zero(b.imag) { return CBF_scaled(a, b.real) }
        if CBF_zero(a.imag) { return CBF_scaled(b, a.real) }
        if CBF_zero(b.real) {
            let s = CBF_scaled(a, b.imag)
            return (Self){-s.imag, s.real.copy()}
        }
        if CBF_zero(a.real) {
            let s = CBF_scaled(b, a.imag)
            return (Self){-s.imag, s.real.copy()}
        }
        if CBF_wild(a) || CBF_wild(b) {
            return (Self){a.real * b.real - a.imag * b.imag, a.real * b.imag + a.imag * b.real}
        }
        return CBF_product(a, b, BigFloat_bits())
    }
    static let *(a:Self, b:BigFloat):Self { CBF_scaled(a, b) }
    static let *(a:BigFloat, b:Self):Self { CBF_scaled(b, a) }
    static let *(a:Self, b:BigInt):Self { a * BigFloat(b) }
    static let *(a:BigInt, b:Self):Self { BigFloat(a) * b }
    static let *(a:Self, b:i64):Self { a * BigFloat(b) }
    static let *(a:i64, b:Self):Self { BigFloat(a) * b }

    // a times b's conjugate, over b's norm: each part the quotient of two
    // sums of products, exactly, rounded once. By 0 it is infinite,
    // CBF_by_zero's, and by an infinity 0; by a real number it is part
    // by part, and by an imaginary one too, with a quarter turn, as a
    // CBR's (#572)
    static let /(a:Self, b:Self):Self {
        if CBF_zero(b.real) && CBF_zero(b.imag) { return CBF_by_zero(a, b.real) }
        if b.real.special == 1 || b.imag.special == 1 {
            if CBF_wild(a) { return (Self){BigFloat_nan(), BigFloat_nan()} }
            return (Self){BigFloat_zero(), BigFloat_zero()}
        }
        if CBF_zero(b.imag) { return (Self){a.real / b.real, a.imag / b.real} }
        if CBF_zero(b.real) { return (Self){a.imag / b.imag, -(a.real / b.imag)} }
        if CBF_wild(a) || CBF_wild(b) {
            let d = b.real * b.real + b.imag * b.imag
            return (Self){(a.real * b.real + a.imag * b.imag) / d, (a.imag * b.real - a.real * b.imag) / d}
        }
        let bits = BigFloat_bits()
        let d1 = CBF_times(b.real, b.real, false)
        let d2 = CBF_times(b.imag, b.imag, false)
        let re = CBF_ratio(CBF_times(a.real, b.real, false), CBF_times(a.imag, b.imag, false), d1, d2, bits)
        let im = CBF_ratio(CBF_times(a.imag, b.real, false), CBF_times(a.real, b.imag, true), d1, d2, bits)
        return (Self){re.copy(), im.copy()}
    }
    static let /(a:Self, b:BigFloat):Self {
        if CBF_zero(b) { return CBF_by_zero(a, b) }
        return (Self){a.real / b, a.imag / b}
    }
    static let /(a:BigFloat, b:Self):Self { CBF(a) / b }
    static let /(a:Self, b:BigInt):Self { a / BigFloat(b) }
    static let /(a:BigInt, b:Self):Self { CBF(BigFloat(a)) / b }
    static let /(a:Self, b:i64):Self { a / BigFloat(b) }
    static let /(a:i64, b:Self):Self { CBF(BigFloat(a)) / b }

    // a part that is a NaN equals nothing, as a BigFloat's
    static let ==(a:Self, b:Self):bool { a.real == b.real && a.imag == b.imag }
    static let !=(a:Self, b:Self):bool { !(a == b) }
}

// ---------- parts ----------

let conj(z:lent CBF):CBF { (CBF){z.real.copy(), -z.imag} }

// |z|², a BigFloat: the sum of the two squares, exactly, rounded once
let norm(z:lent CBF):BigFloat {
    if CBF_wild(z) { return z.real * z.real + z.imag * z.imag }
    let none = CBF_none()
    let bits = BigFloat_bits()
    let n = CBF_total(CBF_times(z.real, z.real, false), CBF_times(z.imag, z.imag, false), none, none, bits + 4)
    return BigFloat_make(n.m, n.e, bits, 0)
}

extend CBF {
    let conj():Self { conj(self) }
    let norm():BigFloat { norm(self) }
    let i:Self { (Self){-self.imag, self.real.copy()} }   // z rotated a quarter turn: z times i

    // each part at precision significant bits, by a rule or to the
    // nearest and the even one, as x.round of a BigFloat
    let round(precision:i64, rule:RoundingRule):Self { (Self){self.real.round(precision, rule), self.imag.round(precision, rule)} }
    let round(precision:i64):Self { (Self){self.real.round(precision), self.imag.round(precision)} }

    // its text, which print shows whole and .cstr gives: (0.1-0.2.i), each
    // part a BigFloat's text, the imaginary part's sign joining the two,
    // as a c64's (#570); .dec has the real part's sign too, (+0.1-0.2.i),
    // and .hex is of the parts' .hex, (+0x1.8p+0-0x1p+1.i), exact
    let string:String {
        let real = self.real.string
        let imag = self.imag.string
        return complex_text(real.cstr, imag.cstr)
    }
    let dec:String {
        let real = self.real.dec
        let imag = self.imag.dec
        return complex_text(real.cstr, imag.cstr)
    }
    let hex:String {
        let real = self.real.hex
        let imag = self.imag.hex
        return complex_text(real.cstr, imag.cstr)
    }
}

extend BigFloat {
    let i:CBF { (CBF){BigFloat_zero(), self.copy()} }     // x rotated a quarter turn: CBF(0, x)
}

// ---------- math's functions of a CBF (#582) ----------
//
// abs and arg, BigFloats, and sqrt, exp, log, pow, the trigonometric and
// hyperbolic functions and their inverses, CBFs, each a method too. Each
// part of a result has BigFloat.precision significant bits, or the
// precision written, whatever its size and however far below the other
// part it is: the nearest to the true value's, or where that is all but
// midway between two, one of them, as a BigFloat's functions are. A
// part that is 0 is exactly 0: exp of a real number is real.
//
// exp, the sines and cosines and tanh are products and quotients of a
// BigFloat's functions, which lose nothing; sqrt and log are of the norm,
// exactly, and pow is e^(w log z); the inverses are a CBR's
// (math+Rational.k), with as many bits after the point as make each
// part's bits good, so they have its principal values and its branch
// cuts. With an infinity or a NaN in a part each is a CBR's too.

let CBF_nan():CBF { (CBF){BigFloat_nan(), BigFloat_nan()} }

// whether a part is past reckoning: 2^67108864 and more in size, or
// below 2^-67108864, where a rational of it is too long to make, as the
// inverses do. exp, the sines, the cosines and the tangents make none,
// and ask nothing of it (#585), nor do log, arg and pow (#586)
let CBF_past_part(x:lent BigFloat):bool {
    if x.special != 0 || x.mantissa.isZero { return false }
    let top:i128 = BigFloat_top(x)
    return top > 67108864 || top < 0 - 67108864
}
let CBF_past(z:lent CBF):bool { CBF_past_part(z.real) || CBF_past_part(z.imag) }

// how far below 1 the lesser part of z is, in bits: 0 where none is
let CBF_low(z:lent CBF):i64 {
    var low:i64 = 0
    if z.real.special == 0 && !z.real.mantissa.isZero {
        let t:i128 = BigFloat_top(z.real)
        if t < 0 - low as i128 { low = (0 - t) as i64 }
    }
    if z.imag.special == 0 && !z.imag.mantissa.isZero {
        let t:i128 = BigFloat_top(z.imag)
        if t < 0 - low as i128 { low = (0 - t) as i64 }
    }
    return low
}

// whether |x| is below 1, and whether it is 1; x is finite
let CBF_below_one(x:lent BigFloat):bool { x.mantissa.isZero || BigFloat_top(x) <= 0 }
let CBF_is_one(x:lent BigFloat):bool { x.exponent == 0 && x.mantissa.abs == BigInt(1) }

// a times b to bits bits; a 0 times an infinity, which is a number past
// any exponent here, is 0
let CBF_mul(a:lent BigFloat, b:lent BigFloat, bits:i64):BigFloat {
    if a.special == 2 || b.special == 2 { return BigFloat_nan() }
    if CBF_zero(a) || CBF_zero(b) { return BigFloat_zero() }
    if a.special == 1 || b.special == 1 {
        let sign:i64 = a.mantissa.sign * b.mantissa.sign
        return BigFloat_inf(sign)
    }
    return BigFloat_make(a.mantissa * b.mantissa, a.exponent as i128 + b.exponent as i128, bits, 0)
}

// a over b to bits bits; both finite, and b not 0
let CBF_div(a:lent BigFloat, b:lent BigFloat, bits:i64):BigFloat {
    if a.mantissa.isZero { return BigFloat_zero() }
    return BigFloat_quotient(a.mantissa, b.mantissa, a.exponent as i128 - b.exponent as i128, bits, 0)
}

// x, or less it
let CBF_signed(x:lent BigFloat, minus:bool):BigFloat {
    if minus { return -x }
    return x.copy()
}

// a times b to bits bits, b a sine or a cosine: 0 where a is, though b
// is of a number past reckoning and is not known, being 1 at the most
let CBF_turned(a:lent BigFloat, b:lent BigFloat, bits:i64):BigFloat {
    if CBF_zero(a) { return BigFloat_zero() }
    return CBF_mul(a, b, bits)
}

// half of x
let CBF_half(x:lent BigFloat):BigFloat {
    if x.special != 0 || x.mantissa.isZero { return x.copy() }
    return (BigFloat){x.mantissa.copy(), x.exponent - 1, 0}
}

// ---------- by a CBR's function ----------

// the function numbered f of a CBR, each part within 2^-w
let CBF_function(f:i64, z:lent CBR, w:i64):CBR {
    if f == 1 { return asin(z, w) }
    if f == 2 { return acos(z, w) }
    if f == 3 { return atan(z, w) }
    if f == 4 { return asinh(z, w) }
    if f == 5 { return acosh(z, w) }
    if f == 6 { return atanh(z, w) }
    if f == 8 { return sqrt(z, w) }
    if f == 9 { return exp(z, w) }
    if f == 10 { return log(z, w) }
    if f == 11 { return sin(z, w) }
    if f == 12 { return cos(z, w) }
    if f == 13 { return tan(z, w) }
    if f == 14 { return sinh(z, w) }
    if f == 15 { return cosh(z, w) }
    return tanh(z, w)
}

// of a z with an infinity or a NaN in a part, which has no size to
// reckon: a CBR's, which is an infinity, a NaN, 0 or a multiple of pi
let CBF_wild_by(f:i64, z:lent CBF, bits:i64):CBF {
    return CBF(CBF_function(f, CBR(z), bits + 8), bits)
}

// a part of a CBR's result, within 2^-w, to bits bits where they are
// good; else again is raised to the w that would make them so. zero
// says the part is 0 exactly, by what the function is
let CBF_part(r:lent BigRat, w:i64, bits:i64, zero:bool, again:i64^):BigFloat {
    if zero { return BigFloat_zero() }
    var more:i64 = 0
    let x = BigFloat_good(r, w, bits, &more)
    if more > again^ { again^ = more }
    return x
}

// f of z, each part to bits significant bits: with more bits after
// the point until both parts' are good
let CBF_by(f:i64, z:lent CBF, bits:i64, real_zero:bool, imag_zero:bool):CBF {
    if CBF_past(z) { return CBF_nan() }
    let rz = CBR(z)
    var w:i64 = bits + 32 + CBF_low(z)
    var again:i64 = 0
    var re = BigFloat_zero()
    var im = BigFloat_zero()
    while true {
        let c = CBF_function(f, rz, w)
        again = 0
        re = CBF_part(c.real, w, bits, real_zero, &again)
        im = CBF_part(c.imag, w, bits, imag_zero, &again)
        if again == 0 || again >= 67108864 { break }
        w = again
    }
    return (CBF){re.copy(), im.copy()}
}

// ---------- abs, arg, sqrt and log ----------

// |z| of a finite z, the nearest: the root of the norm, which is exact
// to twice the bits and has a bit below for the rest
let CBF_abs(z:lent CBF, bits:i64):BigFloat {
    let none = CBF_none()
    let n = CBF_total(CBF_times(z.real, z.real, false), CBF_times(z.imag, z.imag, false), none, none, 2 * bits + 8)
    return BigFloat_sqrt(BigFloat_make(n.m, n.e, 1000000000000, 0), bits)
}

let abs(z:lent CBF, precision:i64):BigFloat {
    let bits:i64 = precision < 1 ? 1 : precision
    if CBF_wild(z) { return sqrt(z.real * z.real + z.imag * z.imag, bits) }
    return CBF_abs(z, bits)
}

// the angle from the positive real axis, from -pi to pi: a BigFloat's
// atan2, of parts of any size
let arg(z:lent CBF, precision:i64):BigFloat { atan2(z.imag, z.real, precision) }

// the principal square root, whose real part is never negative:
// sqrt((|z| + |x|) / 2), the larger part, and |y| over twice it; of a
// real number its root, on the real axis or the imaginary one
let CBF_sqrt(z:lent CBF, bits:i64):CBF {
    if CBF_wild(z) { return CBF_wild_by(8, z, bits) }
    if CBF_zero(z.imag) {
        if z.real.mantissa.isNegative { return (CBF){BigFloat_zero(), sqrt(-z.real, bits)} }
        return (CBF){sqrt(z.real, bits), BigFloat_zero()}
    }
    let p:i64 = bits + 16
    let m = CBF_abs(z, p)
    let a:BigFloat = (BigFloat){z.real.mantissa.abs, z.real.exponent, 0}
    let b:BigFloat = (BigFloat){z.imag.mantissa.abs, z.imag.exponent, 0}
    let s = BigFloat_sqrt(CBF_half(BigFloat_sum(m, a, p)), p)
    let t = CBF_half(CBF_div(b, s, p))
    let minus = z.imag.mantissa.isNegative
    if z.real.mantissa.isNegative { return (CBF){t.round(bits), CBF_signed(s.round(bits), minus)} }
    return (CBF){s.round(bits), CBF_signed(t.round(bits), minus)}
}

// ln|z|, of the greater part and the lesser: half the log of the norm,
// which is exact but where one part is far below the other, and then it
// is all but the greater's square; of 1 and a part far below, half that
// part's square
let CBF_log_size(big:lent BigFloat, small:lent BigFloat, bits:i64):BigFloat {
    if !small.mantissa.isZero && CBF_is_one(big) && 2 * BigFloat_top(small) < 0 - bits as i128 - 24 {
        return BigFloat_make(small.mantissa * small.mantissa, 2 * small.exponent as i128 - 1, bits, 0)
    }
    let none = CBF_none()
    let keep:i64 = bits + 2 * (BigFloat_length(big.mantissa) + BigFloat_length(small.mantissa)) + 32
    let n = CBF_total(CBF_times(big, big, false), CBF_times(small, small, false), none, none, keep)
    let odd = BigFloat_make(n.m, 0, 1000000000000, 0)      // the norm's exponent may be past an i64
    return CBF_half(BigFloat_log_of(odd.mantissa, n.e + odd.exponent as i128, bits))
}

// the principal value, ln|z| + i arg z, of a z of any size (#586): the
// angle is a BigFloat's atan2, which takes any two numbers (#583), and
// the norm is had with an exponent of any size
let CBF_log(z:lent CBF, bits:i64):CBF {
    if CBF_wild(z) { return CBF_wild_by(10, z, bits) }
    if CBF_zero(z.real) && CBF_zero(z.imag) { return (CBF){BigFloat_inf(0 - 1), BigFloat_zero()} }
    let im = atan2(z.imag, z.real, bits)
    if CBF_zero(z.imag) || (!CBF_zero(z.real) && BigFloat_top(z.real) >= BigFloat_top(z.imag)) {
        return (CBF){CBF_log_size(z.real, z.imag, bits), im.copy()}
    }
    return (CBF){CBF_log_size(z.imag, z.real, bits), im.copy()}
}

// ---------- exp, the sines and the cosines ----------

// These are of a BigFloat's functions, which take a number of any size
// (#583), so a part of any size is taken (#585): near 0 a function is
// its first term, exp(CBF(1, tiny)) is (e + e tiny i); far out e^x is an
// infinity or 0, and sinh and cosh infinities; and the sine and the
// cosine of a number of 2^67108864 and more are NaNs, which a part that
// has one in it is, but where the other factor is 0

// e^x (cos y + i sin y)
let CBF_exp(z:lent CBF, bits:i64):CBF {
    if CBF_wild(z) { return CBF_wild_by(9, z, bits) }
    if CBF_zero(z.imag) { return (CBF){exp(z.real, bits), BigFloat_zero()} }
    let p:i64 = bits + 16
    let e = exp(z.real, p)
    return (CBF){CBF_turned(e, cos(z.imag, p), bits), CBF_turned(e, sin(z.imag, p), bits)}
}

// sinh(a + ib) = sinh a cos b + i cosh a sin b
let CBF_sinh(z:lent CBF, bits:i64):CBF {
    if CBF_wild(z) { return CBF_wild_by(14, z, bits) }
    if CBF_zero(z.imag) { return (CBF){sinh(z.real, bits), BigFloat_zero()} }
    let p:i64 = bits + 16
    return (CBF){CBF_turned(sinh(z.real, p), cos(z.imag, p), bits), CBF_mul(cosh(z.real, p), sin(z.imag, p), bits)}
}

// cosh(a + ib) = cosh a cos b + i sinh a sin b
let CBF_cosh(z:lent CBF, bits:i64):CBF {
    if CBF_wild(z) { return CBF_wild_by(15, z, bits) }
    if CBF_zero(z.imag) { return (CBF){cosh(z.real, bits), BigFloat_zero()} }
    let p:i64 = bits + 16
    return (CBF){CBF_mul(cosh(z.real, p), cos(z.imag, p), bits), CBF_turned(sinh(z.real, p), sin(z.imag, p), bits)}
}

// sin(x + iy) = sin x cosh y + i cos x sinh y
let CBF_sin(z:lent CBF, bits:i64):CBF {
    if CBF_wild(z) { return CBF_wild_by(11, z, bits) }
    if CBF_zero(z.imag) { return (CBF){sin(z.real, bits), BigFloat_zero()} }
    let p:i64 = bits + 16
    return (CBF){CBF_mul(sin(z.real, p), cosh(z.imag, p), bits), CBF_mul(cos(z.real, p), sinh(z.imag, p), bits)}
}

// cos(x + iy) = cos x cosh y - i sin x sinh y
let CBF_cos(z:lent CBF, bits:i64):CBF {
    if CBF_wild(z) { return CBF_wild_by(12, z, bits) }
    if CBF_zero(z.imag) { return (CBF){cos(z.real, bits), BigFloat_zero()} }
    let p:i64 = bits + 16
    return (CBF){CBF_mul(cos(z.real, p), cosh(z.imag, p), bits), -CBF_mul(sin(z.real, p), sinh(z.imag, p), bits)}
}

// tanh(a + ib) = (sinh a cosh a + i sin b cos b) / (sinh^2 a + cos^2 b),
// a sum that cancels nothing, near a pole too; of an a as large as the
// bits, where the sum is all but e^(2|a|) / 4, it is 1 with a's sign and
// 4 sin b cos b e^(-2|a|). z is finite, and b not 0
let CBF_tanh_of(z:lent CBF, bits:i64):CBF {
    let p:i64 = bits + 16
    let s = sin(z.imag, p)
    let c = cos(z.imag, p)
    let size:BigFloat = (BigFloat){z.real.mantissa.abs, z.real.exponent, 0}
    if size >= BigFloat(p) {
        let e = exp(-(size * 2), p)
        if e.mantissa.isZero { return (CBF){BigFloat(z.real.mantissa.sign), BigFloat_zero()} }
        if s.special != 0 { return (CBF){BigFloat(z.real.mantissa.sign), BigFloat_nan()} }   // b is past reckoning, and its part not 0
        let t = CBF_mul(CBF_mul(s, c, p), e, bits)
        if t.special != 0 || t.mantissa.isZero { return (CBF){BigFloat(z.real.mantissa.sign), BigFloat_zero()} }
        return (CBF){BigFloat(z.real.mantissa.sign), (BigFloat){t.mantissa.copy(), t.exponent + 2, 0}}
    }
    if s.special != 0 {                                  // b is past reckoning: i tan b of an imaginary z, and else nothing
        if CBF_zero(z.real) { return (CBF){BigFloat_zero(), BigFloat_nan()} }
        return CBF_nan()
    }
    let sh = sinh(z.real, p)
    let ch = cosh(z.real, p)
    let d = BigFloat_sum(CBF_mul(sh, sh, p), CBF_mul(c, c, p), p)
    return (CBF){CBF_div(CBF_mul(sh, ch, p), d, bits), CBF_div(CBF_mul(s, c, p), d, bits)}
}

let CBF_tanh(z:lent CBF, bits:i64):CBF {
    if CBF_wild(z) { return CBF_wild_by(16, z, bits) }
    if CBF_zero(z.imag) { return (CBF){tanh(z.real, bits), BigFloat_zero()} }
    return CBF_tanh_of(z, bits)
}

// tan z = -i tanh(iz)
let CBF_tan(z:lent CBF, bits:i64):CBF {
    if CBF_wild(z) { return CBF_wild_by(13, z, bits) }
    if CBF_zero(z.imag) { return (CBF){tan(z.real, bits), BigFloat_zero()} }
    let w = CBF_tanh_of((CBF){-z.imag, z.real.copy()}, bits)
    return (CBF){w.imag.copy(), -w.real}
}

// ---------- the inverses, a CBR's ----------

// of a real z where the function of a real number is one, a
// BigFloat's; else a CBR's, and a part is 0 exactly where the function
// has it so: asin of an imaginary z is imaginary, acos right of 1 too
let CBF_asin(z:lent CBF, bits:i64):CBF {
    if CBF_zero(z.imag) && z.real.special == 0 && (CBF_below_one(z.real) || CBF_is_one(z.real)) {
        return (CBF){asin(z.real, bits), BigFloat_zero()}
    }
    return CBF_by(1, z, bits, CBF_zero(z.real), false)
}

let CBF_acos(z:lent CBF, bits:i64):CBF {
    if CBF_zero(z.imag) && z.real.special == 0 && (CBF_below_one(z.real) || CBF_is_one(z.real)) {
        return (CBF){acos(z.real, bits), BigFloat_zero()}
    }
    return CBF_by(2, z, bits, CBF_zero(z.imag) && z.real.special == 0 && !z.real.mantissa.isNegative, false)
}

let CBF_atan(z:lent CBF, bits:i64):CBF {
    if CBF_zero(z.imag) && z.real.special == 0 { return (CBF){atan(z.real, bits), BigFloat_zero()} }
    let within = z.imag.special == 0 && (CBF_below_one(z.imag) || CBF_is_one(z.imag))
    return CBF_by(3, z, bits, CBF_zero(z.real) && within, false)
}

let CBF_asinh(z:lent CBF, bits:i64):CBF {
    if CBF_zero(z.imag) && z.real.special == 0 { return (CBF){asinh(z.real, bits), BigFloat_zero()} }
    let within = z.imag.special == 0 && (CBF_below_one(z.imag) || CBF_is_one(z.imag))
    return CBF_by(4, z, bits, CBF_zero(z.real) && within, false)
}

let CBF_acosh(z:lent CBF, bits:i64):CBF {
    let real = CBF_zero(z.imag) && z.real.special == 0
    let within = real && (CBF_below_one(z.real) || CBF_is_one(z.real))
    if real && !z.real.mantissa.isNegative && (!within || CBF_is_one(z.real)) {
        return (CBF){acosh(z.real, bits), BigFloat_zero()}
    }
    return CBF_by(5, z, bits, within, false)
}

let CBF_atanh(z:lent CBF, bits:i64):CBF {
    let real = CBF_zero(z.imag) && z.real.special == 0
    if real && CBF_below_one(z.real) { return (CBF){atanh(z.real, bits), BigFloat_zero()} }
    return CBF_by(6, z, bits, CBF_zero(z.real), real && CBF_is_one(z.real))
}

// ---------- pow ----------

// z to the w is e^(w log z), and w log z is made of the parts of w
// times ln|z| and the angle of z, which is kept as k quarter turns and
// what is left of them, rho, an eighth of a turn at the most: so of a z
// beside an axis, (tiny + i), what is left is known to its own bits, not
// to those of a quarter turn (#586). The turns that w's real part makes of
// the k are whole where it is whole, or a whole and a half with k of 2,
// and are then taken out of the angle exactly, j of them; on a diagonal,
// rho being an eighth of a turn, those of an even whole w are too. What is
// left of the angle, phi, is w's real part times rho and its imaginary
// part times ln|z|: where it is nothing a part of the power is 0 exactly

// a number that stands for each part of z, as beside a 0 (#583)
let CBF_stand(z:lent CBF):CBF { (CBF){BigFloat_stand(z.real), BigFloat_stand(z.imag)} }

// the power of 2 above a term, and of none one far below any
let CBF_top(t:lent CBF_term):i128 {
    if t.m.isZero { return 0 - ((1 as i128) << 100) }
    return t.e + BigFloat_length(t.m) as i128
}

// x times hp times k, k from -2 to 2
let CBF_turns(x:lent BigFloat, hp:lent BigFloat, k:i64):CBF_term {
    if k == 0 { return CBF_none() }
    let t = CBF_times(x, hp, k < 0)
    if k == 2 || k == 0 - 2 { return (CBF_term){t.m.copy(), t.e + 1} }
    return (CBF_term){t.m.copy(), t.e}
}

// m * 2^e, a whole number, e being 0 or more: what it is over 4s, 0 to 3
let CBF_mod4(m:lent BigInt, e:i64):i64 {
    if m.isZero || e >= 2 { return 0 }
    let a = m.abs
    var r:i64 = (a - ((a >> 2) << 2)).i64
    r = (r << e) % 4
    if m.isNegative { r = (4 - r) % 4 }
    return r
}

// each part of c times 2^s
let CBF_shifted(c:lent CBF, s:i128, bits:i64):CBF {
    return (CBF){BigFloat_make(c.real.mantissa, c.real.exponent as i128 + s, bits, 0), BigFloat_make(c.imag.mantissa, c.imag.exponent as i128 + s, bits, 0)}
}

// z to the n, n whole and 65536 at the most, or 1 over it: the power
// itself, rounded, of z over 2^k, whose parts are whole numbers, times
// 2^(k n). The parts of z are no further apart than 2^67108864, or one
// is 0
let CBF_whole_power(z:lent CBF, n:i64, minus:bool, bits:i64):CBF {
    var k:i64 = z.real.exponent
    if z.real.mantissa.isZero || (!z.imag.mantissa.isZero && z.imag.exponent < k) { k = z.imag.exponent }
    var re = BigRat(0)
    var im = BigRat(0)
    if !z.real.mantissa.isZero { re = BigRat(z.real.mantissa << (z.real.exponent - k)) }
    if !z.imag.mantissa.isZero { im = BigRat(z.imag.mantissa << (z.imag.exponent - k)) }
    let up = CBR_power((CBR){re.copy(), im.copy()}, n)
    if minus { return CBF_shifted(CBF(1 / up, bits), 0 - k as i128 * n as i128, bits) }
    return CBF_shifted(CBF(up, bits), k as i128 * n as i128, bits)
}

// whether the parts of z are no further apart than 2^67108864, or one
// is 0: a whole power of it is then made exactly
let CBF_level(z:lent CBF):bool {
    if z.real.mantissa.isZero || z.imag.mantissa.isZero { return true }
    let apart:i128 = z.real.exponent as i128 - z.imag.exponent as i128
    return apart <= 67108864 && apart >= 0 - 67108864
}

// e^(w log z) of a finite z and w, neither 0. Each of ln|z|, rho and
// half of pi is had to q bits, so a sum of their products is within
// 2^(top + 3 - q), top being the greatest product's; e^x wants its x
// within 2^-(bits + 19), and a sine or a cosine what is left of the angle
// within that of its own size: q is raised until they are, and what would
// take 1048576 bits more than are asked is past reckoning, a NaN. An x
// that is past any exponent whatever its error makes an infinity or 0, and
// 0 times a sine not known is 0
let CBF_power(z:lent CBF, w:lent CBF, bits:i64):CBF {
    // the angle of z: k quarter turns and atan2(num, den), den above 0 and num no more than it in size
    let ax:BigFloat = (BigFloat){z.real.mantissa.abs, z.real.exponent, 0}
    let ay:BigFloat = (BigFloat){z.imag.mantissa.abs, z.imag.exponent, 0}
    var k:i64 = 0
    var num = z.imag.copy()
    var den = z.real.copy()
    if ax >= ay {
        if z.real.mantissa.isNegative {
            k = z.imag.mantissa.isNegative ? 0 - 2 : 2
            num = -z.imag
            den = -z.real
        }
    } else if z.imag.mantissa.isNegative {
        k = 0 - 1
        num = z.real.copy()
        den = -z.imag
    } else {
        k = 1
        num = -z.real
        den = z.imag.copy()
    }
    let unit = num.mantissa.isZero && CBF_is_one(den)       // |z| is 1, and its log 0
    let diagonal = num.exponent == den.exponent && num.mantissa.abs == den.mantissa
    // j, the whole quarter turns of w's real part times the angle
    var j:i64 = 0
    var turned = true                    // those of the k are in j
    var skew = false                     // and those of rho, an eighth of a turn
    let ae:i64 = w.real.exponent
    if w.real.mantissa.isZero || (k == 0 && !(diagonal && ae >= 1)) {
        j = 0
    } else if diagonal && ae >= 1 {
        let eighths:i64 = 2 * k + (num.mantissa.isNegative ? 0 - 1 : 1)
        j = ((CBF_mod4(w.real.mantissa, ae - 1) * eighths) % 4 + 4) % 4
        skew = true
    } else if ae >= 0 {
        j = ((CBF_mod4(w.real.mantissa, ae) * k) % 4 + 4) % 4
    } else if ae == 0 - 1 && (k == 2 || k == 0 - 2) {
        j = ((CBF_mod4(w.real.mantissa, 0) * (k / 2)) % 4 + 4) % 4
    } else {
        turned = false
    }
    let none = CBF_none()
    let far:i128 = 0 - ((1 as i128) << 100)
    let limit:i128 = bits as i128 + 1048576 + 64
    var q:i64 = bits + 40
    var e = BigFloat(1)                  // e^(the real part of w log z)
    var c = BigFloat(1)                  // the cosine and the sine of phi
    var s = BigFloat_zero()
    var still = true                     // phi is nothing: the sine is 0 exactly
    var lost_e = false                   // past reckoning
    var lost_c = false
    var lost_s = false
    while true {
        var l = BigFloat_zero()
        if !unit { l = CBF_log_size(den, num, q) }
        var rho = BigFloat_zero()
        if !num.mantissa.isZero { rho = atan2(num, den, q) }
        let hp = BigFloat_pi_times(0 - 1, q, false)
        var need:i128 = 0
        // the real part: w.real ln|z| - w.imag (k hp + rho)
        let r1 = CBF_times(w.real, l, false)
        let r2 = CBF_turns(w.imag, hp, 0 - k)
        let r3 = CBF_times(w.imag, rho, true)
        var tre:i128 = CBF_top(r1)
        if CBF_top(r2) > tre { tre = CBF_top(r2) }
        if CBF_top(r3) > tre { tre = CBF_top(r3) }
        if tre != far && !lost_e {
            let tr = CBF_total(r1, r2, r3, none, q + 8)
            let top:i128 = CBF_top(tr)
            if !tr.m.isZero && top > 66 && top > tre + 12 - q as i128 {
                if tr.m.isNegative { return (CBF){BigFloat_zero(), BigFloat_zero()} }
                e = BigFloat_inf(1)
            } else {
                var want:i128 = bits as i128 + 22 + tre
                if tr.m.isZero && want <= q as i128 { want = 2 * q as i128 + 8 }
                if want > limit {
                    lost_e = true
                } else if want > q as i128 {
                    need = want
                } else {
                    e = exp(BigFloat_make(tr.m, tr.e, q, 0), bits + 16)
                    if CBF_zero(e) { return (CBF){BigFloat_zero(), BigFloat_zero()} }
                }
            }
        }
        // what is left of the angle: w.real rho + w.imag ln|z|, and w.real k hp where its turns are not whole
        var p1 = CBF_none()
        if !skew { p1 = CBF_times(w.real, rho, false) }
        let p2 = CBF_times(w.imag, l, false)
        var p3 = CBF_none()
        if !turned { p3 = CBF_turns(w.real, hp, k) }
        var tphi:i128 = CBF_top(p1)
        if CBF_top(p2) > tphi { tphi = CBF_top(p2) }
        if CBF_top(p3) > tphi { tphi = CBF_top(p3) }
        if tphi != far && !(lost_c && lost_s) {
            still = false
            let base:i128 = bits as i128 + 22 + tphi
            if base > limit {
                lost_c = true
                lost_s = true
            } else if base > q as i128 {
                if base > need { need = base }
            } else {
                let ph = CBF_total(p1, p2, p3, none, q + 8)
                let phi = BigFloat_make(ph.m, ph.e, q, 0)
                var want_c:i128 = 0
                var want_s:i128 = 0
                if ph.m.isZero {
                    want_s = 2 * q as i128 + 8      // the products cancel to the last bit had
                    c = BigFloat(1)
                } else if phi.mantissa.isZero {
                    c = BigFloat(1)                 // below the least number: its sine is 0
                    s = BigFloat_zero()
                } else {
                    c = cos(phi, bits + 16)
                    s = sin(phi, bits + 16)
                    want_c = c.mantissa.isZero ? 2 * q as i128 + 8 : base - BigFloat_top(c)
                    want_s = s.mantissa.isZero ? 2 * q as i128 + 8 : base - BigFloat_top(s)
                }
                if want_c > limit { lost_c = true }
                if want_s > limit { lost_s = true }
                if !lost_c && want_c > need { need = want_c }
                if !lost_s && want_s > need { need = want_s }
            }
        }
        if need <= q as i128 { break }
        q = (need + 8) as i64
    }
    if lost_e { e = BigFloat_nan() }
    if lost_c { c = BigFloat_nan() }
    if lost_s { s = BigFloat_nan() }
    // the j quarter turns: (c, s), (-s, c), (-c, -s) and (s, -c)
    var re = BigFloat_zero()
    var im = BigFloat_zero()
    if j == 0 || j == 2 {
        re = CBF_turned(e, c, bits)
        if !still { im = CBF_turned(e, s, bits) }
    } else {
        if !still { re = CBF_turned(e, s, bits) }
        im = CBF_turned(e, c, bits)
    }
    if j == 1 || j == 2 { re = -re }
    if j == 2 || j == 3 { im = -im }
    return (CBF){re.copy(), im.copy()}
}

// z to the w: of a whole real w, 65536 at the most, the power itself,
// exactly, rounded, where the parts of z are no further apart than
// 2^67108864; of a real z above 0 and a real w a BigFloat's; else
// e^(w log z). A part of it is 0 exactly where the angle, w's real part
// times arg z and its imaginary part times ln|z|, is a whole number of
// quarter turns: of a negative z, half a turn, and a real part of w
// that is whole or a whole and a half; of an imaginary z, a quarter, and
// one that is whole; of a z on a diagonal, an eighth, and one that is
// whole and even; with a real w, or a z of size 1, whose log is 0. 1 to
// any w is 1; 0 to a w and a z to 0 are a CBR's, which reads no more of
// the other than the signs of its parts
let CBF_pow(z:lent CBF, w:lent CBF, bits:i64):CBF {
    if CBF_wild(z) || CBF_wild(w) { return CBF_nan() }
    if (CBF_zero(z.real) && CBF_zero(z.imag)) || (CBF_zero(w.real) && CBF_zero(w.imag)) {
        return CBF(pow(CBR(CBF_stand(z)), CBR(CBF_stand(w)), 8), bits)
    }
    let real = CBF_zero(w.imag)
    let whole = w.real.mantissa.isZero || w.real.exponent >= 0      // of w's real part
    if real && whole && BigFloat_top(w.real) <= 17 && CBF_level(z) {
        let n:i64 = (w.real.mantissa.abs << w.real.exponent).i64
        if n <= 65536 { return CBF_whole_power(z, n, w.real.mantissa.isNegative, bits) }
    }
    if CBF_zero(z.imag) && !z.real.mantissa.isNegative {
        if CBF_is_one(z.real) { return (CBF){BigFloat(1), BigFloat_zero()} }
        if real { return (CBF){pow(z.real, w.real, bits), BigFloat_zero()} }
    }
    return CBF_power(z, w, bits)
}

// ---------- the functions, to a precision ----------

let sqrt(z:lent CBF, precision:i64):CBF { CBF_sqrt(z, precision < 1 ? 1 : precision) }
let exp(z:lent CBF, precision:i64):CBF { CBF_exp(z, precision < 1 ? 1 : precision) }
let log(z:lent CBF, precision:i64):CBF { CBF_log(z, precision < 1 ? 1 : precision) }
let sin(z:lent CBF, precision:i64):CBF { CBF_sin(z, precision < 1 ? 1 : precision) }
let cos(z:lent CBF, precision:i64):CBF { CBF_cos(z, precision < 1 ? 1 : precision) }
let tan(z:lent CBF, precision:i64):CBF { CBF_tan(z, precision < 1 ? 1 : precision) }
let sinh(z:lent CBF, precision:i64):CBF { CBF_sinh(z, precision < 1 ? 1 : precision) }
let cosh(z:lent CBF, precision:i64):CBF { CBF_cosh(z, precision < 1 ? 1 : precision) }
let tanh(z:lent CBF, precision:i64):CBF { CBF_tanh(z, precision < 1 ? 1 : precision) }
let asin(z:lent CBF, precision:i64):CBF { CBF_asin(z, precision < 1 ? 1 : precision) }
let acos(z:lent CBF, precision:i64):CBF { CBF_acos(z, precision < 1 ? 1 : precision) }
let atan(z:lent CBF, precision:i64):CBF { CBF_atan(z, precision < 1 ? 1 : precision) }
let asinh(z:lent CBF, precision:i64):CBF { CBF_asinh(z, precision < 1 ? 1 : precision) }
let acosh(z:lent CBF, precision:i64):CBF { CBF_acosh(z, precision < 1 ? 1 : precision) }
let atanh(z:lent CBF, precision:i64):CBF { CBF_atanh(z, precision < 1 ? 1 : precision) }
let pow(z:lent CBF, w:lent CBF, precision:i64):CBF { CBF_pow(z, w, precision < 1 ? 1 : precision) }
let pow(z:lent CBF, x:lent BigFloat, precision:i64):CBF { pow(z, CBF(x), precision) }
let pow(x:lent BigFloat, w:lent CBF, precision:i64):CBF { pow(CBF(x), w, precision) }

// each with BigFloat.precision where none is written
let abs(z:lent CBF):BigFloat { abs(z, BigFloat.precision) }
let arg(z:lent CBF):BigFloat { arg(z, BigFloat.precision) }
let sqrt(z:lent CBF):CBF { sqrt(z, BigFloat.precision) }
let exp(z:lent CBF):CBF { exp(z, BigFloat.precision) }
let log(z:lent CBF):CBF { log(z, BigFloat.precision) }
let sin(z:lent CBF):CBF { sin(z, BigFloat.precision) }
let cos(z:lent CBF):CBF { cos(z, BigFloat.precision) }
let tan(z:lent CBF):CBF { tan(z, BigFloat.precision) }
let sinh(z:lent CBF):CBF { sinh(z, BigFloat.precision) }
let cosh(z:lent CBF):CBF { cosh(z, BigFloat.precision) }
let tanh(z:lent CBF):CBF { tanh(z, BigFloat.precision) }
let asin(z:lent CBF):CBF { asin(z, BigFloat.precision) }
let acos(z:lent CBF):CBF { acos(z, BigFloat.precision) }
let atan(z:lent CBF):CBF { atan(z, BigFloat.precision) }
let asinh(z:lent CBF):CBF { asinh(z, BigFloat.precision) }
let acosh(z:lent CBF):CBF { acosh(z, BigFloat.precision) }
let atanh(z:lent CBF):CBF { atanh(z, BigFloat.precision) }
let pow(z:lent CBF, w:lent CBF):CBF { pow(z, w, BigFloat.precision) }
let pow(z:lent CBF, x:lent BigFloat):CBF { pow(z, x, BigFloat.precision) }
let pow(x:lent BigFloat, w:lent CBF):CBF { pow(x, w, BigFloat.precision) }

extend CBF {
    // each function as a method, z.exp(), z.exp(64)
    let abs():BigFloat { abs(self) }
    let abs(precision:i64):BigFloat { abs(self, precision) }
    let arg():BigFloat { arg(self) }
    let arg(precision:i64):BigFloat { arg(self, precision) }
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
    let sinh():Self { sinh(self) }
    let sinh(precision:i64):Self { sinh(self, precision) }
    let cosh():Self { cosh(self) }
    let cosh(precision:i64):Self { cosh(self, precision) }
    let tanh():Self { tanh(self) }
    let tanh(precision:i64):Self { tanh(self, precision) }
    let asin():Self { asin(self) }
    let asin(precision:i64):Self { asin(self, precision) }
    let acos():Self { acos(self) }
    let acos(precision:i64):Self { acos(self, precision) }
    let atan():Self { atan(self) }
    let atan(precision:i64):Self { atan(self, precision) }
    let asinh():Self { asinh(self) }
    let asinh(precision:i64):Self { asinh(self, precision) }
    let acosh():Self { acosh(self) }
    let acosh(precision:i64):Self { acosh(self, precision) }
    let atanh():Self { atanh(self) }
    let atanh(precision:i64):Self { atanh(self, precision) }
    let pow(w:lent Self):Self { pow(self, w) }
    let pow(w:lent Self, precision:i64):Self { pow(self, w, precision) }
}
