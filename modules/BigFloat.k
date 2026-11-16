// modules/BigFloat.k - a floating-point number of any precision (#576): a
// mantissa, a BigInt, times a power of 2,
//
//     #import <BigFloat>
//     let x = BigFloat(1) / 3                    // a third, to 128 bits
//     println(x.f64, " ", (x * 3).f64, " ", BigRat(x.round(8)))   // 0.33333333333333331 1.0 (171n/512n)
//
// It is a float of BigFloat.precision bits, 128 where a program sets no
// other: every result, of + - * / and of the making of one, is rounded to
// that many significant bits, the bits of the mantissa wherever the point
// is, to the nearest and of two as near to the even one, as an f64's are
// to its 53. So it never grows, as a BigRat does, and is seldom exact.
//
// x.round(precision) is x at another count of bits, and
// x.round(precision, rule) by one of six rules: BigFloat.nearestEven,
// which is the one where none is written, BigFloat.nearestAway,
// BigFloat.up, BigFloat.down, BigFloat.towardZero and
// BigFloat.awayFromZero.
//
// As an f64 it has infinities and a NaN, which equals nothing, and never
// divides by zero; it has one 0, with no sign, as a rational. BigRat(x) is
// its value exactly, and x.f64 the nearest f64.
#import <Rational>

// mantissa * 2^exponent, the mantissa odd, or 0 with an exponent of 0, so
// that a value has one form; special is 1 of an infinity, whose mantissa
// is 1 or -1 for its sign, 2 of a NaN, and 0 of every other
struct BigFloat {
    mantissa: BigInt
    exponent: i64
    special: i64
}

// how a number is rounded to fewer bits: one of BigFloat's six
struct RoundingRule {
    rule: i64
}

extend BigFloat {
    // the significant bits of every result; a program may set it, and
    // one below 1 is 1
    static var precision:i64 = 128

    // to the nearest, and of two as near: to the one whose last bit is
    // 0, IEEE 754's and the one where none is written; or to the one
    // away from 0
    static let nearestEven:RoundingRule = {0}
    static let nearestAway:RoundingRule = {1}
    // toward the greater, toward the less, toward 0 and away from it
    static let up:RoundingRule = {2}
    static let down:RoundingRule = {3}
    static let towardZero:RoundingRule = {4}
    static let awayFromZero:RoundingRule = {5}
}

// ---------- making one ----------

let BigFloat_nan():BigFloat { (BigFloat){BigInt(0), 0, 2} }
let BigFloat_inf(sign:i64):BigFloat { (BigFloat){BigInt(sign < 0 ? -1 : 1), 0, 1} }
let BigFloat_zero():BigFloat { (BigFloat){BigInt(0), 0, 0} }

// the precision of a result: BigFloat.precision, 1 at the least
let BigFloat_bits():i64 { BigFloat.precision < 1 ? 1 : BigFloat.precision }

// the bits of |x|: 0 of 0
let BigFloat_length(x:lent BigInt):i64 { x.abs.bits.count as i64 - 1 }

// m * 2^e rounded to precision significant bits by a rule, its mantissa
// made odd: every finite BigFloat is made here. A precision below 1 is
// taken as it is, for x.f64 of a number below an f64's: the bits above
// 2^(e + length - precision) are kept, which may be none. An exponent
// past an i64 is an infinity, and one below it 0
let BigFloat_make(m:lent BigInt, e:i128, precision:i64, rule:i64):BigFloat {
    if m.isZero { return BigFloat_zero() }
    let negative = m.isNegative
    var a = m.abs
    var x:i128 = e
    let n = BigFloat_length(a)
    if n > precision {
        let shift:i64 = n - precision
        let q = a >> shift
        let r = a - (q << shift)                         // what is cut off, less than 2^shift
        var more = false                                 // whether the magnitude goes up by one
        if !r.isZero {
            let half = BigInt(1) << (shift - 1)
            if rule == 0 {
                more = r > half || (r == half && !(q & BigInt(1)).isZero)
            } else if rule == 1 {
                more = r >= half
            } else if rule == 2 {
                more = !negative
            } else if rule == 3 {
                more = negative
            } else if rule == 5 {
                more = true
            }
        }
        a = more ? q + 1 : q.copy()
        x += shift as i128
        if a.isZero { return BigFloat_zero() }
    }
    let bits = a.bits                                    // the low bits that are 0 go to the exponent
    var low:i64 = 0
    while !bits[low] { low += 1 }
    if low > 0 {
        a = a >> low
        x += low as i128
    }
    if x > 9223372036854775807 { return BigFloat_inf(negative ? -1 : 1) }
    if x < -9223372036854775807 { return BigFloat_zero() }
    if negative { return (BigFloat){0 - a, x as i64, 0} }
    return (BigFloat){a.copy(), x as i64, 0}
}

