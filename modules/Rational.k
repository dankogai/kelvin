// modules/Rational.k - rational numbers (#538, #539): a numerator over a
// denominator, each a signed integer, kept in lowest terms with the
// denominator 0 or more.
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
// rat64 is of two i64s, and rat32, rat16 and rat8 of two i32s, i16s and
// i8s, small as those are; n.over(d) of two integers of one signed type
// makes the rational of that type. Two widths do not mix: rat64(r) and
// its kin convert, a NaN where the narrower does not hold it.


struct rat64 {
    num: i64
    den: i64
}

struct rat32 {
    num: i32
    den: i32
}

struct rat16 {
    num: i16
    den: i16
}

struct rat8 {
    num: i8
    den: i8
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

// n over d in lowest terms, d 0 or more, its parts within most, the most
// of the integer they are to fit: of 0 a sign over 0, an infinity, or
// (0/0), a NaN; a NaN too where a part does not fit
let rat_lowest(n:i128, d:i128, most:i128):rat64 {
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
    if num > most || num < -most - 1 || den > most { return (rat64){0, 0} }
    return (rat64){num as i64, den as i64}
}

let rat64_lowest(n:i128, d:i128):rat64 { rat_lowest(n, d, 9223372036854775807) }
let rat32_lowest(n:i128, d:i128):rat32 {
    let r:rat64 = rat_lowest(n, d, 2147483647)
    return (rat32){r.num as i32, r.den as i32}
}
let rat16_lowest(n:i128, d:i128):rat16 {
    let r:rat64 = rat_lowest(n, d, 32767)
    return (rat16){r.num as i16, r.den as i16}
}
let rat8_lowest(n:i128, d:i128):rat8 {
    let r:rat64 = rat_lowest(n, d, 127)
    return (rat8){r.num as i8, r.den as i8}
}

let rat64(num:i64, den:i64):rat64 { rat64_lowest(num as i128, den as i128) }
let rat64(num:i64):rat64 { (rat64){num, 1} }
let rat32(num:i32, den:i32):rat32 { rat32_lowest(num as i128, den as i128) }
let rat32(num:i32):rat32 { (rat32){num, 1} }
let rat16(num:i16, den:i16):rat16 { rat16_lowest(num as i128, den as i128) }
let rat16(num:i16):rat16 { (rat16){num, 1} }
let rat8(num:i8, den:i8):rat8 { rat8_lowest(num as i128, den as i128) }
let rat8(num:i8):rat8 { (rat8){num, 1} }

// of another width: the same value, or a NaN where the narrower does not
// hold it
let rat64(r:rat32):rat64 { rat64_lowest(r.num as i128, r.den as i128) }
let rat64(r:rat16):rat64 { rat64_lowest(r.num as i128, r.den as i128) }
let rat64(r:rat8):rat64 { rat64_lowest(r.num as i128, r.den as i128) }
let rat32(r:rat64):rat32 { rat32_lowest(r.num as i128, r.den as i128) }
let rat32(r:rat16):rat32 { rat32_lowest(r.num as i128, r.den as i128) }
let rat32(r:rat8):rat32 { rat32_lowest(r.num as i128, r.den as i128) }
let rat16(r:rat64):rat16 { rat16_lowest(r.num as i128, r.den as i128) }
let rat16(r:rat32):rat16 { rat16_lowest(r.num as i128, r.den as i128) }
let rat16(r:rat8):rat16 { rat16_lowest(r.num as i128, r.den as i128) }
let rat8(r:rat64):rat8 { rat8_lowest(r.num as i128, r.den as i128) }
let rat8(r:rat32):rat8 { rat8_lowest(r.num as i128, r.den as i128) }
let rat8(r:rat16):rat8 { rat8_lowest(r.num as i128, r.den as i128) }

// n.over(d) is (n/d), of the signed integer type of n
extend i64 {
    let over(den:i64):rat64 { rat64_lowest(self as i128, den as i128) }
}
extend i32 {
    let over(den:i32):rat32 { rat32_lowest(self as i128, den as i128) }
}
extend i16 {
    let over(den:i16):rat16 { rat16_lowest(self as i128, den as i128) }
}
extend i8 {
    let over(den:i8):rat8 { rat8_lowest(self as i128, den as i128) }
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

extend rat32 {
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
let rat32.cstr():cstr { `(${.num}/${.den})` }

extend rat16 {
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
let rat16.cstr():cstr { `(${.num}/${.den})` }

extend rat8 {
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
let rat8.cstr():cstr { `(${.num}/${.den})` }

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

extend rat32 {
    static let +(a:Self, b:Self):Self {
        if a.den == 0 && b.den == 0 {                    // two infinities: the same one, else a NaN
            return a.num == b.num ? a : (Self){0, 0}
        }
        return rat32_lowest(a.num as i128 * b.den as i128 + b.num as i128 * a.den as i128, a.den as i128 * b.den as i128)
    }
    static let +(a:Self, b:i32):Self { a + rat32(b) }
    static let +(a:i32, b:Self):Self { rat32(a) + b }
    static let -(a:Self):Self { rat32_lowest(-(a.num as i128), a.den as i128) }
    static let -(a:Self, b:Self):Self { a + -b }
    static let -(a:Self, b:i32):Self { a + -rat32(b) }
    static let -(a:i32, b:Self):Self { rat32(a) + -b }
    static let *(a:Self, b:Self):Self {
        rat32_lowest(a.num as i128 * b.num as i128, a.den as i128 * b.den as i128)
    }
    static let *(a:Self, b:i32):Self { a * rat32(b) }
    static let *(a:i32, b:Self):Self { rat32(a) * b }
    // by 0 it is an infinity, and 0 by 0 a NaN: no division by zero
    static let /(a:Self, b:Self):Self {
        rat32_lowest(a.num as i128 * b.den as i128, a.den as i128 * b.num as i128)
    }
    static let /(a:Self, b:i32):Self { a / rat32(b) }
    static let /(a:i32, b:Self):Self { rat32(a) / b }

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

extend rat16 {
    static let +(a:Self, b:Self):Self {
        if a.den == 0 && b.den == 0 {                    // two infinities: the same one, else a NaN
            return a.num == b.num ? a : (Self){0, 0}
        }
        return rat16_lowest(a.num as i128 * b.den as i128 + b.num as i128 * a.den as i128, a.den as i128 * b.den as i128)
    }
    static let +(a:Self, b:i16):Self { a + rat16(b) }
    static let +(a:i16, b:Self):Self { rat16(a) + b }
    static let -(a:Self):Self { rat16_lowest(-(a.num as i128), a.den as i128) }
    static let -(a:Self, b:Self):Self { a + -b }
    static let -(a:Self, b:i16):Self { a + -rat16(b) }
    static let -(a:i16, b:Self):Self { rat16(a) + -b }
    static let *(a:Self, b:Self):Self {
        rat16_lowest(a.num as i128 * b.num as i128, a.den as i128 * b.den as i128)
    }
    static let *(a:Self, b:i16):Self { a * rat16(b) }
    static let *(a:i16, b:Self):Self { rat16(a) * b }
    // by 0 it is an infinity, and 0 by 0 a NaN: no division by zero
    static let /(a:Self, b:Self):Self {
        rat16_lowest(a.num as i128 * b.den as i128, a.den as i128 * b.num as i128)
    }
    static let /(a:Self, b:i16):Self { a / rat16(b) }
    static let /(a:i16, b:Self):Self { rat16(a) / b }

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

extend rat8 {
    static let +(a:Self, b:Self):Self {
        if a.den == 0 && b.den == 0 {                    // two infinities: the same one, else a NaN
            return a.num == b.num ? a : (Self){0, 0}
        }
        return rat8_lowest(a.num as i128 * b.den as i128 + b.num as i128 * a.den as i128, a.den as i128 * b.den as i128)
    }
    static let +(a:Self, b:i8):Self { a + rat8(b) }
    static let +(a:i8, b:Self):Self { rat8(a) + b }
    static let -(a:Self):Self { rat8_lowest(-(a.num as i128), a.den as i128) }
    static let -(a:Self, b:Self):Self { a + -b }
    static let -(a:Self, b:i8):Self { a + -rat8(b) }
    static let -(a:i8, b:Self):Self { rat8(a) + -b }
    static let *(a:Self, b:Self):Self {
        rat8_lowest(a.num as i128 * b.num as i128, a.den as i128 * b.den as i128)
    }
    static let *(a:Self, b:i8):Self { a * rat8(b) }
    static let *(a:i8, b:Self):Self { rat8(a) * b }
    // by 0 it is an infinity, and 0 by 0 a NaN: no division by zero
    static let /(a:Self, b:Self):Self {
        rat8_lowest(a.num as i128 * b.den as i128, a.den as i128 * b.num as i128)
    }
    static let /(a:Self, b:i8):Self { a / rat8(b) }
    static let /(a:i8, b:Self):Self { rat8(a) / b }

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
