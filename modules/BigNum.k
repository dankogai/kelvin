// modules/BigNum.k - numbers of any size, and math's functions of them
// (#590): CBR, a complex number of two BigRats; BigFloat, a
// floating-point number of any precision; CBF, a complex number of two
// BigFloats; and math's functions, sqrt, exp, sin and the rest, of a
// BigRat, a CBR, a BigFloat and a CBF, each to a precision.
//
//     #import <BigNum>
//     let x = BigFloat(1) / 3                              // a third, to 128 bits
//     println(x, " ", sqrt(BigFloat(2)), " ", exp(CBF(0, 1)))
//     println(sqrt(1n.over(2n), 64), " ", CBR(1n.over(2n), 1n.over(3n)).conj())
//
// It is built on the prelude's BigInt, on math, and on Rational's BigRat,
// which <Rational> alone has too, with its arithmetic and no function of
// math. Its three parts were three files before #590: the overlay
// math+Rational.k, read where <math> and <Rational> were both imported
// (#551); BigFloat.k, #import <BigFloat> (#576); and the overlay
// math+BigFloat.k (#580). They stand here in that order, each using the
// ones before it.
#import <math>
#import <Rational>

// ========== CBR, and math's functions of a BigRat and of a CBR ==========

// CBR (#551 to #554) is a complex number whose parts are BigRats,
// fractions of any size, also complexBigRat by its alias, as c64 is
// complex64. It was the overlay of math with Rational, math+Rational.k,
// before #590.
//
//     #import <BigNum>
//     let z = CBR(1n.over(2n), 1n.over(3n))
//     println(z * z, " ", z / z.conj(), " ", norm(z))
//
// What stays rational is exact: + - * /, unary -, == and !=, with a
// BigRat, a BigInt or an i64 on either side; conj and norm, each a method
// too; z.i, z rotated a quarter turn, and r.i of a BigRat, CBR(0, r).
// What does not, abs, arg, exp and the rest of math's, of a BigRat
// (#553) and of a CBR (#554), takes a precision, below; c64(z) is the
// nearest c64. A part may be an infinity or a NaN, a BigRat's own
// (rational.md): z / 0 is infinite, a part that is 0 staying 0 (#571),
// and no division by zero.

struct CBR {
    real: BigRat
    imag: BigRat
}

// the same by what it is of, as an alias, as complex64 is c64's (#150)
typealias complexBigRat = CBR

// ---------- making one ----------

let CBR(real:lent BigRat, imag:lent BigRat):CBR { (CBR){real.copy(), imag.copy()} }
let CBR(real:lent BigRat):CBR { (CBR){real.copy(), BigRat(0)} }
let CBR(real:lent BigInt, imag:lent BigInt):CBR { (CBR){BigRat(real), BigRat(imag)} }
let CBR(real:lent BigInt):CBR { (CBR){BigRat(real), BigRat(0)} }
let CBR(real:i64, imag:i64):CBR { (CBR){BigRat(real), BigRat(imag)} }
let CBR(real:i64):CBR { (CBR){BigRat(real), BigRat(0)} }

// ---------- of text (#569) ----------

// a part of a CBR's text at text[at]: a BigRat's ratio, bare, or in
// parentheses of its own, which a sign may come before, as in
// +(-1n/3n); end is -1 where none is
let CBR_part(text:cstr, at:i64, base:i64):BigRat_ratio {
    var i:i64 = at
    var negative = false
    if (text[i] == '+' as u8 || text[i] == '-' as u8) && text[i + 1] == '(' as u8 {
        negative = text[i] == '-' as u8
        i += 1
    }
    if text[i] != '(' as u8 { return BigRat_ratio(text, at, base, false) }
    i = complex_spaces(text, i + 1)
    let r = BigRat_ratio(text, i, base, false)
    if r.end < 0 { return (BigRat_ratio){fx_nan(), -1} }
    i = complex_spaces(text, r.end)
    if text[i] != ')' as u8 { return (BigRat_ratio){fx_nan(), -1} }
    if negative { return (BigRat_ratio){-r.value, i + 1} }
    return (BigRat_ratio){r.value.copy(), i + 1}
}

// the parts of a CBR's text, and where it ends; end is -1 where the
// text is none
struct CBR_parts {
    real: BigRat
    imag: BigRat
    end: i64
}

// a+b.i at text[at]: a part, the sign that joins, a second part and
// .i, with spaces about the sign or none; or the first alone, the real
// part, or with .i the imaginary one
let CBR_body(text:cstr, at:i64, base:i64):CBR_parts {
    let a = CBR_part(text, at, base)
    if a.end < 0 { return (CBR_parts){fx_nan(), fx_nan(), -1} }
    let alone = complex_mark(text, a.end)
    if alone >= 0 { return (CBR_parts){BigRat(0), a.value.copy(), alone} }
    let sign:i64 = complex_spaces(text, a.end)
    if text[sign] != '+' as u8 && text[sign] != '-' as u8 { return (CBR_parts){a.value.copy(), BigRat(0), a.end} }
    let second:i64 = complex_spaces(text, sign + 1)
    if text[second] == '+' as u8 || text[second] == '-' as u8 { return (CBR_parts){fx_nan(), fx_nan(), -1} }
    let b = CBR_part(text, second, base)
    if b.end < 0 { return (CBR_parts){fx_nan(), fx_nan(), -1} }
    let both = complex_mark(text, b.end)
    if both < 0 { return (CBR_parts){fx_nan(), fx_nan(), -1} }
    if text[sign] == '-' as u8 { return (CBR_parts){a.value.copy(), -b.value, both} }
    return (CBR_parts){a.value.copy(), b.value.copy(), both}
}

// the text of a struct of the parts at text[at], after its {, which print
// wrote before #570: real: a part, imag: a part, and the }
let CBR_record(text:cstr, at:i64, base:i64):CBR_parts {
    var i:i64 = complex_spaces(text, at)
    if !complex_word(text, i, "real", false) { return (CBR_parts){fx_nan(), fx_nan(), -1} }
    i = complex_spaces(text, i + 4)
    if text[i] != ':' as u8 { return (CBR_parts){fx_nan(), fx_nan(), -1} }
    let a = CBR_part(text, complex_spaces(text, i + 1), base)
    if a.end < 0 { return (CBR_parts){fx_nan(), fx_nan(), -1} }
    i = complex_spaces(text, a.end)
    if text[i] != ',' as u8 { return (CBR_parts){fx_nan(), fx_nan(), -1} }
    i = complex_spaces(text, i + 1)
    if !complex_word(text, i, "imag", false) { return (CBR_parts){fx_nan(), fx_nan(), -1} }
    i = complex_spaces(text, i + 4)
    if text[i] != ':' as u8 { return (CBR_parts){fx_nan(), fx_nan(), -1} }
    let b = CBR_part(text, complex_spaces(text, i + 1), base)
    if b.end < 0 { return (CBR_parts){fx_nan(), fx_nan(), -1} }
    i = complex_spaces(text, b.end)
    if text[i] != '}' as u8 { return (CBR_parts){fx_nan(), fx_nan(), -1} }
    return (CBR_parts){a.value.copy(), b.value.copy(), i + 1}
}

// a CBR of its text, in a base, all of it: ((1n/2n)+(-1n/3n).i), with
// 16, 8 or 2 its .hex, .oct or .bin, with the outer parentheses or with
// none, which print writes (#570); a part alone, (1n/2n) or (1n/3n).i; or
// the text of a struct of the parts, {real: (1n/2n), imag: (1n/3n)}. A
// part is a BigRat's text, as
// BigRat(text, base) reads it, in parentheses of its own or bare, 1.5
// and 1/2, and a part left out is 0. Text that is no such thing is an
// error, a NaN in both parts
let CBR_read(text:cstr, base:i64):CBR {
    if base < 2 || base > 36 { return (CBR){fx_nan(), fx_nan()} }
    var i:i64 = complex_spaces(text, 0)
    if text[i] == '{' as u8 {
        let named = CBR_record(text, i + 1, base)
        if named.end < 0 || text[complex_spaces(text, named.end)] != 0 { return (CBR){fx_nan(), fx_nan()} }
        return (CBR){named.real.copy(), named.imag.copy()}
    }
    let bare = CBR_body(text, i, base)
    if bare.end >= 0 && text[complex_spaces(text, bare.end)] == 0 { return (CBR){bare.real.copy(), bare.imag.copy()} }
    if text[i] != '(' as u8 { return (CBR){fx_nan(), fx_nan()} }
    let inner = CBR_body(text, complex_spaces(text, i + 1), base)
    if inner.end < 0 { return (CBR){fx_nan(), fx_nan()} }
    i = complex_spaces(text, inner.end)
    if text[i] != ')' as u8 || text[complex_spaces(text, i + 1)] != 0 { return (CBR){fx_nan(), fx_nan()} }
    return (CBR){inner.real.copy(), inner.imag.copy()}
}
let CBR(text:cstr, base:i64):CBR { CBR_read(text, base) }
let CBR(text:cstr):CBR { CBR_read(text, 10) }
let CBR(text:const String^, base:i64):CBR { CBR_read(text^.cstr, base) }
let CBR(text:const String^):CBR { CBR_read(text^.cstr, 10) }