// n / d * 2^e to precision bits by a rule, neither n nor d 0: the
// quotient to two bits more, and one below them that says whether
// anything is left, which the rounding reads
let BigFloat_quotient(n:lent BigInt, d:lent BigInt, e:i128, precision:i64, rule:i64):BigFloat {
    let negative = n.isNegative != d.isNegative
    let a = n.abs
    let b = d.abs
    var s:i64 = precision + 2 + BigFloat_length(b) - BigFloat_length(a)
    if s < 0 { s = 0 }
    let top = a << s
    var q = top / b
    var x:i128 = e - s as i128
    if q * b != top {
        q = (q << 1) + 1
        x -= 1
    }
    if negative { return BigFloat_make(0 - q, x, precision, rule) }
    return BigFloat_make(q, x, precision, rule)
}

// of an integer, a BigInt, an f64 and a rational: the nearest of
// BigFloat.precision bits, or of the precision written
let BigFloat(n:lent BigInt, precision:i64):BigFloat { BigFloat_make(n, 0, precision < 1 ? 1 : precision, 0) }
let BigFloat(n:lent BigInt):BigFloat { BigFloat_make(n, 0, BigFloat_bits(), 0) }
let BigFloat(n:i64, precision:i64):BigFloat { BigFloat_make(BigInt(n), 0, precision < 1 ? 1 : precision, 0) }
let BigFloat(n:i64):BigFloat { BigFloat_make(BigInt(n), 0, BigFloat_bits(), 0) }

// an f64 is a mantissa of 53 bits times a power of 2: brought between
// 2^52 and 2^53 by doublings and halvings, which lose nothing, it is a
// whole number
let BigFloat(x:f64, precision:i64):BigFloat {
    if x != x { return BigFloat_nan() }
    if x == 0.0 { return BigFloat_zero() }
    var y:f64 = x < 0.0 ? -x : x
    if y - y != 0.0 { return BigFloat_inf(x < 0.0 ? -1 : 1) }
    var e:i64 = 0
    while y < 4503599627370496.0 {
        y = y * 2.0
        e -= 1
    }
    while y >= 9007199254740992.0 {
        y = y * 0.5
        e += 1
    }
    let m:i64 = y as i64
    return BigFloat_make(BigInt(x < 0.0 ? -m : m), e as i128, precision < 1 ? 1 : precision, 0)
}
let BigFloat(x:f64):BigFloat { BigFloat(x, BigFloat_bits()) }

// a rational's infinity and its NaN are a BigFloat's
let BigFloat(r:lent BigRat, precision:i64):BigFloat {
    if r.isNaN { return BigFloat_nan() }
    if r.isInfinite { return BigFloat_inf(r.num.sign) }
    if r.num.isZero { return BigFloat_zero() }
    return BigFloat_quotient(r.num, r.den, 0, precision < 1 ? 1 : precision, 0)
}
let BigFloat(r:lent BigRat):BigFloat { BigFloat(r, BigFloat_bits()) }

// a BigFloat as a rational, exactly: its mantissa over a power of 2
let BigRat(x:lent BigFloat):BigRat {
    if x.special == 2 { return (BigRat){BigInt(0), BigInt(0)} }
    if x.special == 1 { return (BigRat){BigInt(x.mantissa.sign), BigInt(0)} }
    if x.exponent >= 0 { return (BigRat){x.mantissa << x.exponent, BigInt(1)} }
    return (BigRat){x.mantissa.copy(), BigInt(1) << (0 - x.exponent)}
}

// ---------- what it is ----------

extend BigFloat {
    let isNaN:bool { self.special == 2 }
    let isInfinite:bool { self.special == 1 }
    let isFinite:bool { self.special == 0 }

    // self at precision significant bits, by a rule or to the nearest
    // and the even one; a number of no more bits is itself, and so are an
    // infinity and a NaN
    let round(precision:i64, rule:RoundingRule):Self {
        if self.special != 0 { return self.copy() }
        return BigFloat_make(self.mantissa, self.exponent as i128, precision < 1 ? 1 : precision, rule.rule)
    }
    let round(precision:i64):Self { self.round(precision, BigFloat.nearestEven) }

    // the nearest f64, of two as near the even one: 53 bits of it, or the
    // fewer a number below 2^-1022 has above 2^-1074, scaled by its
    // exponent, which loses nothing; past an f64's range inf or -inf, and
    // below it 0
    let f64:f64 {
        if self.special == 2 { return f64.nan }
        let negative = self.mantissa.isNegative
        let inf:f64 = f64.infinity
        if self.special == 1 { return negative ? -inf : inf }
        if self.mantissa.isZero { return 0.0 }
        let top:i128 = self.exponent as i128 + BigFloat_length(self.mantissa) as i128
        if top > 1025 { return negative ? -inf : inf }
        if top < -1075 { return negative ? -0.0 : 0.0 }
        var p:i64 = 53
        if top < -1021 { p = (top + 1074) as i64 }
        let r = BigFloat_make(self.mantissa, self.exponent as i128, p, 0)
        if r.mantissa.isZero { return negative ? -0.0 : 0.0 }
        var x:f64 = r.mantissa.i64 as f64
        var k:i64 = r.exponent
        while k > 0 {
            x = x * 2.0
            k -= 1
        }
        while k < 0 {
            x = x * 0.5
            k += 1
        }
        return x
    }
}

