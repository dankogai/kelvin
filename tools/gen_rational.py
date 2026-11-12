#!/usr/bin/env python3 -I
"""gen_rational.py: modules/Rational.k, the module of #import <Rational>
(#538, #539, #540; this script #541). Kelvin has no generic struct, so
rat8, rat16, rat32 and rat64 are one text written out for each width, and
bigrat, of two BigInts, is written once beside them. Writes
modules/Rational.k, which `make` runs when this script is the newer.
Change the module here and rerun, not in the file it writes.

    python3 -I tools/gen_rational.py
"""
import os
here = os.path.dirname(os.path.abspath(__file__))
path = os.path.join(os.path.dirname(here), 'modules', 'Rational.k')

widths = [8, 16, 32, 64]
most = {8: "127", 16: "32767", 32: "2147483647", 64: "9223372036854775807"}
out = []
w = out.append
w('''// modules/Rational.k - rational numbers (#538, #539, #540): a numerator over a
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
//
// bigrat is of two BigInts, a fraction of any precision, which every
// result fits: 1n.over(3n) makes one, and it shows as (1n/3n).
//
// Written by tools/gen_rational.py, which writes the four widths out from
// one text; do not edit: change the script and rerun it.
''')
for b in reversed(widths):
    w(f'''
struct rat{b} {{
    num: i{b}
    den: i{b}
}}''')
w('''

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

let rat64_lowest(n:i128, d:i128):rat64 { rat_lowest(n, d, 9223372036854775807) }''')
for b in [32, 16, 8]:
    w(f'''let rat{b}_lowest(n:i128, d:i128):rat{b} {{
    let r:rat64 = rat_lowest(n, d, {most[b]})
    return (rat{b}){{r.num as i{b}, r.den as i{b}}}
}}''')
w('')
for b in reversed(widths):
    w(f'''let rat{b}(num:i{b}, den:i{b}):rat{b} {{ rat{b}_lowest(num as i128, den as i128) }}
let rat{b}(num:i{b}):rat{b} {{ (rat{b}){{num, 1}} }}''')
w('''
// of another width: the same value, or a NaN where the narrower does not
// hold it''')
for b in reversed(widths):
    for c in reversed(widths):
        if b != c:
            w(f'let rat{b}(r:rat{c}):rat{b} {{ rat{b}_lowest(r.num as i128, r.den as i128) }}')
