// modules/Rational.k - rational numbers (#538): a numerator over a
// denominator, each an integer, kept in lowest terms with the denominator
// 0 or more.
//
//     #import <Rational>
//     let r = 1.over(3) + 1.over(6)              // (1/2), a rat64
//     println(r, " ", r.f64, " ", 1.over(0))     // (1/2) 0.5 (1/0)
//
// A rational is treated a little like a floating-point number, which it
// can also stand for: a denominator of 0 is no division by zero but an
// infinity, (1/0) and (-1/0), and (0/0) is a NaN, which equals nothing,
// itself included. A result whose numerator or denominator does not fit
// its integers is a NaN too. A rational shows as (num/den).
//
// rat64 is of two i64s; n.over(d) of two i64s makes one.

struct rat64 {
    num: i64
    den: i64
}

// ---------- making one ----------

// the greatest common divisor of two magnitudes, Euclid's
let rat_gcd(a:i128, b:i128):i128 {
    var x:i128 = a
    var y:i128 = b
    while y != 0 {
        let t:i128 = x % y
        x = y
        y = t
    }
    return x
}

// n over d in lowest terms, d 0 or more: of 0 a sign over 0, an infinity,
// or (0/0), a NaN; a NaN too where a part does not fit an i64
let rat64_lowest(n:i128, d:i128):rat64 {
    var num:i128 = n
    var den:i128 = d
    if den < 0 {
        num = -num
        den = -den
    }
    if den == 0 { return (rat64){num > 0 ? 1 : num < 0 ? -1 : 0, 0} }
    if num == 0 { return (rat64){0, 1} }
    let g:i128 = rat_gcd(num < 0 ? -num : num, den)
    num /= g
    den /= g
    let most:i128 = 9223372036854775807
    if num > most || num < -most - 1 || den > most { return (rat64){0, 0} }
    return (rat64){num as i64, den as i64}
}

let rat64(num:i64, den:i64):rat64 { rat64_lowest(num as i128, den as i128) }
let rat64(num:i64):rat64 { (rat64){num, 1} }

extend i64 {
    // n.over(d) is (n/d)
    let over(den:i64):rat64 { rat64_lowest(self as i128, den as i128) }
}

// ---------- what it is, and its text ----------

// (num/den) of two texts
let rat_text(num:cstr, den:cstr):String {
    var s = $"("
    s += num
    s += "/"
    s += den
    s += ")"
    return s
}

extend rat64 {
    let isNaN:bool { self.num == 0 && self.den == 0 }
    let isInfinite:bool { self.num != 0 && self.den == 0 }
    let isFinite:bool { self.den != 0 }

    // the nearest f64: an infinity's is inf or -inf, a NaN's nan
    let f64:f64 { self.num as f64 / self.den as f64 }

    // (num.hex/den.hex), and the same in base 8 and base 2
    let hex:String { rat_text(self.num.hex, self.den.hex) }
    let oct:String { rat_text(self.num.oct, self.den.oct) }
    let bin:String { rat_text(self.num.bin, self.den.bin) }
}

// its text: (1/3), (-1/3), (1/0) of an infinity, (0/0) of a NaN
let rat64.cstr():cstr { `(${.num}/${.den})` }

// ---------- arithmetic ----------

extend rat64 {
    static let +(a:Self, b:Self):Self {
        if a.den == 0 && b.den == 0 {                    // two infinities: the same one, else a NaN
            return a.num == b.num ? a : (Self){0, 0}
        }
        return rat64_lowest(a.num as i128 * b.den as i128 + b.num as i128 * a.den as i128, a.den as i128 * b.den as i128)
    }
    static let +(a:Self, b:i64):Self { a + rat64(b) }
    static let +(a:i64, b:Self):Self { rat64(a) + b }
    static let -(a:Self):Self { rat64_lowest(-(a.num as i128), a.den as i128) }
    static let -(a:Self, b:Self):Self { a + -b }
    static let -(a:Self, b:i64):Self { a + -rat64(b) }
    static let -(a:i64, b:Self):Self { rat64(a) + -b }
    static let *(a:Self, b:Self):Self {
        rat64_lowest(a.num as i128 * b.num as i128, a.den as i128 * b.den as i128)
    }
    static let *(a:Self, b:i64):Self { a * rat64(b) }
    static let *(a:i64, b:Self):Self { rat64(a) * b }
    // by 0 it is an infinity, and 0 by 0 a NaN: no division by zero
    static let /(a:Self, b:Self):Self {
        rat64_lowest(a.num as i128 * b.den as i128, a.den as i128 * b.num as i128)
    }
    static let /(a:Self, b:i64):Self { a / rat64(b) }
    static let /(a:i64, b:Self):Self { rat64(a) / b }

    // a NaN equals nothing and has no order, as a float's
    static let ==(a:Self, b:Self):bool { !a.isNaN && !b.isNaN && a.num == b.num && a.den == b.den }
    static let !=(a:Self, b:Self):bool { !(a == b) }
    static let <(a:Self, b:Self):bool {
        if a.isNaN || b.isNaN { return false }
        if a.den == 0 && b.den == 0 { return a.num < b.num }
        return a.num as i128 * b.den as i128 < b.num as i128 * a.den as i128
    }
    static let >(a:Self, b:Self):bool { b < a }
    static let <=(a:Self, b:Self):bool { a < b || a == b }
    static let >=(a:Self, b:Self):bool { b < a || a == b }
}