// ---------- arithmetic ----------

// a + b of two finite numbers, to precision bits. Where b is all below
// a's last bit and below the last bit kept, by 4 places and more, it
// tells only which side of a the sum is: a bit 5 places below stands for
// it, so that no shift is as long as the exponents are apart
let BigFloat_sum(a:lent BigFloat, b:lent BigFloat, precision:i64):BigFloat {
    if a.mantissa.isZero { return BigFloat_make(b.mantissa, b.exponent as i128, precision, 0) }
    if b.mantissa.isZero { return BigFloat_make(a.mantissa, a.exponent as i128, precision, 0) }
    let ta:i128 = a.exponent as i128 + BigFloat_length(a.mantissa) as i128
    let tb:i128 = b.exponent as i128 + BigFloat_length(b.mantissa) as i128
    if tb > ta { return BigFloat_sum(b, a, precision) }
    var low:i128 = ta - precision as i128
    if a.exponent as i128 < low { low = a.exponent as i128 }
    low -= 4
    if tb < low {
        let s:i64 = (a.exponent as i128 - low + 1) as i64
        return BigFloat_make((a.mantissa << s) + b.mantissa.sign, low - 1, precision, 0)
    }
    let e:i128 = a.exponent < b.exponent ? a.exponent as i128 : b.exponent as i128
    let sa:i64 = (a.exponent as i128 - e) as i64
    let sb:i64 = (b.exponent as i128 - e) as i64
    return BigFloat_make((a.mantissa << sa) + (b.mantissa << sb), e, precision, 0)
}

// -1, 0 or 1 as a is below b, equal to it or above; neither is a NaN
let BigFloat_order(a:lent BigFloat, b:lent BigFloat):i64 {
    let sa = a.mantissa.sign
    let sb = b.mantissa.sign
    if sa != sb { return sa < sb ? -1 : 1 }
    if sa == 0 { return 0 }
    if a.special == 1 || b.special == 1 {
        if a.special == b.special { return 0 }
        return (a.special == 1) == (sa > 0) ? 1 : -1
    }
    let ta:i128 = a.exponent as i128 + BigFloat_length(a.mantissa) as i128
    let tb:i128 = b.exponent as i128 + BigFloat_length(b.mantissa) as i128
    if ta != tb { return (ta > tb) == (sa > 0) ? 1 : -1 }
    let e:i64 = a.exponent < b.exponent ? a.exponent : b.exponent
    let x = a.mantissa << (a.exponent - e)
    let y = b.mantissa << (b.exponent - e)
    return x < y ? -1 : x > y ? 1 : 0
}