// the nearest c64, each part the f64 of its BigRat
let c64(z:lent CBR):c64 { (c64){z.real.f64, z.imag.f64} }

// ---------- arithmetic ----------

// z / 0 (#571): each part a BigRat's quotient by 0, an infinity of the
// part's sign, but a part that is 0 stays 0 beside one that is none, since
// a rational's 0 is exactly 0: CBR(1) / CBR(0) is ((1n/0n)+(0n/1n).i),
// where the part was 0 / 0, a NaN. 0 / 0 is NaNs still, and a NaN part
// makes no 0 of the other
let CBR_by_zero(z:lent CBR, zero:lent BigRat):CBR {
    let real = z.real.isFinite && z.real.num.isZero
    let imag = z.imag.isFinite && z.imag.num.isZero
    if real && !imag && !z.imag.isNaN { return (CBR){BigRat(0), z.imag / zero} }
    if imag && !real && !z.real.isNaN { return (CBR){z.real / zero, BigRat(0)} }
    return (CBR){z.real / zero, z.imag / zero}
}

// z times a real number r (#573): each part times r, but times an infinity
// a part that is 0 stays 0 beside one that is none, as by 0 (#571), since a
// rational's 0 is exactly 0: CBR(1) * inf is ((1n/0n)+(0n/1n).i), where
// the part was 0 times an infinity, a NaN. 0 times an infinity is NaNs
// in both parts, whichever of the two is the 0, and a NaN part makes no 0
// of the other
let CBR_scaled(z:lent CBR, r:lent BigRat):CBR {
    let real = z.real.isFinite && z.real.num.isZero
    let imag = z.imag.isFinite && z.imag.num.isZero
    if r.isInfinite {
        if real && imag { return (CBR){BigRat(0, 0), BigRat(0, 0)} }
        if real && !z.imag.isNaN { return (CBR){BigRat(0), z.imag * r} }
        if imag && !z.real.isNaN { return (CBR){z.real * r, BigRat(0)} }
    }
    if r.isFinite && r.num.isZero && (z.real.isInfinite || z.imag.isInfinite) {
        return (CBR){BigRat(0, 0), BigRat(0, 0)}
    }
    return (CBR){z.real * r, z.imag * r}
}

extend CBR {
    static let +(a:Self, b:Self):Self { (Self){a.real + b.real, a.imag + b.imag} }
    static let +(a:Self, b:BigRat):Self { (Self){a.real + b, a.imag.copy()} }
    static let +(a:BigRat, b:Self):Self { (Self){a + b.real, b.imag.copy()} }
    static let +(a:Self, b:BigInt):Self { a + BigRat(b) }
    static let +(a:BigInt, b:Self):Self { BigRat(a) + b }
    static let +(a:Self, b:i64):Self { a + BigRat(b) }
    static let +(a:i64, b:Self):Self { BigRat(a) + b }

    static let -(a:Self):Self { (Self){-a.real, -a.imag} }
    static let -(a:Self, b:Self):Self { (Self){a.real - b.real, a.imag - b.imag} }
    static let -(a:Self, b:BigRat):Self { (Self){a.real - b, a.imag.copy()} }
    static let -(a:BigRat, b:Self):Self { (Self){a - b.real, -b.imag} }
    static let -(a:Self, b:BigInt):Self { a - BigRat(b) }
    static let -(a:BigInt, b:Self):Self { BigRat(a) - b }
    static let -(a:Self, b:i64):Self { a - BigRat(b) }
    static let -(a:i64, b:Self):Self { BigRat(a) - b }

    // by a real number, one with an imaginary part of 0, it is the other
    // scaled, CBR_scaled's, and by an imaginary one too, with a quarter
    // turn (#573): the same where all is finite, and no 0 of the one meets
    // an infinity of the other, so CBR(1) * CBR(inf, 0) is
    // ((1n/0n)+(0n/1n).i), not a NaN in a part; either way round
    static let *(a:Self, b:Self):Self {
        if b.imag.isFinite && b.imag.num.isZero { return CBR_scaled(a, b.real) }
        if a.imag.isFinite && a.imag.num.isZero { return CBR_scaled(b, a.real) }
        if b.real.isFinite && b.real.num.isZero {
            let s = CBR_scaled(a, b.imag)
            return (Self){-s.imag, s.real.copy()}
        }
        if a.real.isFinite && a.real.num.isZero {
            let s = CBR_scaled(b, a.imag)
            return (Self){-s.imag, s.real.copy()}
        }
        return (Self){a.real * b.real - a.imag * b.imag, a.real * b.imag + a.imag * b.real}
    }
    static let *(a:Self, b:BigRat):Self { CBR_scaled(a, b) }
    static let *(a:BigRat, b:Self):Self { CBR_scaled(b, a) }
    static let *(a:Self, b:BigInt):Self { a * BigRat(b) }
    static let *(a:BigInt, b:Self):Self { BigRat(a) * b }
    static let *(a:Self, b:i64):Self { a * BigRat(b) }
    static let *(a:i64, b:Self):Self { BigRat(a) * b }

    // a times b's conjugate, over b's norm, a BigRat; by 0 it is infinite,
    // CBR_by_zero's, and by an infinity 0, as c64's is. By a real number, b
    // with an imaginary part of 0, it is part by part, each of a's times
    // the reciprocal of b's, and by an imaginary one too, with a quarter
    // turn (#572): the same where all is finite, and no 0 of b's meets an
    // infinity of a's, so CBR(inf, 0) / CBR(2) is ((1n/0n)+(0n/1n).i), not
    // a NaN in a part. The reciprocal has b's sign, as an infinity
    // divided by b has too (#574)
    static let /(a:Self, b:Self):Self {
        if b.real.isFinite && b.real.num.isZero && b.imag.isFinite && b.imag.num.isZero {
            return CBR_by_zero(a, b.real)
        }
        if b.real.isInfinite || b.imag.isInfinite {
            if !a.real.isFinite || !a.imag.isFinite { return (Self){BigRat(0, 0), BigRat(0, 0)} }
            return (Self){BigRat(0), BigRat(0)}
        }
        if b.imag.isFinite && b.imag.num.isZero {
            let r = BigRat(1) / b.real
            return (Self){a.real * r, a.imag * r}
        }
        if b.real.isFinite && b.real.num.isZero {
            let r = BigRat(1) / b.imag
            return (Self){a.imag * r, -(a.real * r)}
        }
        let d = b.real * b.real + b.imag * b.imag
        return (Self){(a.real * b.real + a.imag * b.imag) / d, (a.imag * b.real - a.real * b.imag) / d}
    }
    static let /(a:Self, b:BigRat):Self {
        if b.isFinite && b.num.isZero { return CBR_by_zero(a, b) }
        return (Self){a.real / b, a.imag / b}
    }
    static let /(a:BigRat, b:Self):Self { CBR(a) / b }
    static let /(a:Self, b:BigInt):Self { a / BigRat(b) }
    static let /(a:BigInt, b:Self):Self { CBR(a) / b }
    static let /(a:Self, b:i64):Self { a / BigRat(b) }
    static let /(a:i64, b:Self):Self { CBR(a) / b }

    // a part that is a NaN equals nothing, as a BigRat's
    static let ==(a:Self, b:Self):bool { a.real == b.real && a.imag == b.imag }
    static let !=(a:Self, b:Self):bool { !(a == b) }
}

// ---------- parts ----------

let conj(z:lent CBR):CBR { (CBR){z.real.copy(), -z.imag} }

// |z|², a BigRat: |z| itself is seldom rational
let norm(z:lent CBR):BigRat { z.real * z.real + z.imag * z.imag }

extend CBR {
    let conj():Self { conj(self) }
    let norm():BigRat { norm(self) }
    let i:Self { (Self){-self.imag, self.real.copy()} }   // z rotated a quarter turn: z times i

    // its text (#570), which print shows whole and .cstr gives:
    // ((1n/2n)+(-1n/3n).i), each part a BigRat's text, in its own
    // parentheses, a + between them, as .hex lays it out
    let string:String {
        var s = $"("
        s += self.real.string
        s += "+"
        s += self.imag.string
        s += ".i)"
        return s
    }

    // (real.hex+imag.hex.i), and the same in base 8 and base 2 (#558):
    // each part is a BigRat's text, in its own parentheses
    let hex:String {
        var s = $"("
        s += self.real.hex
        s += "+"
        s += self.imag.hex
        s += ".i)"
        return s
    }
    let oct:String {
        var s = $"("
        s += self.real.oct
        s += "+"
        s += self.imag.oct
        s += ".i)"
        return s
    }
    let bin:String {
        var s = $"("
        s += self.real.bin
        s += "+"
        s += self.imag.bin
        s += ".i)"
        return s
    }
}

