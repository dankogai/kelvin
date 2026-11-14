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
// What it offers is what stays rational, and so exact: + - * /, unary -,
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