extend BigFloat {
    // an infinity less itself is a NaN
    static let +(a:Self, b:Self):Self {
        if a.special == 2 || b.special == 2 { return BigFloat_nan() }
        if a.special == 1 {
            if b.special == 1 && a.mantissa.sign != b.mantissa.sign { return BigFloat_nan() }
            return a.copy()
        }
        if b.special == 1 { return b.copy() }
        return BigFloat_sum(a, b, BigFloat_bits())
    }
    static let +(a:Self, b:BigInt):Self { a + BigFloat(b) }
    static let +(a:BigInt, b:Self):Self { BigFloat(a) + b }
    static let +(a:Self, b:i64):Self { a + BigFloat(b) }
    static let +(a:i64, b:Self):Self { BigFloat(a) + b }
    static let -(a:Self):Self { (Self){0 - a.mantissa, a.exponent, a.special} }
    static let -(a:Self, b:Self):Self { a + -b }
    static let -(a:Self, b:BigInt):Self { a + -BigFloat(b) }
    static let -(a:BigInt, b:Self):Self { BigFloat(a) + -b }
    static let -(a:Self, b:i64):Self { a + -BigFloat(b) }
    static let -(a:i64, b:Self):Self { BigFloat(a) + -b }
    // 0 times an infinity is a NaN
    static let *(a:Self, b:Self):Self {
        if a.special == 2 || b.special == 2 { return BigFloat_nan() }
        if a.special == 1 || b.special == 1 {
            let sign:i64 = a.mantissa.sign * b.mantissa.sign
            if sign == 0 { return BigFloat_nan() }
            return BigFloat_inf(sign)
        }
        return BigFloat_make(a.mantissa * b.mantissa, a.exponent as i128 + b.exponent as i128, BigFloat_bits(), 0)
    }
    static let *(a:Self, b:BigInt):Self { a * BigFloat(b) }
    static let *(a:BigInt, b:Self):Self { BigFloat(a) * b }
    static let *(a:Self, b:i64):Self { a * BigFloat(b) }
    static let *(a:i64, b:Self):Self { BigFloat(a) * b }
    // by 0 it is an infinity, and 0 by 0 a NaN: no division by zero; an
    // infinity by a number has the quotient's sign, by 0 its own, and by
    // an infinity it is a NaN
    static let /(a:Self, b:Self):Self {
        if a.special == 2 || b.special == 2 { return BigFloat_nan() }
        if a.special == 1 {
            if b.special == 1 { return BigFloat_nan() }
            return BigFloat_inf(b.mantissa.isNegative ? 0 - a.mantissa.sign : a.mantissa.sign)
        }
        if b.special == 1 || a.mantissa.isZero {
            if b.mantissa.isZero { return BigFloat_nan() }
            return BigFloat_zero()
        }
        if b.mantissa.isZero { return BigFloat_inf(a.mantissa.sign) }
        return BigFloat_quotient(a.mantissa, b.mantissa, a.exponent as i128 - b.exponent as i128, BigFloat_bits(), 0)
    }
    static let /(a:Self, b:BigInt):Self { a / BigFloat(b) }
    static let /(a:BigInt, b:Self):Self { BigFloat(a) / b }
    static let /(a:Self, b:i64):Self { a / BigFloat(b) }
    static let /(a:i64, b:Self):Self { BigFloat(a) / b }

    // a NaN equals nothing and has no order, as a float's
    static let ==(a:Self, b:Self):bool { a.special != 2 && b.special != 2 && BigFloat_order(a, b) == 0 }
    static let !=(a:Self, b:Self):bool { !(a == b) }
    static let <(a:Self, b:Self):bool { a.special != 2 && b.special != 2 && BigFloat_order(a, b) < 0 }
    static let >(a:Self, b:Self):bool { b < a }
    static let <=(a:Self, b:Self):bool { a.special != 2 && b.special != 2 && BigFloat_order(a, b) <= 0 }
    static let >=(a:Self, b:Self):bool { b <= a }
}

// ---------- its text (#577) ----------

// 10^k and 2^k, of any k, as rationals
let BigFloat_ten(k:i64):BigRat {
    if k >= 0 { return (BigRat){BigInt(10) ** k, BigInt(1)} }
    return (BigRat){BigInt(1), BigInt(10) ** (0 - k)}
}
let BigFloat_two(k:i64):BigRat {
    if k >= 0 { return (BigRat){BigInt(1) << k, BigInt(1)} }
    return (BigRat){BigInt(1), BigInt(1) << (0 - k)}
}

// digits * 10^exponent, a decimal; found is whether there is one
struct BigFloat_decimal {
    digits: BigInt
    exponent: i64
    found: bool
}

// the multiple of 10^k nearest v that is between lo and hi, the ends
// too where closed: the one below v or the one above, of two as near the
// even one
let BigFloat_digits(v:lent BigRat, lo:lent BigRat, hi:lent BigRat, closed:bool, k:i64):BigFloat_decimal {
    let s = BigFloat_ten(k)
    let t = v / s
    let c = t.num / t.den
    var found = false
    var best = BigInt(0)
    var gap = BigRat(0)
    for j in 0..<2 {
        let d = c + j
        let w = BigRat(d) * s
        let inside = closed ? w >= lo && w <= hi : w > lo && w < hi
        if !inside { continue }
        let g = j == 0 ? v - w : w - v
        if !found || g < gap || (g == gap && !(best & BigInt(1)).isZero) {
            best = d.copy()
            gap = g.copy()
        }
        found = true
    }
    return (BigFloat_decimal){best.copy(), k, found}
}

// ---------- the text of a number far from 1 (#584) ----------

// a number far from 1, 2^1000000000000, is no rational: its text, and
// the reading of it, are of 5^k to as many bits as tell, and no more

// m * 2^e, which is 5^k or below it, by less than one part in
// 2^(bits - 65): 5^k of k from 0 up, by squarings, each cut to bits
// bits; cut is whether any was, and where none it is 5^k itself
struct BigFloat_power {
    m: BigInt
    e: i128
    cut: bool
}
let BigFloat_five(k:i64, bits:i64):BigFloat_power {
    var m = BigInt(1)
    var e:i128 = 0
    var cut = false
    var i:i64 = 62
    while i >= 0 {
        m = m * m
        e = e * 2
        if (k >> i) % 2 == 1 { m = m * 5 }
        let over:i64 = BigFloat_length(m) - bits
        if over > 0 {
            m = m >> over
            e += over as i128
            cut = true
        }
        i -= 1
    }
    return (BigFloat_power){m.copy(), e, cut}
}