extend BigRat {
    let i:CBR { (CBR){BigRat(0), self.copy()} }           // r rotated a quarter turn: CBR(0, r)
}

// ---------- functions that are not rational, to a precision (#553) ----------
//
// sqrt, exp, log, pow, the trigonometric and hyperbolic functions and
// their inverses, of a BigRat: seldom rational, so each takes a precision,
// a count of bits after the binary point, and gives a BigRat of 2^precision
// parts within one of them of the true value, 2^-precision:
//
//     sqrt(BigRat(2), 64)      // (26087635650665564425n/18446744073709551616n)
//     exp(BigRat(1))           // e, to BigRat.precision, 128 bits
//     BigRat.pi(256)           // pi to 256 bits
//
// With no precision it is BigRat.precision, 128 bits, some 38 decimal
// digits; one below 0 is 0. The precision is absolute: a large result has
// more bits in all, a small one fewer, down to 0. Each is a method too,
// r.exp(), r.exp(64). What a float answers with an infinity or a NaN, a
// BigRat does too: log(0) is (-1n/0n), sqrt(-1) is (0n/0n).
//
// They are reckoned in BigInts, a number x as the integer x * 2^w, of some
// more bits than asked for, which the rounding at the end takes off: sums
// of series after the argument is brought near 0, exp's by ln 2 and
// halvings, log's by a power of 2, the sine's by pi / 2, atan's by its
// half-angle formula.

extend BigRat {
    static let precision:i64 = 128
}

// the bits of |x|: 0 of 0
let fx_bits(x:lent BigInt):i64 { x.isZero ? 0 : x.abs.bits.count as i64 - 1 }

// r as x * 2^w, cut toward 0; r is finite
let fx_of(r:lent BigRat, w:i64):BigInt { (r.num << w) / r.den }

