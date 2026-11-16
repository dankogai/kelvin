// modules/math+BigFloat.k - the overlay of math with BigFloat (#579): read
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

// ln x: x is s * 2^t, s from 1 up to 2, so ln x is ln s and t times
// ln 2; near 1 the two all but cancel, and more bits are taken
let BigFloat_log(x:lent BigFloat, bits:i64):BigFloat {
    if x.special != 0 || x.mantissa.sign <= 0 { return BigFloat_by(2, x, x, bits, true) }
    let n = BigFloat_length(x.mantissa)
    let t:i128 = x.exponent as i128 + n as i128 - 1
    if n == 1 && t == 0 { return BigFloat_zero() }
    let s:BigRat = (BigRat){x.mantissa.copy(), BigInt(1) << (n - 1)}
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

// x to the y: e^(y ln x) of an x above 0; of a negative x and a whole
// y it is of |x|, with the sign where y is odd, and of one not whole a
// NaN; of a 0, an infinity or a NaN, a BigRat's
let BigFloat_pow(x:lent BigFloat, y:lent BigFloat, bits:i64):BigFloat {
    if x.special != 0 || y.special != 0 || x.mantissa.isZero || y.mantissa.isZero { return BigFloat_by(16, x, y, bits, true) }
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
        if f == 11 { return BigFloat_by(f, x, x, bits, false) }
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
let sin(x:lent BigFloat, precision:i64):BigFloat { BigFloat_odd(3, x, precision < 1 ? 1 : precision) }
let cos(x:lent BigFloat, precision:i64):BigFloat { BigFloat_by(4, x, x, precision < 1 ? 1 : precision, x.special != 0) }
let tan(x:lent BigFloat, precision:i64):BigFloat { BigFloat_odd(5, x, precision < 1 ? 1 : precision) }
let asin(x:lent BigFloat, precision:i64):BigFloat { BigFloat_odd(6, x, precision < 1 ? 1 : precision) }
// acos(1) is 0, and so is acosh(1)
let acos(x:lent BigFloat, precision:i64):BigFloat {
    BigFloat_by(7, x, x, precision < 1 ? 1 : precision, x.special != 0 || x == BigFloat(1))
}
let atan(x:lent BigFloat, precision:i64):BigFloat { BigFloat_odd(8, x, precision < 1 ? 1 : precision) }
// of a y that is 0 it is 0 or pi, by the sign of x
let atan2(y:lent BigFloat, x:lent BigFloat, precision:i64):BigFloat {
    let exact = y.special != 0 || x.special != 0 || (y.mantissa.isZero && !x.mantissa.isNegative)
    return BigFloat_by(9, y, x, precision < 1 ? 1 : precision, exact)
}
let sinh(x:lent BigFloat, precision:i64):BigFloat { BigFloat_hyper(10, x, precision < 1 ? 1 : precision) }
let cosh(x:lent BigFloat, precision:i64):BigFloat { BigFloat_hyper(11, x, precision < 1 ? 1 : precision) }
let tanh(x:lent BigFloat, precision:i64):BigFloat { BigFloat_hyper(12, x, precision < 1 ? 1 : precision) }
let asinh(x:lent BigFloat, precision:i64):BigFloat { BigFloat_odd(13, x, precision < 1 ? 1 : precision) }
let acosh(x:lent BigFloat, precision:i64):BigFloat {
    BigFloat_by(14, x, x, precision < 1 ? 1 : precision, x.special != 0 || x == BigFloat(1))
}
let atanh(x:lent BigFloat, precision:i64):BigFloat { BigFloat_odd(15, x, precision < 1 ? 1 : precision) }

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