// a * 2^s over p.m where down, and a * p.m * 2^s otherwise, cut to a
// whole number
let BigFloat_scaled(a:lent BigInt, p:lent BigFloat_power, s:i128, down:bool):BigInt {
    if down {
        if s >= 0 { return (a << (s as i64)) / p.m }
        return a / (p.m << ((0 - s) as i64))
    }
    let t = a * p.m
    if s >= 0 { return t << (s as i64) }
    return t >> ((0 - s) as i64)
}

// whether d is within by of 0
let BigFloat_near(d:lent BigInt, by:i64):bool { (d.abs - by).isNegative }

// what a probe finds: state is 0 where no multiple is between, 1 where
// digits is the one, and 2 where the bits are too few to tell
struct BigFloat_probe {
    digits: BigInt
    state: i64
}

// the multiple of step nearest v that is between lo and hi, as
// BigFloat_digits finds it, of whole numbers: v, lo and hi are each
// within 2 of what they stand for, so a multiple that near one of them,
// and two as near v as that, are not told
let BigFloat_far_digits(v:lent BigInt, lo:lent BigInt, hi:lent BigInt, step:lent BigInt):BigFloat_probe {
    let c = v / step
    let r = v - c * step
    if BigFloat_near(r, 2) || BigFloat_near(step - r, 2) { return (BigFloat_probe){BigInt(0), 2} }
    var found = false
    var best = BigInt(0)
    for j in 0..<2 {
        let w = (c + j) * step
        let below = w - lo
        let above = hi - w
        if BigFloat_near(below, 2) || BigFloat_near(above, 2) { return (BigFloat_probe){BigInt(0), 2} }
        if below.isNegative || above.isNegative { continue }
        if found {
            let t = r + r - step                         // above 0 where v is nearer the second
            if BigFloat_near(t, 4) { return (BigFloat_probe){BigInt(0), 2} }
            if !t.isNegative { best = c + j }
        } else {
            best = c + j
        }
        found = true
    }
    return (BigFloat_probe){best.copy(), found ? 1 : 0}
}

// the fewest digits of a number far from 1, as BigFloat_shortest finds
// them of any: |x|, and the two ends of what rounds to it, are divided
// by a power of 10 that leaves digits enough before the point, to guard
// bits after it, and each multiple of a power of 10 is tried against
// those. So far out no multiple is one of the three, nor midway between
// two that are tried: with bits enough every one is told, and they are
// added until it is
let BigFloat_far_shortest(x:lent BigFloat, q:i64):BigFloat_decimal {
    let a = x.mantissa.abs
    let n = BigFloat_length(a)
    let top:i128 = x.exponent as i128 + n as i128
    let unit:i128 = top - q as i128 - 2                  // |x|, and the ends, are whole numbers of 2^unit
    let av = a << (q + 2 - n)
    let alo = av - (n == 1 ? 1 : 2)
    let ahi = av + 2
    let two32:i128 = 4294967296
    var e10:i64 = ((top - 1) * 5553023288523357132 / (two32 * two32)) as i64   // the power of 10 of its first digit, or one off: log10(2) is 5553023288523357132 / 2^64
    var most:i64 = q * 30103 / 100000 + 3                // digits that are enough
    var guard:i64 = 64
    var result = (BigFloat_decimal){BigInt(0), 0, false}
    while !result.found {
        let k:i64 = e10 - most
        let width:i64 = (most + 3) * 10 / 3 + 8 + guard  // the bits of the three, divided, at the most
        let p = BigFloat_five(k < 0 ? 0 - k : k, width + 72)
        let s:i128 = k >= 0 ? unit + guard as i128 - k as i128 - p.e : unit + guard as i128 - k as i128 + p.e
        let v = BigFloat_scaled(av, p, s, k >= 0)
        let ten = BigInt(10)
        if v < (ten.pow(most - 1) << guard) {            // the first digit is one lower
            e10 -= 1
            continue
        }
        if v >= (ten.pow(most + 2) << guard) {
            e10 += 1
            continue
        }
        let lo = BigFloat_scaled(alo, p, s, k >= 0)
        let hi = BigFloat_scaled(ahi, p, s, k >= 0)
        var r = BigFloat_far_digits(v, lo, hi, BigInt(1) << guard)
        if r.state == 0 {
            most += 8
            continue
        }
        var least:i64 = 0                                // the powers of 10 a multiple of which is between
        var last:i64 = most + 2
        while r.state == 1 && least < last {
            let mid:i64 = (least + last + 1) / 2
            let t = BigFloat_far_digits(v, lo, hi, ten.pow(mid) << guard)
            if t.state == 1 {
                least = mid
                r = (BigFloat_probe){t.digits.copy(), 1}
            } else if t.state == 0 {
                last = mid - 1
            } else {
                r = (BigFloat_probe){BigInt(0), 2}
            }
        }
        if r.state != 1 {                                // not told: with more bits
            guard += 64
            continue
        }
        var digits = r.digits.copy()
        var exponent:i64 = k + least
        while (digits % ten).isZero {
            digits = digits / ten
            exponent += 1
        }
        result = (BigFloat_decimal){digits.copy(), exponent, true}
    }
    return result
}