w('''
// n.over(d) is (n/d), of the signed integer type of n''')
for b in reversed(widths):
    w(f'''extend i{b} {{
    let over(den:i{b}):rat{b} {{ rat{b}_lowest(self as i128, den as i128) }}
}}''')
w('''
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
''')
for b in reversed(widths):
    w(f'''extend rat{b} {{
    let isNaN:bool {{ self.num == 0 && self.den == 0 }}
    let isInfinite:bool {{ self.num != 0 && self.den == 0 }}
    let isFinite:bool {{ self.den != 0 }}

    // the nearest f64: an infinity's is inf or -inf, a NaN's nan
    let f64:f64 {{ self.num as f64 / self.den as f64 }}

    // (num.hex/den.hex), and the same in base 8 and base 2
    let hex:String {{ rat_text(self.num.hex, self.den.hex) }}
    let oct:String {{ rat_text(self.num.oct, self.den.oct) }}
    let bin:String {{ rat_text(self.num.bin, self.den.bin) }}
}}

// its text: (1/3), (-1/3), (1/0) of an infinity, (0/0) of a NaN
let rat{b}.cstr():cstr {{ `(${{.num}}/${{.den}})` }}
''')
w('''// ---------- arithmetic ----------
''')
for b in reversed(widths):
    w(f'''extend rat{b} {{
    static let +(a:Self, b:Self):Self {{
        if a.den == 0 && b.den == 0 {{                    // two infinities: the same one, else a NaN
            return a.num == b.num ? a : (Self){{0, 0}}
        }}
        return rat{b}_lowest(a.num as i128 * b.den as i128 + b.num as i128 * a.den as i128, a.den as i128 * b.den as i128)
    }}
    static let +(a:Self, b:i{b}):Self {{ a + rat{b}(b) }}
    static let +(a:i{b}, b:Self):Self {{ rat{b}(a) + b }}
    static let -(a:Self):Self {{ rat{b}_lowest(-(a.num as i128), a.den as i128) }}
    static let -(a:Self, b:Self):Self {{ a + -b }}
    static let -(a:Self, b:i{b}):Self {{ a + -rat{b}(b) }}
    static let -(a:i{b}, b:Self):Self {{ rat{b}(a) + -b }}
    static let *(a:Self, b:Self):Self {{
        rat{b}_lowest(a.num as i128 * b.num as i128, a.den as i128 * b.den as i128)
    }}
    static let *(a:Self, b:i{b}):Self {{ a * rat{b}(b) }}
    static let *(a:i{b}, b:Self):Self {{ rat{b}(a) * b }}
    // by 0 it is an infinity, and 0 by 0 a NaN: no division by zero
    static let /(a:Self, b:Self):Self {{
        rat{b}_lowest(a.num as i128 * b.den as i128, a.den as i128 * b.num as i128)
    }}
    static let /(a:Self, b:i{b}):Self {{ a / rat{b}(b) }}
    static let /(a:i{b}, b:Self):Self {{ rat{b}(a) / b }}

    // a NaN equals nothing and has no order, as a float's
    static let ==(a:Self, b:Self):bool {{ !a.isNaN && !b.isNaN && a.num == b.num && a.den == b.den }}
    static let !=(a:Self, b:Self):bool {{ !(a == b) }}
    static let <(a:Self, b:Self):bool {{
        if a.isNaN || b.isNaN {{ return false }}
        if a.den == 0 && b.den == 0 {{ return a.num < b.num }}
        return a.num as i128 * b.den as i128 < b.num as i128 * a.den as i128
    }}
    static let >(a:Self, b:Self):bool {{ b < a }}
    static let <=(a:Self, b:Self):bool {{ a < b || a == b }}
    static let >=(a:Self, b:Self):bool {{ b < a || a == b }}
}}
''')
w('''// ---------- bigrat: of two BigInts, of any size (#540) ----------

struct bigrat {
    num: BigInt
    den: BigInt
}

// n over d in lowest terms, d 0 or more: of 0 a sign over 0, an infinity,
// or (0/0), a NaN; every other fits, as a BigInt holds any integer
let bigrat_lowest(n:lent BigInt, d:lent BigInt):bigrat {
    if d.isZero { return (bigrat){BigInt(n.sign), BigInt(0)} }
    if n.isZero { return (bigrat){BigInt(0), BigInt(1)} }
    let g = n.abs.gcd(d.abs)
    if d.isNegative { return (bigrat){-n / g, -d / g} }
    return (bigrat){n / g, d / g}
}

let bigrat(num:lent BigInt, den:lent BigInt):bigrat { bigrat_lowest(num, den) }
let bigrat(num:lent BigInt):bigrat { bigrat_lowest(num, BigInt(1)) }
let bigrat(num:i64, den:i64):bigrat { bigrat_lowest(BigInt(num), BigInt(den)) }
let bigrat(num:i64):bigrat { bigrat_lowest(BigInt(num), BigInt(1)) }
// of a rational of integers, which it always holds''')
for b in reversed(widths):
    w(f'let bigrat(r:rat{b}):bigrat {{ (bigrat){{BigInt(r.num as i128), BigInt(r.den as i128)}} }}')