// x * 2^w as a BigRat of 2^p parts, the nearest; w is above p
let fx_round(x:lent BigInt, w:i64, p:i64):BigRat {
    let n = (x + (BigInt(1) << (w - p - 1))) >> (w - p)
    return BigRat_lowest(n, BigInt(1) << p)
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

let fx_nan():BigRat { (BigRat){BigInt(0), BigInt(0)} }
let fx_inf(sign:i64):BigRat { (BigRat){BigInt(sign), BigInt(0)} }

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
let fx_exp(x:lent BigRat, w:i64):BigInt {
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
let fx_exp_over(x:lent BigRat):bool { x > BigRat(4294967296) }

// ln x * 2^w of a finite x above 0: x = m 2^e, m from 3/4 to 3/2, and
// ln m = 2 atanh((m - 1) / (m + 1)), its series
let fx_log(x:lent BigRat, w:i64):BigInt {
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
let fx_sin_cos(x:lent BigRat, w:i64, cosine:bool):BigInt {
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
let fx_atan(x:lent BigRat, w:i64):BigInt {
    if x.num.isNegative { return 0 - fx_atan(-x, w) }
    if x.num > x.den { return (fx_pi(w + 1) >> 2) - fx_atan(BigRat(x.den, x.num), w) }
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
let fx_atan2(y0:lent BigRat, x0:lent BigRat, w:i64):BigInt {
    let far = x0.isInfinite || y0.isInfinite
    let x:BigRat = far ? BigRat(x0.isInfinite ? x0.num.sign : 0) : x0.copy()
    let y:BigRat = far ? BigRat(y0.isInfinite ? y0.num.sign : 0) : y0.copy()
    if x.num.isZero {
        if y.num.isZero { return BigInt(0) }
        return y.num.isNegative ? 0 - (fx_pi(w + 1) >> 2) : fx_pi(w + 1) >> 2
    }
    let a = fx_atan(y / x, w)
    if x.num.isNegative { return y.num.isNegative ? a - fx_pi(w) : a + fx_pi(w) }
    return a
}

extend BigRat {
    // pi to a precision
    static let pi(precision:i64):Self {
        let p:i64 = precision > 0 ? precision : 0
        return fx_round(fx_pi(p + 8), p + 8, p)
    }
    static let pi():Self { BigRat.pi(BigRat.precision) }
}

let sqrt(x:lent BigRat, precision:i64):BigRat {
    if x.isNaN || x.num.isNegative { return fx_nan() }
    if x.isInfinite { return fx_inf(1) }
    let p:i64 = precision > 0 ? precision : 0
    return fx_round(((x.num << (2 * p + 16)) / x.den).isqrt(), p + 8, p)
}

let exp(x:lent BigRat, precision:i64):BigRat {
    if x.isNaN { return fx_nan() }
    if x.isInfinite { return x.num.isNegative ? BigRat(0) : fx_inf(1) }
    if fx_exp_over(x) { return fx_inf(1) }
    let p:i64 = precision > 0 ? precision : 0
    return fx_round(fx_exp(x, p + 8), p + 8, p)
}

let log(x:lent BigRat, precision:i64):BigRat {
    if x.isNaN || x.num.isNegative { return fx_nan() }
    if x.isInfinite { return fx_inf(1) }
    if x.num.isZero { return fx_inf(-1) }
    let p:i64 = precision > 0 ? precision : 0
    return fx_round(fx_log(x, p + 8), p + 8, p)
}

let sin(x:lent BigRat, precision:i64):BigRat {
    if !x.isFinite { return fx_nan() }
    let p:i64 = precision > 0 ? precision : 0
    return fx_round(fx_sin_cos(x, p + 8, false), p + 8, p)
}

let cos(x:lent BigRat, precision:i64):BigRat {
    if !x.isFinite { return fx_nan() }
    let p:i64 = precision > 0 ? precision : 0
    return fx_round(fx_sin_cos(x, p + 8, true), p + 8, p)
}

// sin x / cos x, with the bits a cosine near 0 takes: it is reckoned
// anew with twice as many more as the cosine has zeros after its point
let tan(x:lent BigRat, precision:i64):BigRat {
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

let atan(x:lent BigRat, precision:i64):BigRat {
    if x.isNaN { return fx_nan() }
    let p:i64 = precision > 0 ? precision : 0
    if x.isInfinite {
        let h = fx_pi(p + 9) >> 2                        // pi / 2
        return fx_round(fx_signed(h, x.num.isNegative), p + 8, p)
    }
    return fx_round(fx_atan(x, p + 8), p + 8, p)
}

let atan2(y:lent BigRat, x:lent BigRat, precision:i64):BigRat {
    if x.isNaN || y.isNaN { return fx_nan() }
    let p:i64 = precision > 0 ? precision : 0
    return fx_round(fx_atan2(y, x, p + 8), p + 8, p)
}

// asin x * 2^w, x from -1 to 1: the angle of (sqrt(1 - x^2), x)
let fx_asin(x:lent BigRat, w:i64):BigInt {
    let g:i64 = w + 16
    let rest = BigRat(1) - x * x
    let s = BigRat(((rest.num << (2 * g)) / rest.den).isqrt(), BigInt(1) << g)
    return fx_atan2(x, s, w)
}

let asin(x:lent BigRat, precision:i64):BigRat {
    if !x.isFinite || x.num.abs > x.den { return fx_nan() }
    let p:i64 = precision > 0 ? precision : 0
    return fx_round(fx_asin(x, p + 8), p + 8, p)
}

let acos(x:lent BigRat, precision:i64):BigRat {
    if !x.isFinite || x.num.abs > x.den { return fx_nan() }
    let p:i64 = precision > 0 ? precision : 0
    return fx_round((fx_pi(p + 9) >> 2) - fx_asin(x, p + 8), p + 8, p)   // pi / 2, less it
}

// (e^x - e^-x) / 2 and (e^x + e^-x) / 2, by e^|x|
let sinh(x:lent BigRat, precision:i64):BigRat {
    if x.isNaN { return fx_nan() }
    if x.isInfinite || fx_exp_over(x) || fx_exp_over(-x) { return fx_inf(x.num.sign) }
    let p:i64 = precision > 0 ? precision : 0
    let g:i64 = p + 8
    let e = fx_exp(x.num.isNegative ? -x : x.copy(), g)
    let h = (e - (BigInt(1) << (2 * g)) / e) >> 1
    return fx_round(fx_signed(h, x.num.isNegative), g, p)
}

let cosh(x:lent BigRat, precision:i64):BigRat {
    if x.isNaN { return fx_nan() }
    if x.isInfinite || fx_exp_over(x) || fx_exp_over(-x) { return fx_inf(1) }
    let p:i64 = precision > 0 ? precision : 0
    let g:i64 = p + 8
    let e = fx_exp(x.num.isNegative ? -x : x.copy(), g)
    return fx_round((e + (BigInt(1) << (2 * g)) / e) >> 1, g, p)
}

// (1 - t) / (1 + t) of t = e^(-2|x|), which is 1 at most
let tanh(x:lent BigRat, precision:i64):BigRat {
    if x.isNaN { return fx_nan() }
    if x.isInfinite { return BigRat(x.num.sign) }
    let p:i64 = precision > 0 ? precision : 0
    let g:i64 = p + 8
    let one = BigInt(1) << g
    let t = fx_exp((x.num.isNegative ? x.copy() : -x) * 2, g)
    let h = ((one - t) << g) / (one + t)
    return fx_round(fx_signed(h, x.num.isNegative), g, p)
}

// ln(|x| + sqrt(x^2 + 1)), with x's sign
let asinh(x:lent BigRat, precision:i64):BigRat {
    if x.isNaN { return fx_nan() }
    if x.isInfinite { return fx_inf(x.num.sign) }
    let p:i64 = precision > 0 ? precision : 0
    let g:i64 = p + 16
    let a:BigRat = x.num.isNegative ? -x : x.copy()
    let sq = a * a + 1
    let u = BigRat(fx_of(a, g) + ((sq.num << (2 * g)) / sq.den).isqrt(), BigInt(1) << g)
    let h = fx_log(u, p + 8)
    return fx_round(fx_signed(h, x.num.isNegative), p + 8, p)
}

// ln(x + sqrt(x^2 - 1)), of x of 1 or more
let acosh(x:lent BigRat, precision:i64):BigRat {
    if x.isNaN || x < BigRat(1) { return fx_nan() }
    if x.isInfinite { return fx_inf(1) }
    let p:i64 = precision > 0 ? precision : 0
    let g:i64 = p + 16
    let sq = x * x - 1
    let u = BigRat(fx_of(x, g) + ((sq.num << (2 * g)) / sq.den).isqrt(), BigInt(1) << g)
    return fx_round(fx_log(u, p + 8), p + 8, p)
}

// ln((1 + x) / (1 - x)) / 2, of x between -1 and 1; of 1 and -1 infinite
let atanh(x:lent BigRat, precision:i64):BigRat {
    if !x.isFinite || x.num.abs > x.den { return fx_nan() }
    if x.num.abs == x.den { return fx_inf(x.num.sign) }
    let p:i64 = precision > 0 ? precision : 0
    return fx_round(fx_log((BigRat(1) + x) / (BigRat(1) - x), p + 9) >> 2, p + 8, p)
}

// x to the y: of a whole y the power itself, rounded; else e^(y ln x), of
// x above 0, with the bits a large power takes; 0 to a y above 0 is 0, to
// 0 it is 1, and below 0 infinite; a negative x to a y not whole is a NaN
let pow(x:lent BigRat, y:lent BigRat, precision:i64):BigRat {
    if x.isNaN || y.isNaN { return fx_nan() }
    let p:i64 = precision > 0 ? precision : 0
    if y.num.isZero { return BigRat(1) }
    if x.num.isZero && x.isFinite { return y.num.isNegative ? fx_inf(1) : BigRat(0) }
    if y.isFinite && x.isFinite && y.den == 1 {
        if let n = y.num.abs.exactI64 {
            if n <= 65536 {
                let up:BigRat = (BigRat){x.num ** n, x.den ** n}
                let v:BigRat = y.num.isNegative ? BigRat(1) / up : up.copy()
                return fx_round(fx_of(v, p + 2), p + 2, p)
            }
        }
    }
    if x.num.isNegative { return fx_nan() }
    if x.isInfinite { return y.num.isNegative ? BigRat(0) : fx_inf(1) }
    if y.isInfinite {
        let grows = (x > BigRat(1)) == !y.num.isNegative
        return x == BigRat(1) ? BigRat(1) : grows ? fx_inf(1) : BigRat(0)
    }
    let rough = y * BigRat(fx_log(x, 64), BigInt(1) << 64)   // y ln x, about: how large the power is
    if fx_exp_over(rough) { return fx_inf(1) }
    let size:i64 = (rough.num / rough.den).exactI64 ?? 0
    let wl:i64 = p + (size > 0 ? 2 * size : 0) + fx_bits(y.num) + 64
    return exp(y * BigRat(fx_log(x, wl), BigInt(1) << wl), p)
}

// each with BigRat.precision where none is written
let sqrt(x:lent BigRat):BigRat { sqrt(x, BigRat.precision) }
let exp(x:lent BigRat):BigRat { exp(x, BigRat.precision) }
let log(x:lent BigRat):BigRat { log(x, BigRat.precision) }
let sin(x:lent BigRat):BigRat { sin(x, BigRat.precision) }
let cos(x:lent BigRat):BigRat { cos(x, BigRat.precision) }
let tan(x:lent BigRat):BigRat { tan(x, BigRat.precision) }
let asin(x:lent BigRat):BigRat { asin(x, BigRat.precision) }
let acos(x:lent BigRat):BigRat { acos(x, BigRat.precision) }
let atan(x:lent BigRat):BigRat { atan(x, BigRat.precision) }
let atan2(y:lent BigRat, x:lent BigRat):BigRat { atan2(y, x, BigRat.precision) }
let sinh(x:lent BigRat):BigRat { sinh(x, BigRat.precision) }
let cosh(x:lent BigRat):BigRat { cosh(x, BigRat.precision) }
let tanh(x:lent BigRat):BigRat { tanh(x, BigRat.precision) }
let asinh(x:lent BigRat):BigRat { asinh(x, BigRat.precision) }
let acosh(x:lent BigRat):BigRat { acosh(x, BigRat.precision) }
let atanh(x:lent BigRat):BigRat { atanh(x, BigRat.precision) }
let pow(x:lent BigRat, y:lent BigRat):BigRat { pow(x, y, BigRat.precision) }

extend BigRat {
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

// ---------- a CBR's functions that are not rational, to a precision (#554) ----------
//
// abs and arg, BigRats, and sqrt, exp, log, pow, the trigonometric and
// hyperbolic functions and their inverses, CBRs: each part within
// 2^-precision of the true value's, as a BigRat's functions are, with
// BigRat.precision where none is written, and each a method too. The
// inverses take their principal values, with C99's branch cuts; a
// rational has no negative zero, so a point on a cut is on the side a
// float's +0 is.

// both parts NaNs
let CBR_nan():CBR { (CBR){fx_nan(), fx_nan()} }

// x * 2^w and y * 2^w as a CBR of 2^p parts
let CBR_round(x:lent BigInt, y:lent BigInt, w:i64, p:i64):CBR { (CBR){fx_round(x, w, p), fx_round(y, w, p)} }

// whether a part is no finite number
let CBR_wild(z:lent CBR):bool { !z.real.isFinite || !z.imag.isFinite }

// the bits of |z| above its point, 0 at least: of the larger part
let CBR_bits(z:lent CBR):i64 {
    let a:i64 = fx_bits(z.real.num) - fx_bits(z.real.den) + 1
    let b:i64 = fx_bits(z.imag.num) - fx_bits(z.imag.den) + 1
    let m:i64 = a > b ? a : b
    return m > 0 ? m + 1 : 1
}

// |z|, the root of its norm
let abs(z:lent CBR, precision:i64):BigRat { sqrt(norm(z), precision) }

// the angle from the positive real axis, from -pi to pi
let arg(z:lent CBR, precision:i64):BigRat { atan2(z.imag, z.real, precision) }

// the principal square root, whose real part is never negative: z times
// a power of 4 that brings |z| near 1, then sqrt((|z| + |x|) / 2) and the
// other part from z itself, and the power of 2 taken back
let sqrt(z:lent CBR, precision:i64):CBR {
    if z.real.isNaN || z.imag.isNaN { return CBR_nan() }
    if z.imag.isInfinite { return (CBR){fx_inf(1), z.imag.copy()} }
    if z.real.isInfinite {
        if z.real.num.isNegative { return (CBR){BigRat(0), fx_inf(z.imag.num.isNegative ? -1 : 1)} }
        return (CBR){fx_inf(1), BigRat(0)}
    }
    let p:i64 = precision > 0 ? precision : 0
    let n = norm(z)
    if n.num.isZero { return CBR(0) }
    let e:i64 = fx_bits(n.num) - fx_bits(n.den)
    let k:i64 = 0 - (e >> 2)                              // z * 4^k is near 1; its root times 2^-k is z's
    let g:i64 = (k > 0 ? (p > k ? p - k : 0) : p - k) + 24
    let up:i64 = k > 0 ? 2 * k : 0
    let down:i64 = k < 0 ? 0 - 2 * k : 0
    let x = (z.real.num.abs << (g + up)) / (z.real.den << down)   // |x| and |y| of z * 4^k
    let y = (z.imag.num.abs << (g + up)) / (z.imag.den << down)
    let m = (x * x + y * y).isqrt()
    let s = (((m + x) >> 1) << g).isqrt()                 // sqrt((|z| + |x|) / 2), the larger part
    let t = (y << (g - 1)) / s                            // |y| / (2 s), the lesser
    let re = z.real.num.isNegative ? t.copy() : s.copy()
    let im = z.real.num.isNegative ? s.copy() : t.copy()
    let w:i64 = k > 0 ? g + k : g
    let shift:i64 = k < 0 ? 0 - k : 0
    return CBR_round(re << shift, fx_signed(im << shift, z.imag.num.isNegative), w, p)
}

// how many bits e^x has above its point, at most: 0 of an x of 0 or less
let fx_exp_size(x:lent BigRat):i64 {
    if x.num.sign <= 0 { return 0 }
    return (((x.num * 3) / (x.den * 2)).exactI64 ?? 0) + 2
}

// e^x (cos y + i sin y): the sine and the cosine to as many more bits as
// e^x is large
let exp(z:lent CBR, precision:i64):CBR {
    if z.real.isNaN || !z.imag.isFinite { return CBR_nan() }
    if z.real.isInfinite && z.real.num.isNegative { return CBR(0) }
    let p:i64 = precision > 0 ? precision : 0
    if z.real.isInfinite || fx_exp_over(z.real) {         // past reckoning: an infinity by the sign of each part
        let c = fx_sin_cos(z.imag, 64, true)
        let s = fx_sin_cos(z.imag, 64, false)
        return (CBR){c.isZero ? BigRat(0) : fx_inf(c.sign), s.isZero ? BigRat(0) : fx_inf(s.sign)}
    }
    let w:i64 = p + 16
    let g:i64 = w + fx_exp_size(z.real)
    let e = fx_exp(z.real, w)
    return CBR_round((e * fx_sin_cos(z.imag, g, true)) >> g, (e * fx_sin_cos(z.imag, g, false)) >> g, w, p)
}

// the principal value, ln|z| + i arg z: half the log of its norm
let log(z:lent CBR, precision:i64):CBR {
    if z.real.isNaN || z.imag.isNaN { return CBR_nan() }
    let p:i64 = precision > 0 ? precision : 0
    if CBR_wild(z) { return (CBR){fx_inf(1), atan2(z.imag, z.real, p)} }
    let n = norm(z)
    if n.num.isZero { return (CBR){fx_inf(-1), BigRat(0)} }
    return CBR_round(fx_log(n, p + 9) >> 2, fx_atan2(z.imag, z.real, p + 8), p + 8, p)
}

// sinh a cos b, cosh a sin b, cosh a cos b and sinh a sin b, each * 2^w:
// what the sines and cosines of a CBR are made of; the trigonometric ones
// to as many more bits as e^|a| is large. a is finite and e^|a| reckoned
struct CBR_products {
    shc: BigInt
    chs: BigInt
    chc: BigInt
    shs: BigInt
}

let CBR_products(a:lent BigRat, b:lent BigRat, w:i64):CBR_products {
    let mag:BigRat = a.num.isNegative ? -a : a.copy()
    let g:i64 = w + fx_exp_size(mag)
    let e = fx_exp(mag, w)
    let r = (BigInt(1) << (2 * w)) / e
    let ch = (e + r) >> 1
    let sh = fx_signed((e - r) >> 1, a.num.isNegative)
    let c = fx_sin_cos(b, g, true)
    let s = fx_sin_cos(b, g, false)
    return (CBR_products){(sh * c) >> g, (ch * s) >> g, (ch * c) >> g, (sh * s) >> g}
}

// whether e^|a| is past reckoning, or a or b no finite number: the sines
// and cosines of such a CBR are NaNs here
let CBR_far(a:lent BigRat, b:lent BigRat):bool {
    return !a.isFinite || !b.isFinite || fx_exp_over(a) || fx_exp_over(-a)
}

// sinh(a + ib) = sinh a cos b + i cosh a sin b
let sinh(z:lent CBR, precision:i64):CBR {
    if CBR_far(z.real, z.imag) { return CBR_nan() }
    let p:i64 = precision > 0 ? precision : 0
    let q = CBR_products(z.real, z.imag, p + 16)
    return CBR_round(q.shc, q.chs, p + 16, p)
}

// cosh(a + ib) = cosh a cos b + i sinh a sin b
let cosh(z:lent CBR, precision:i64):CBR {
    if CBR_far(z.real, z.imag) { return CBR_nan() }
    let p:i64 = precision > 0 ? precision : 0
    let q = CBR_products(z.real, z.imag, p + 16)
    return CBR_round(q.chc, q.shs, p + 16, p)
}

// sin(x + iy) = sin x cosh y + i cos x sinh y
let sin(z:lent CBR, precision:i64):CBR {
    if CBR_far(z.imag, z.real) { return CBR_nan() }
    let p:i64 = precision > 0 ? precision : 0
    let q = CBR_products(z.imag, z.real, p + 16)
    return CBR_round(q.chs, q.shc, p + 16, p)
}

// cos(x + iy) = cos x cosh y - i sin x sinh y
let cos(z:lent CBR, precision:i64):CBR {
    if CBR_far(z.imag, z.real) { return CBR_nan() }
    let p:i64 = precision > 0 ? precision : 0
    let q = CBR_products(z.imag, z.real, p + 16)
    return CBR_round(q.chc, 0 - q.shs, p + 16, p)
}

// tanh(a + ib), by t = e^(-2|a|), 1 at most, so that nothing is large:
// (1 - t^2) / d with a's sign, and 2 t sin 2b / d, d = 1 + t^2 + 2 t cos 2b;
// near a pole d is near 0, and it is reckoned anew with twice as many more
// bits as d has zeros after its point
let tanh(z:lent CBR, precision:i64):CBR {
    if z.real.isNaN || !z.imag.isFinite { return CBR_nan() }
    if z.real.isInfinite { return CBR(z.real.num.sign) }
    let p:i64 = precision > 0 ? precision : 0
    var g:i64 = p + 40
    while true {
        let one = BigInt(1) << g
        let t = fx_exp((z.real.num.isNegative ? z.real.copy() : -z.real) * 2, g)
        let t2 = (t * t) >> g
        let d = one + t2 + ((t * fx_sin_cos(z.imag * 2, g, true)) >> (g - 1))
        let zeros:i64 = g - fx_bits(d)
        if g >= p + 2 * zeros + 16 {
            let re = ((one - t2) << g) / d
            let im = (t * fx_sin_cos(z.imag * 2, g, false)) / (d >> 1)
            return CBR_round(fx_signed(re, z.real.num.isNegative), im, g, p)
        }
        g = p + 2 * zeros + 48
    }
    return CBR_nan()
}

// tan z = -i tanh(iz)
let tan(z:lent CBR, precision:i64):CBR {
    let w = tanh((CBR){-z.imag, z.real.copy()}, precision)
    return (CBR){w.imag.copy(), -w.real}
}

// z to a whole power, exact: by squaring
let CBR_power(z:lent CBR, n:i64):CBR {
    var r = CBR(1)
    var b:CBR = (CBR){z.real.copy(), z.imag.copy()}
    var k:i64 = n
    while k > 0 {
        if k % 2 == 1 { r = r * b }
        k = k / 2
        if k > 0 { b = b * b }
    }
    return r
}

// a CBR to 2^p parts, the nearest; its parts are finite
let CBR_to(z:lent CBR, p:i64):CBR { CBR_round(fx_of(z.real, p + 2), fx_of(z.imag, p + 2), p + 2, p) }

// z to the w: of a whole real w the power itself, rounded; else
// e^(w log z), the log to as many more bits as the power is large; 0 to
// a w whose real part is above 0 is 0, to 0 it is 1, and to a negative
// real w infinite, as c64's
let pow(z:lent CBR, w:lent CBR, precision:i64):CBR {
    if CBR_wild(z) || CBR_wild(w) { return CBR_nan() }
    let p:i64 = precision > 0 ? precision : 0
    if w.real.num.isZero && w.imag.num.isZero { return CBR(1) }
    if z.real.num.isZero && z.imag.num.isZero {
        if w.real.num.sign > 0 { return CBR(0) }
        if w.imag.num.isZero { return (CBR){fx_inf(1), BigRat(0)} }
        return CBR_nan()
    }
    if w.imag.num.isZero && w.real.den == 1 {
        if let n = w.real.num.abs.exactI64 {
            if n <= 65536 {
                let up = CBR_power(z, n)
                if w.real.num.isNegative { return CBR_to(1 / up, p) }
                return CBR_to(up, p)
            }
        }
    }
    let rough = w * log(z, 64)                            // w log z, about: how large the power is
    if fx_exp_over(rough.real) { return CBR_nan() }
    let size:i64 = fx_exp_size(rough.real)
    return exp(w * log(z, p + size + CBR_bits(w) + 64), p)
}
let pow(z:lent CBR, x:lent BigRat, precision:i64):CBR { pow(z, CBR(x), precision) }
let pow(x:lent BigRat, w:lent CBR, precision:i64):CBR { pow(CBR(x), w, precision) }

// asinh z = log(z + sqrt(z^2 + 1)), reckoned so of a z right of the
// imaginary axis, or on it above 0, where the sum cancels nothing, the
// root to twice the bits of |z| more, as the sum may be as small as
// 1 / (2|z|). Left of the axis it is -asinh(-z), as it is odd; on the
// axis below 0 the conjugate of its conjugate's, the side of the cut a
// real part of +0 is on. left says the real part, 0, is a float's -0,
// as iz's is of a real z: then it is -asinh(-z) too
let CBR_asinh(z:lent CBR, p:i64, left:bool):CBR {
    if z.real.num.isNegative || (z.real.num.isZero && left) { return -CBR_asinh(-z, p, false) }
    if z.real.num.isZero && z.imag.num.isNegative { return conj(CBR_asinh(conj(z), p, false)) }
    return log(z + sqrt(z * z + 1, p + 2 * CBR_bits(z) + 32), p)
}

let asinh(z:lent CBR, precision:i64):CBR {
    if CBR_wild(z) { return CBR_nan() }
    return CBR_asinh(z, precision > 0 ? precision : 0, false)
}

// asin z = -i asinh(iz); of a real z, iz's real part is -0
let asin(z:lent CBR, precision:i64):CBR {
    if CBR_wild(z) { return CBR_nan() }
    let w = CBR_asinh((CBR){-z.imag, z.real.copy()}, precision > 0 ? precision : 0, z.imag.num.isZero)
    return (CBR){w.imag.copy(), -w.real}
}

// acos z = pi / 2 - asin z
let acos(z:lent CBR, precision:i64):CBR {
    if CBR_wild(z) { return CBR_nan() }
    let p:i64 = precision > 0 ? precision : 0
    let w = asin(z, p + 8)
    return CBR_round((fx_pi(p + 9) >> 2) - fx_of(w.real, p + 8), 0 - fx_of(w.imag, p + 8), p + 8, p)
}

// acosh z = log(z + sqrt(z + 1) sqrt(z - 1)), C99's form of it, whose sum
// is never below 1
let acosh(z:lent CBR, precision:i64):CBR {
    if CBR_wild(z) { return CBR_nan() }
    let p:i64 = precision > 0 ? precision : 0
    let g:i64 = p + CBR_bits(z) + 32
    return log(z + sqrt(z + 1, g) * sqrt(z - 1, g), p)
}

// atanh z = (log(1 + z) - log(1 - z)) / 2; of 1 and -1 infinite; right of
// 1 on the real axis 1 - z is on log's cut, on the side C99 has it
let atanh(z:lent CBR, precision:i64):CBR {
    if CBR_wild(z) { return CBR_nan() }
    let p:i64 = precision > 0 ? precision : 0
    if z.imag.num.isZero && z.real.num.abs == z.real.den { return (CBR){fx_inf(z.real.num.sign), BigRat(0)} }
    let a = log(1 + z, p + 8)
    let b = log(1 - z, p + 8)
    let flip = z.imag.num.isZero && z.real > BigRat(1)
    let im = fx_of(a.imag, p + 8) - fx_signed(fx_of(b.imag, p + 8), flip)
    return CBR_round((fx_of(a.real, p + 8) - fx_of(b.real, p + 8)) >> 1, im >> 1, p + 8, p)
}

// atan z = -i atanh(iz)
let atan(z:lent CBR, precision:i64):CBR {
    let w = atanh((CBR){-z.imag, z.real.copy()}, precision)
    return (CBR){w.imag.copy(), -w.real}
}

// each with BigRat.precision where none is written
let abs(z:lent CBR):BigRat { abs(z, BigRat.precision) }
let arg(z:lent CBR):BigRat { arg(z, BigRat.precision) }
let sqrt(z:lent CBR):CBR { sqrt(z, BigRat.precision) }
let exp(z:lent CBR):CBR { exp(z, BigRat.precision) }
let log(z:lent CBR):CBR { log(z, BigRat.precision) }
let sin(z:lent CBR):CBR { sin(z, BigRat.precision) }
let cos(z:lent CBR):CBR { cos(z, BigRat.precision) }
let tan(z:lent CBR):CBR { tan(z, BigRat.precision) }
let sinh(z:lent CBR):CBR { sinh(z, BigRat.precision) }
let cosh(z:lent CBR):CBR { cosh(z, BigRat.precision) }
let tanh(z:lent CBR):CBR { tanh(z, BigRat.precision) }
let asin(z:lent CBR):CBR { asin(z, BigRat.precision) }
let acos(z:lent CBR):CBR { acos(z, BigRat.precision) }
let atan(z:lent CBR):CBR { atan(z, BigRat.precision) }
let asinh(z:lent CBR):CBR { asinh(z, BigRat.precision) }
let acosh(z:lent CBR):CBR { acosh(z, BigRat.precision) }
let atanh(z:lent CBR):CBR { atanh(z, BigRat.precision) }
let pow(z:lent CBR, w:lent CBR):CBR { pow(z, w, BigRat.precision) }
let pow(z:lent CBR, x:lent BigRat):CBR { pow(z, x, BigRat.precision) }
let pow(x:lent BigRat, w:lent CBR):CBR { pow(x, w, BigRat.precision) }

extend CBR {
    // each function as a method, z.exp(), z.exp(64)
    let abs():BigRat { abs(self) }
    let abs(precision:i64):BigRat { abs(self, precision) }
    let arg():BigRat { arg(self) }
    let arg(precision:i64):BigRat { arg(self, precision) }
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

// ========== BigFloat ==========

// BigFloat is a floating-point number of any precision (#576): a
// mantissa, a BigInt, times a power of 2. It was BigFloat.k, #import
// <BigFloat>, before #590.
//
//     #import <BigNum>
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
// sign * significand * 2^exponent (#598), as an f64 is made of the three,
// f64(sign, exponent, significand), and as a BigFloat is its mantissa
// times 2^exponent: rounded to BigFloat.precision bits; a NaN where the
// sign is neither -1 nor 1
let BigFloat(sign:i64, exponent:i64, significand:lent BigInt):BigFloat {
    if sign != 1 && sign != -1 { return BigFloat_nan() }
    let m:BigInt = sign < 0 ? -significand : significand.copy()
    return BigFloat_make(m, exponent as i128, BigFloat_bits(), 0)
}
let BigFloat(sign:i64, exponent:i64, significand:i64):BigFloat { BigFloat(sign, exponent, BigInt(significand)) }

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
    // the three every number of the family has (#596), each computed, a
    // new one at each read (#595), as a BigFloat owns its mantissa: 0, the
    // positive infinity, and a NaN
    static let zero:Self { BigFloat_zero() }
    static let infinity:Self { BigFloat_inf(1) }
    static let nan:Self { BigFloat_nan() }

    // -1 or 1, an i64, as an f64's (#597): -1 where it is negative, the
    // negative infinity too, and 1 of all else; its one 0 and its one NaN
    // have no sign
    let sign:i64 { self.mantissa.isNegative ? -1 : 1 }

    // its mantissa without its sign (#598), a BigInt, odd or 0, so that x
    // is BigFloat(x.sign, x.exponent, x.significand); 1 of an infinity and
    // 0 of a NaN, as each is kept
    let significand:BigInt { self.mantissa.abs }

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
    // the first as hex digits, and the power of 2 of the first, with its
    // sign, but of 0, +0x1p0 (#603)
    let hex:String {
        if self.special == 2 { return $"nan" }
        let sign:cstr := self.mantissa.isNegative ? "-" : "+"
        if self.special == 1 { return $`${sign}inf` }
        if self.mantissa.isZero { return $`${sign}0x0p0` }
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
        if p != 0 { s += p < 0 ? '-' : '+' }           // an exponent of 0 has no sign, p0 (#603)
        let size:i128 = p < 0 ? 0 - p : p
        let tail = $`${size}`
        s += &tail
        return s
    }
}

// ========== math's functions of a BigFloat, and CBF ==========

// math's functions take a BigFloat (#580); this was the overlay of math
// with BigFloat, math+BigFloat.k, before #590:
//
//     #import <BigNum>
//     println(sqrt(BigFloat(2)), " ", exp(BigFloat(1)), " ", BigFloat.pi())
//
// sqrt, exp, log, pow, sin, cos, tan, asin, acos, atan, atan2, sinh, cosh,
// tanh, asinh, acosh and atanh, each a method too, x.exp(), and
// BigFloat.pi(). A result has BigFloat.precision significant bits, as
// every BigFloat's, or the precision written after the argument,
// exp(x, 256): the nearest to the true value, or where that is all but
// midway between two, one of them. sqrt's is always the nearest.
//
// They are a BigRat's, above, which are within 2^-w of the true
// value for a w of bits after the point: w is taken so that the bits
// asked for are good, and 8 more, whatever the size of the result. An
// infinity and a NaN come where a BigRat's function gives one, which is
// where a float's does: log(0) is -inf, sqrt(-1) a NaN.
//
// And CBF, a complex number of two BigFloats, also complexBigFloat by
// its alias (#581), below: its + - * /, each part the exact one's rounded
// once, conj, norm, z.i and x.i, z.round, and its text, a c64's; and
// math's functions of a CBF (#582), last.

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

// the square root of m * 2^x, m above 0, the nearest: m shifted so
// that the exponent is even and its whole root has bits + 2 bits, and
// one bit more below them where the root is not whole, which the
// rounding reads. x is of any size, as a norm's is, which is of the
// square of a part (#587)
let BigFloat_sqrt_of(m:lent BigInt, x:i128, bits:i64):BigFloat {
    var s:i64 = 2 * bits + 4 - BigFloat_length(m)
    if s < 0 { s = 0 }
    var e:i128 = x - s as i128
    if e % 2 != 0 {
        s += 1
        e -= 1
    }
    let big = m << s
    var r = big.isqrt()
    var half:i128 = e / 2
    if r * r != big {
        r = (r << 1) + 1
        half -= 1
    }
    return BigFloat_make(r, half, bits, 0)
}

// the square root, the nearest
let BigFloat_sqrt(x:lent BigFloat, bits:i64):BigFloat {
    if x.special == 2 || x.mantissa.isNegative { return BigFloat_nan() }
    if x.special == 1 { return BigFloat_inf(1) }
    if x.mantissa.isZero { return BigFloat_zero() }
    return BigFloat_sqrt_of(x.mantissa, x.exponent as i128, bits)
}

// a whole number below 2^95 in size, as an i128
let BigFloat_i128(k:lent BigInt):i128 {
    let high = k >> 32
    let low = k - (high << 32)
    return high.i64 as i128 * 4294967296 + low.i64 as i128
}

// e^x of a finite x, in two parts: a number near 1, to bits bits, and
// the k it is to be taken times 2 to, written to at. x is k times ln 2
// and a rest of no more than half of ln 2, so e^x is e^rest times 2^k,
// and no bits are spent on its size. The k is an i64's and more: e^x has
// an exponent an i64 holds up to an x of 2^63 times ln 2, 6.39e18 (#588),
// and past it too its product with a number below 1 may have one (#589).
// Of an x of 2^64 and more in size e^x is past any exponent, whatever
// number it is taken times: the k is then 2^100, or less it
let BigFloat_exp_parts(x:lent BigFloat, bits:i64, at:i128^):BigFloat {
    at^ = 0
    if x.mantissa.isZero { return BigFloat(1) }
    let top = BigFloat_top(x)
    if top > 64 {
        at^ = (1 as i128) << 100
        if x.mantissa.isNegative { at^ = 0 - ((1 as i128) << 100) }
        return BigFloat(1)
    }
    if top < 0 - bits as i128 - 2 { return BigFloat(1) }    // 1 + x rounds to 1
    let w:i64 = bits + 32
    let ln2 = log(BigRat(2), w + 70)
    let rx = BigRat(x)
    let q = rx / ln2
    let k = fx_floor_div(q.num * 2 + q.den, q.den * 2)      // the nearest whole number to x / ln 2
    let rest = rx - BigRat(k) * ln2
    at^ = BigFloat_i128(k)
    return BigFloat(exp(rest, w), bits)
}

// e^x times 2^shift, of a finite x that is not 0: it is the result
// that is tried against the exponents there are, not x against 2^62
// (#588), and one past any exponent is an infinity, or 0
let BigFloat_exp_at(x:lent BigFloat, bits:i64, shift:i128):BigFloat {
    var k:i128 = 0
    let m = BigFloat_exp_parts(x, bits, &k)
    return BigFloat_make(m.mantissa, m.exponent as i128 + k + shift, bits, 0)
}

// e^x
let BigFloat_exp(x:lent BigFloat, bits:i64):BigFloat {
    if x.special != 0 { return BigFloat_by(1, x, x, bits, true) }
    if x.mantissa.isZero { return BigFloat(1, bits) }
    return BigFloat_exp_at(x, bits, 0)
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
        let half = BigFloat_exp_at(size, p, 0 - 1).round(bits)     // e^|x| / 2, which may be had where e^|x| is not (#588)
        if negative && f == 10 { return -half }
        return half
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
// (0.1-0.2.i), z.dec's, (+0.1-0.2.i), and z.hex's, (+0x1.8p0-0x1p+1.i), as
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
    // and .hex is of the parts' .hex, (+0x1.8p0-0x1p+1.i), exact
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
// above, with as many bits after the point as make each
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

// each part of a finite c times 2^s: past an exponent an infinity, or 0
let CBF_shifted(c:lent CBF, s:i128, bits:i64):CBF {
    return (CBF){BigFloat_make(c.real.mantissa, c.real.exponent as i128 + s, bits, 0), BigFloat_make(c.imag.mantissa, c.imag.exponent as i128 + s, bits, 0)}
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
// to twice the bits and has a bit below for the rest. The norm's
// exponent is twice a part's and may be past an i64's, which no BigFloat
// holds: the root is of the term itself (#587)
let CBF_abs(z:lent CBF, bits:i64):BigFloat {
    let none = CBF_none()
    let n = CBF_total(CBF_times(z.real, z.real, false), CBF_times(z.imag, z.imag, false), none, none, 2 * bits + 8)
    if n.m.isZero { return BigFloat_zero() }
    return BigFloat_sqrt_of(n.m, n.e, bits)
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
// sqrt((|z| + |x|) / 2), the larger part, and |y| over twice it. z is
// finite, its imaginary part is not 0, and it is near 1 in size
let CBF_sqrt_of(z:lent CBF, bits:i64):CBF {
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

// of a real number its root, on the real axis or the imaginary one;
// else of z over 4^k, whose greater part is near 1, times 2^k: so |z|
// and the sum it is in are had where a part is 2^(2^62) and more in
// size, or as far below 1, and their square past any exponent (#587).
// Parts further apart than 2^(2^40) are no parts of one BigFloat's
// arithmetic, and the root is of the greater alone: sqrt|x| and |y| over
// twice it, or sqrt(|y| / 2) in both
let CBF_sqrt(z:lent CBF, bits:i64):CBF {
    if CBF_wild(z) { return CBF_wild_by(8, z, bits) }
    if CBF_zero(z.imag) {
        if z.real.mantissa.isNegative { return (CBF){BigFloat_zero(), sqrt(-z.real, bits)} }
        return (CBF){sqrt(z.real, bits), BigFloat_zero()}
    }
    let minus = z.imag.mantissa.isNegative
    var top:i128 = BigFloat_top(z.imag)
    if !CBF_zero(z.real) {
        let apart:i128 = BigFloat_top(z.real) - top
        if apart > 1099511627776 {
            let s = BigFloat_sqrt_of(z.real.mantissa.abs, z.real.exponent as i128, bits)
            let wide = BigFloat_sqrt_of(z.real.mantissa.abs, z.real.exponent as i128, bits + 16)
            let t = BigFloat_quotient(z.imag.mantissa.abs, wide.mantissa, z.imag.exponent as i128 - wide.exponent as i128 - 1, bits, 0)
            if z.real.mantissa.isNegative { return (CBF){t.copy(), CBF_signed(s, minus)} }
            return (CBF){s.copy(), CBF_signed(t, minus)}
        }
        if apart < 0 - 1099511627776 {
            let s = BigFloat_sqrt_of(z.imag.mantissa.abs, z.imag.exponent as i128 - 1, bits)
            return (CBF){s.copy(), CBF_signed(s, minus)}
        }
        if apart > 0 { top = BigFloat_top(z.real) }
    }
    let k:i128 = top / 2
    let r = CBF_sqrt_of(CBF_shifted(z, 0 - 2 * k, 1000000000000), bits)
    return CBF_shifted(r, k, bits)
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
//
// A part is a product, e^x times a cosine, and it is the product that
// is tried against the exponents there are (#589): e^x is kept as a
// term, with its exponent in full, so a part is a number where e^x
// itself is past any exponent and the cosine, or the sine, brings it
// back, exp(CBF(7000000000000000000, tiny)), and where e^x is all but
// below the least number

// e^x of a finite x, as a term
let CBF_exp_term(x:lent BigFloat, bits:i64):CBF_term {
    var k:i128 = 0
    let m = BigFloat_exp_parts(x, bits, &k)
    return (CBF_term){m.mantissa.copy(), m.exponent as i128 + k}
}

// half of e^|x|, which sinh and cosh of an x are, but for the sign of
// sinh, where they are past any exponent
let CBF_exp_half(x:lent BigFloat, bits:i64):CBF_term {
    let size:BigFloat = (BigFloat){x.mantissa.abs, x.exponent, 0}
    let t = CBF_exp_term(size, bits)
    return (CBF_term){t.m.copy(), t.e - 1}
}

// a term above 0 times b, a sine or a cosine, to bits bits, or less
// it: a number wherever the product has an exponent there is. Of a b
// past reckoning it is a NaN, but 0 where the term itself is 0 to the
// bits, b being 1 at the most
let CBF_term_times(t:lent CBF_term, b:lent BigFloat, minus:bool, bits:i64):BigFloat {
    if b.special != 0 {
        if BigFloat_make(t.m, t.e, bits, 0).mantissa.isZero { return BigFloat_zero() }
        return BigFloat_nan()
    }
    let r = BigFloat_make(t.m * b.mantissa, t.e + b.exponent as i128, bits, 0)
    if minus { return -r }
    return r
}

// e^x (cos y + i sin y)
let CBF_exp(z:lent CBF, bits:i64):CBF {
    if CBF_wild(z) { return CBF_wild_by(9, z, bits) }
    if CBF_zero(z.imag) { return (CBF){exp(z.real, bits), BigFloat_zero()} }
    let p:i64 = bits + 16
    let e = CBF_exp_term(z.real, p)
    return (CBF){CBF_term_times(e, cos(z.imag, p), false, bits), CBF_term_times(e, sin(z.imag, p), false, bits)}
}

// sinh(a + ib) = sinh a cos b + i cosh a sin b
let CBF_sinh(z:lent CBF, bits:i64):CBF {
    if CBF_wild(z) { return CBF_wild_by(14, z, bits) }
    if CBF_zero(z.imag) { return (CBF){sinh(z.real, bits), BigFloat_zero()} }
    let p:i64 = bits + 16
    let sh = sinh(z.real, p)
    if sh.special == 1 {
        let h = CBF_exp_half(z.real, p)
        return (CBF){CBF_term_times(h, cos(z.imag, p), z.real.mantissa.isNegative, bits), CBF_term_times(h, sin(z.imag, p), false, bits)}
    }
    return (CBF){CBF_turned(sh, cos(z.imag, p), bits), CBF_mul(cosh(z.real, p), sin(z.imag, p), bits)}
}

// cosh(a + ib) = cosh a cos b + i sinh a sin b
let CBF_cosh(z:lent CBF, bits:i64):CBF {
    if CBF_wild(z) { return CBF_wild_by(15, z, bits) }
    if CBF_zero(z.imag) { return (CBF){cosh(z.real, bits), BigFloat_zero()} }
    let p:i64 = bits + 16
    let ch = cosh(z.real, p)
    if ch.special == 1 {
        let h = CBF_exp_half(z.real, p)
        return (CBF){CBF_term_times(h, cos(z.imag, p), false, bits), CBF_term_times(h, sin(z.imag, p), z.real.mantissa.isNegative, bits)}
    }
    return (CBF){CBF_mul(ch, cos(z.imag, p), bits), CBF_turned(sinh(z.real, p), sin(z.imag, p), bits)}
}

// sin(x + iy) = sin x cosh y + i cos x sinh y
let CBF_sin(z:lent CBF, bits:i64):CBF {
    if CBF_wild(z) { return CBF_wild_by(11, z, bits) }
    if CBF_zero(z.imag) { return (CBF){sin(z.real, bits), BigFloat_zero()} }
    let p:i64 = bits + 16
    let ch = cosh(z.imag, p)
    if ch.special == 1 {
        let h = CBF_exp_half(z.imag, p)
        return (CBF){CBF_term_times(h, sin(z.real, p), false, bits), CBF_term_times(h, cos(z.real, p), z.imag.mantissa.isNegative, bits)}
    }
    return (CBF){CBF_mul(sin(z.real, p), ch, bits), CBF_mul(cos(z.real, p), sinh(z.imag, p), bits)}
}

// cos(x + iy) = cos x cosh y - i sin x sinh y
let CBF_cos(z:lent CBF, bits:i64):CBF {
    if CBF_wild(z) { return CBF_wild_by(12, z, bits) }
    if CBF_zero(z.imag) { return (CBF){cos(z.real, bits), BigFloat_zero()} }
    let p:i64 = bits + 16
    let ch = cosh(z.imag, p)
    if ch.special == 1 {
        let h = CBF_exp_half(z.imag, p)
        return (CBF){CBF_term_times(h, cos(z.real, p), false, bits), CBF_term_times(h, sin(z.real, p), !z.imag.mantissa.isNegative, bits)}
    }
    return (CBF){CBF_mul(cos(z.real, p), ch, bits), -CBF_mul(sin(z.real, p), sinh(z.imag, p), bits)}
}

// tanh(a + ib) = (sinh a cosh a + i sin b cos b) / (sinh^2 a + cos^2 b),
// a sum that cancels nothing, near a pole too; of an a as large as the
// bits, where the sum is all but e^(2|a|) / 4, it is 1 with a's sign and
// 4 sin b cos b e^(-2|a|), a product that is tried against the exponents
// as it is, e^(-2|a|) being a term (#589). z is finite, and b not 0
let CBF_tanh_of(z:lent CBF, bits:i64):CBF {
    let p:i64 = bits + 16
    let s = sin(z.imag, p)
    let c = cos(z.imag, p)
    let size:BigFloat = (BigFloat){z.real.mantissa.abs, z.real.exponent, 0}
    if size >= BigFloat(p) {
        if BigFloat_top(size) > 64 { return (CBF){BigFloat(z.real.mantissa.sign), BigFloat_zero()} }
        let twice:BigFloat = (BigFloat){0 - size.mantissa, size.exponent + 1, 0}
        let e = CBF_exp_term(twice, p)
        let four:CBF_term = (CBF_term){e.m.copy(), e.e + 2}
        // of a b past reckoning a NaN, but where e^(-2|a|) is 0
        return (CBF){BigFloat(z.real.mantissa.sign), CBF_term_times(four, CBF_mul(s, c, p), false, bits)}
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
// 0 times a sine not known is 0. e^x is a term, with its exponent in
// full, and it is its product with the cosine, and with the sine, that is
// tried against the exponents there are (#589)
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
    var e:CBF_term = (CBF_term){BigInt(1), 0}       // e^(the real part of w log z)
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
                e = (CBF_term){BigInt(1), (1 as i128) << 100}
            } else {
                var want:i128 = bits as i128 + 22 + tre
                if tr.m.isZero && want <= q as i128 { want = 2 * q as i128 + 8 }
                if want > limit {
                    lost_e = true
                } else if want > q as i128 {
                    need = want
                } else {
                    e = CBF_exp_term(BigFloat_make(tr.m, tr.e, q, 0), bits + 16)
                    if CBF_top(e) < 0 - 9223372036854775807 as i128 { return (CBF){BigFloat_zero(), BigFloat_zero()} }   // below the least number
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
    if lost_c { c = BigFloat_nan() }
    if lost_s { s = BigFloat_nan() }
    var ec = BigFloat_nan()              // e^x times the cosine, and times the sine
    var es = BigFloat_nan()
    if !lost_e {
        ec = CBF_term_times(e, c, false, bits)
        es = CBF_term_times(e, s, false, bits)
    }
    // the j quarter turns: (c, s), (-s, c), (-c, -s) and (s, -c)
    var re = BigFloat_zero()
    var im = BigFloat_zero()
    if j == 0 || j == 2 {
        re = ec.copy()
        if !still { im = es.copy() }
    } else {
        if !still { re = es.copy() }
        im = ec.copy()
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