// m / d * 10^k to precision bits, the nearest, neither m nor d 0 and
// both of digits digits together, k so far from 0 that it is no number
// of that many bits, nor midway between two: of 5^|k| and of what it is
// below, and where the two do not round to one number, of more bits; of
// 5^|k| itself where that is no longer
let BigFloat_far_read(m:lent BigInt, d:lent BigInt, k:i128, digits:i64, precision:i64):BigFloat {
    let edge:i128 = 4000000000000000000 + digits as i128 // 10 to this is past any exponent
    if k > edge { return BigFloat_inf(m.isNegative != d.isNegative ? -1 : 1) }
    if 0 - k > edge { return BigFloat_zero() }
    let size:i64 = (k < 0 ? 0 - k : k) as i64
    var bits:i64 = precision + 130
    var result = BigFloat_nan()
    var done = false
    while !done {
        let p = BigFloat_five(size, bits)
        var more = p.m.copy()                            // what 5^|k| is below, or itself
        if p.cut { more = p.m + (p.m >> (bits - 65)) + 1 }
        if k > 0 {
            let lo = BigFloat_quotient(m * p.m, d, p.e + k, precision, 0)
            let hi = BigFloat_quotient(m * more, d, p.e + k, precision, 0)
            done = lo.special == hi.special && lo.exponent == hi.exponent && lo.mantissa == hi.mantissa
            result = lo.copy()
        } else {
            let hi = BigFloat_quotient(m, d * p.m, k - p.e, precision, 0)
            let lo = BigFloat_quotient(m, d * more, k - p.e, precision, 0)
            done = lo.special == hi.special && lo.exponent == hi.exponent && lo.mantissa == hi.mantissa
            result = lo.copy()
        }
        bits += 64
    }
    return result
}

// the power of 10 of the number at text[at], which BigRat_part read: its
// exponent less its digits after the point, the exponent in full, where
// a rational's is cut at what it can hold
let BigFloat_tens(text:cstr, at:i64):i128 {
    var p:i64 = at
    if text[p] == '+' as u8 || text[p] == '-' as u8 { p += 1 }
    while rat_digit(text[p], 10) { p += 1 }
    var fracs:i64 = 0
    if text[p] == '.' as u8 {
        var t:i64 = p + 1
        while rat_digit(text[t], 10) { t += 1 }
        fracs = t - p - 1
        p = t
    }
    var x:i128 = 0
    if text[p] == 'e' as u8 || text[p] == 'E' as u8 {
        var t:i64 = p + 1
        var down = false
        if text[t] == '+' as u8 || text[t] == '-' as u8 {
            down = text[t] == '-' as u8
            t += 1
        }
        while rat_digit(text[t], 10) {
            if x < 1000000000000000000 { x = x * 10 + (text[t] - '0' as u8) as i128 }
            t += 1
        }
        if down { x = 0 - x }
    }
    return x - fracs as i128
}

// the fewest digits that read back as |x| at q bits, q no fewer than
// its own; x is finite and not 0. What rounds to x is between the
// halves of the gaps to its neighbours of q bits, the one below half as
// far where x is a power of 2, and the ends too where its last bit of q
// is 0, which a tie rounds to. With more digits there is one between
// too, so the fewest are found by halving
let BigFloat_shortest(x:lent BigFloat, q:i64):BigFloat_decimal {
    let a = x.mantissa.abs
    let n = BigFloat_length(a)
    let far:i128 = x.exponent as i128 + n as i128
    if far > 8 * q as i128 + 256 || 0 - far > 8 * q as i128 + 256 { return BigFloat_far_shortest(x, q) }
    let top:i64 = x.exponent + n
    let v = x.exponent >= 0 ? (BigRat){a << x.exponent, BigInt(1)} : (BigRat){a.copy(), BigInt(1) << (0 - x.exponent)}
    let up = BigFloat_two(top - q - 1)
    let down = BigFloat_two(n == 1 ? top - q - 2 : top - q - 1)
    let lo = v - down
    let hi = v + up
    let closed = n < q
    var e10:i64 = (top - 1) * 30103 / 100000           // the power of 10 of its first digit: about, then exactly
    while BigFloat_ten(e10 + 1) <= v { e10 += 1 }
    while BigFloat_ten(e10) > v { e10 -= 1 }
    var most:i64 = q * 30103 / 100000 + 3              // digits that are enough
    var r = BigFloat_digits(v, lo, hi, closed, e10 + 1 - most)
    while !r.found {
        most += 8
        r = BigFloat_digits(v, lo, hi, closed, e10 + 1 - most)
    }
    var least:i64 = 1
    while least < most {
        let mid:i64 = (least + most) / 2
        let t = BigFloat_digits(v, lo, hi, closed, e10 + 1 - mid)
        if t.found {
            most = mid
            r = (BigFloat_decimal){t.digits.copy(), t.exponent, true}
        } else {
            least = mid + 1
        }
    }
    var digits = r.digits.copy()
    var exponent:i64 = r.exponent
    while (digits % BigInt(10)).isZero {
        digits = digits / BigInt(10)
        exponent += 1
    }
    return (BigFloat_decimal){digits.copy(), exponent, true}
}