w('''
// a rational of integers of a bigrat: the same value, or a NaN where its
// parts do not fit
let rat64(r:lent bigrat):rat64 {
    if let n = r.num.exactI64 {
        if let d = r.den.exactI64 { return (rat64){n, d} }
    }
    return (rat64){0, 0}
}
let rat32(r:lent bigrat):rat32 { rat32(rat64(r)) }
let rat16(r:lent bigrat):rat16 { rat16(rat64(r)) }
let rat8(r:lent bigrat):rat8 { rat8(rat64(r)) }

// n.over(d) of a BigInt is a bigrat: 1n.over(3n), and 1n.over(3)
extend BigInt {
    let over(den:lent BigInt):bigrat { bigrat_lowest(self, den) }
    let over(den:i64):bigrat { bigrat_lowest(self, BigInt(den)) }
}

extend bigrat {
    let isNaN:bool { self.num.isZero && self.den.isZero }
    let isInfinite:bool { !self.num.isZero && self.den.isZero }
    let isFinite:bool { !self.den.isZero }

    // an f64 of it: 66 bits of the quotient, scaled back; past an f64's
    // range inf or -inf, below it 0; an infinity's inf or -inf, a NaN's nan
    let f64:f64 {
        if self.den.isZero { return self.num.sign as f64 / 0.0 }
        if self.num.isZero { return 0.0 }
        let shift:i64 = self.den.bits.count as i64 - self.num.abs.bits.count as i64 + 66
        var x:f64 = 0.0
        if shift >= 0 {
            x = ((self.num << shift) / self.den).f64
        } else {
            x = (self.num / (self.den << (0 - shift))).f64
        }
        var k:i64 = shift
        while k > 0 && x != 0.0 {
            x = x * 0.5
            k -= 1
        }
        while k < 0 && x - x == 0.0 {
            x = x * 2.0
            k += 1
        }
        return x
    }

    // its text, of any length: (1n/3n), its parts as a BigInt shows
    let string:String {
        var s = $"("
        s += self.num.string
        s += "/"
        s += self.den.string
        s += ")"
        return s
    }
    // (num.hex/den.hex), and the same in base 8 and base 2
    let hex:String {
        var s = $"("
        s += self.num.hex
        s += "/"
        s += self.den.hex
        s += ")"
        return s
    }
    let oct:String {
        var s = $"("
        s += self.num.oct
        s += "/"
        s += self.den.oct
        s += ")"
        return s
    }
    let bin:String {
        var s = $"("
        s += self.num.bin
        s += "/"
        s += self.den.bin
        s += ")"
        return s
    }
}

extend bigrat {
    static let +(a:Self, b:Self):Self {
        if a.den.isZero && b.den.isZero {                // two infinities: the same one, else a NaN
            if a.num == b.num { return (Self){BigInt(a.num.sign), BigInt(0)} }
            return (Self){BigInt(0), BigInt(0)}
        }
        return bigrat_lowest(a.num * b.den + b.num * a.den, a.den * b.den)
    }
    static let +(a:Self, b:BigInt):Self { a + bigrat(b) }
    static let +(a:BigInt, b:Self):Self { bigrat(a) + b }
    static let +(a:Self, b:i64):Self { a + bigrat(b) }
    static let +(a:i64, b:Self):Self { bigrat(a) + b }
    static let -(a:Self):Self { bigrat_lowest(-a.num, a.den) }
    static let -(a:Self, b:Self):Self { a + -b }
    static let -(a:Self, b:BigInt):Self { a + -bigrat(b) }
    static let -(a:BigInt, b:Self):Self { bigrat(a) + -b }
    static let -(a:Self, b:i64):Self { a + -bigrat(b) }
    static let -(a:i64, b:Self):Self { bigrat(a) + -b }
    static let *(a:Self, b:Self):Self { bigrat_lowest(a.num * b.num, a.den * b.den) }
    static let *(a:Self, b:BigInt):Self { a * bigrat(b) }
    static let *(a:BigInt, b:Self):Self { bigrat(a) * b }
    static let *(a:Self, b:i64):Self { a * bigrat(b) }
    static let *(a:i64, b:Self):Self { bigrat(a) * b }
    // by 0 it is an infinity, and 0 by 0 a NaN: no division by zero
    static let /(a:Self, b:Self):Self { bigrat_lowest(a.num * b.den, a.den * b.num) }
    static let /(a:Self, b:BigInt):Self { a / bigrat(b) }
    static let /(a:BigInt, b:Self):Self { bigrat(a) / b }
    static let /(a:Self, b:i64):Self { a / bigrat(b) }
    static let /(a:i64, b:Self):Self { bigrat(a) / b }

    // a NaN equals nothing and has no order, as a float's
    static let ==(a:Self, b:Self):bool { !a.isNaN && !b.isNaN && a.num == b.num && a.den == b.den }
    static let !=(a:Self, b:Self):bool { !(a == b) }
    static let <(a:Self, b:Self):bool {
        if a.isNaN || b.isNaN { return false }
        if a.den.isZero && b.den.isZero { return a.num < b.num }
        return a.num * b.den < b.num * a.den
    }
    static let >(a:Self, b:Self):bool { b < a }
    static let <=(a:Self, b:Self):bool { a < b || a == b }
    static let >=(a:Self, b:Self):bool { b < a || a == b }
}
''')
text = '\n'.join(out).rstrip('\n') + '\n'
with open(path, 'w', encoding='utf-8') as f:
    f.write(text)
print('modules/Rational.k:', text.count('\n'), 'lines')
