// modules/math+Rational.k - the overlay of math with Rational (#551 to
// #554): read where <math> and <Rational> are both imported, and by no
// program that imports one of them alone. CBR is a complex number whose
// parts are BigRats, fractions of any size, also complexBigRat by its
// alias, as c64 is complex64.
//
//     #import <math>
//     #import <Rational>
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
#import <math>
#import <Rational>

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