// its decimal text, as an f64's is laid out: plain from 0.0001 up to
// 2^q, where every integer is exact, with a point, 1.0, and with an
// exponent otherwise, 1e+40, 1.5e-05; plus is a + before one that is
// not negative, as x.dec has
let BigFloat_text(x:lent BigFloat, plus:bool):String {
    if x.special == 2 { return $"nan" }
    let sign:cstr := x.mantissa.isNegative ? "-" : plus ? "+" : ""
    if x.special == 1 { return $`${sign}inf` }
    if x.mantissa.isZero { return $`${sign}0.0` }
    var s = $""
    s += sign
    let n = BigFloat_length(x.mantissa)
    let bits = BigFloat_bits()
    let q:i64 = n > bits ? n : bits
    let r = BigFloat_shortest(x, q)
    let text = r.digits.string
    let d:cstr := text.cstr
    var count:i64 = 0
    while rat_digit(d[count], 10) { count += 1 }         // a BigInt's text ends in n
    let e:i64 = count - 1 + r.exponent                   // the power of 10 of the first digit
    let top:i128 = x.exponent as i128 + n as i128
    if e < 0 - 4 || top > q as i128 + 1 || (top == q as i128 + 1 && n > 1) {
        s += d[0]
        if count > 1 {
            s += '.'
            for i in 1..<count { s += d[i] }
        }
        s += 'e'
        s += e < 0 ? '-' : '+'
        let size:i64 = e < 0 ? 0 - e : e
        if size < 10 { s += '0' }
        let tail = $`${size}`
        s += &tail
    } else if e < 0 {
        s += "0."
        for i in 0..<(0 - e - 1) { s += '0' }
        for i in 0..<count { s += d[i] }
    } else {
        for i in 0..<count {
            if i == e + 1 { s += '.' }
            s += d[i]
        }
        for i in count..<(e + 1) { s += '0' }
        if count <= e + 1 { s += ".0" }
    }
    return s
}

// a hex digit's value, or -1
let BigFloat_hex(c:u8):i64 {
    if c >= '0' as u8 && c <= '9' as u8 { return (c - '0' as u8) as i64 }
    if c >= 'a' as u8 && c <= 'f' as u8 { return (c - 'a' as u8) as i64 + 10 }
    if c >= 'A' as u8 && c <= 'F' as u8 { return (c - 'A' as u8) as i64 + 10 }
    return 0 - 1
}

let BigFloat_blank(c:u8):bool { c == ' ' as u8 || (c >= 9 && c <= 13) }

// a BigFloat of its text, to precision bits: a decimal, 0.1, 1.5e-3,
// and what else a BigRat is read from, 1/3, read exactly and then
// rounded; a hex float, 0x1.8p+1, C's; inf and nan, with a sign or
// none. All of the text is read, blanks at its ends aside, and text
// that is none is a NaN. A rational's text whose power of 10 is far
// from 0, 1e1000000000, is no rational: it is laid out as BigRat_read
// lays it out, and BigFloat_far_read has the nearest (#584)
let BigFloat_read(text:cstr, precision:i64):BigFloat {
    var i:i64 = 0
    while BigFloat_blank(text[i]) { i += 1 }
    var j:i64 = i
    var negative = false
    if text[j] == '+' as u8 || text[j] == '-' as u8 {
        negative = text[j] == '-' as u8
        j += 1
    }
    if (text[j] == 'i' as u8 && text[j + 1] == 'n' as u8 && text[j + 2] == 'f' as u8) || (text[j] == 'n' as u8 && text[j + 1] == 'a' as u8 && text[j + 2] == 'n' as u8) {
        let nan = text[j] == 'n' as u8
        j += 3
        while BigFloat_blank(text[j]) { j += 1 }
        if text[j] != 0 || nan { return BigFloat_nan() }
        return BigFloat_inf(negative ? -1 : 1)
    }
    if text[j] == '0' as u8 && (text[j + 1] == 'x' as u8 || text[j + 1] == 'X' as u8) {
        j += 2
        var m = BigInt(0)
        var digits:i64 = 0
        var fracs:i64 = 0
        while BigFloat_hex(text[j]) >= 0 {
            m = (m << 4) + BigFloat_hex(text[j])
            digits += 1
            j += 1
        }
        if text[j] == '.' as u8 {
            j += 1
            while BigFloat_hex(text[j]) >= 0 {
                m = (m << 4) + BigFloat_hex(text[j])
                digits += 1
                fracs += 1
                j += 1
            }
        }
        if digits == 0 { return BigFloat_nan() }
        var e:i128 = 0
        if text[j] == 'p' as u8 || text[j] == 'P' as u8 {
            j += 1
            var minus = false
            if text[j] == '+' as u8 || text[j] == '-' as u8 {
                minus = text[j] == '-' as u8
                j += 1
            }
            if !rat_digit(text[j], 10) { return BigFloat_nan() }
            while rat_digit(text[j], 10) {
                if e < 4611686018427387904 { e = e * 10 + (text[j] - '0' as u8) as i128 }
                j += 1
            }
            if minus { e = 0 - e }
        }
        while BigFloat_blank(text[j]) { j += 1 }
        if text[j] != 0 { return BigFloat_nan() }
        if negative { m = 0 - m }
        return BigFloat_make(m, e - 4 * fracs as i128, precision, 0)
    }
    var a:i64 = i                                        // a rational's text, as BigRat_read lays it out
    var open = false
    if text[a] == '(' as u8 {
        open = true
        a += 1
        while BigFloat_blank(text[a]) { a += 1 }
    }
    let up = BigRat_part(text, a, 10)
    if up.end < 0 { return BigFloat_nan() }
    var k:i128 = BigFloat_tens(text, a)
    var digits:i64 = up.digits
    var den = BigInt(1)
    var b:i64 = up.end
    while BigFloat_blank(text[b]) { b += 1 }
    if text[b] == '/' as u8 {
        b += 1
        while BigFloat_blank(text[b]) { b += 1 }
        let down = BigRat_part(text, b, 10)
        if down.end < 0 { return BigFloat_nan() }
        k -= BigFloat_tens(text, b)
        digits += down.digits
        den = down.m.copy()
        b = down.end
        while BigFloat_blank(text[b]) { b += 1 }
    }
    if open {
        if text[b] != ')' as u8 { return BigFloat_nan() }
        b += 1
        while BigFloat_blank(text[b]) { b += 1 }
    }
    if text[b] != 0 { return BigFloat_nan() }
    let far:i128 = precision as i128 + 4 * digits as i128 + 64
    if !up.m.isZero && !den.isZero && (k > far || 0 - k > far) { return BigFloat_far_read(up.m, den, k, digits, precision) }   // too far from 1 to be read exactly (#584)
    return BigFloat(BigRat(text), precision)
}
let BigFloat(text:cstr, precision:i64):BigFloat { BigFloat_read(text, precision < 1 ? 1 : precision) }
let BigFloat(text:cstr):BigFloat { BigFloat_read(text, BigFloat_bits()) }
let BigFloat(text:const String^, precision:i64):BigFloat { BigFloat_read(text^.cstr, precision < 1 ? 1 : precision) }
let BigFloat(text:const String^):BigFloat { BigFloat_read(text^.cstr, BigFloat_bits()) }

extend BigFloat {
    // its text, which print shows and .cstr gives: the fewest digits
    // that BigFloat(text) reads back as it at BigFloat.precision bits, or
    // at its own where it has more
    let string:String { BigFloat_text(self, false) }

    // the same with a sign, +1.5, as an f64's
    let dec:String { BigFloat_text(self, true) }

    // C's %a with a sign, +0x1.8p+1, its value exactly: the bits after
    // the first as hex digits, and the power of 2 of the first
    let hex:String {
        if self.special == 2 { return $"nan" }
        let sign:cstr := self.mantissa.isNegative ? "-" : "+"
        if self.special == 1 { return $`${sign}inf` }
        if self.mantissa.isZero { return $`${sign}0x0p+0` }
        var s = $""
        s += sign
        let a = self.mantissa.abs
        let n = BigFloat_length(a)
        s += "0x1"
        if n > 1 {
            let pad:i64 = (4 - (n - 1) % 4) % 4
            let frac = (a - (BigInt(1) << (n - 1))) << pad
            let text = frac.text(16)
            let d:cstr := text.cstr
            var count:i64 = 0
            while BigFloat_hex(d[count]) >= 0 { count += 1 }
            s += '.'
            for i in count..<((n - 1 + pad) / 4) { s += '0' }
            for i in 0..<count { s += d[i] }
        }
        let p:i128 = self.exponent as i128 + n as i128 - 1
        s += 'p'
        s += p < 0 ? '-' : '+'
        let size:i128 = p < 0 ? 0 - p : p
        let tail = $`${size}`
        s += &tail
        return s
    }
}
