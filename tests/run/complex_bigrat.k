// cbr, complexBigRat by its alias (#552): a complex number of two
// bigrats, of modules/math+Rational.k, the overlay (#551) read where
// <math> and <Rational> are both imported; what stays rational, and so
// exact: + - * /, unary -, == and !=, with a bigrat, a BigInt or an i64
// on either side, conj, norm, z.i and r.i; c64(z) for the rest of math's
#import <math>
#import <Rational>
let main():int32 {
    let z = cbr(1n.over(2n), 1n.over(3n))
    let w:complexBigRat = cbr(3, -4)
    println(z, " ", w, " ", z.typename, " ", cbr(5n), " ", cbr(2n, 3n) == cbr(2, 3))
    println(z + w, " ", z - w, " ", -z)
    println(z * w, " ", z / w, " ", w / w == cbr(1))
    println(z + 1, " ", 1 - z, " ", z * 2n, " ", 1n.over(2n) * z, " ", 1 / w, " ", z / 1n.over(6n))
    println(2n + z, " ", z - 1n.over(2n), " ", 3n / w, " ", w / 5n, " ", 1n.over(3n) - z, " ", z * 6)
    println(conj(z), " ", z.conj(), " ", norm(w), " ", w.norm(), " ", z.i, " ", 1n.over(7n).i, " ", z.i.i == -z)
    println(c64(w), " ", abs(c64(w)), " ", z * z.conj() == cbr(norm(z)), " ", z != w, " ", sizeof(cbr) == sizeof(bigrat) * 2)
    // by 0 it is infinite, by an infinity 0, and 0 by 0 a NaN, which equals nothing, as c64's
    println(w / cbr(0), " ", w / (w / cbr(0)), " ", cbr(0) / cbr(0), " ", cbr(0) / cbr(0) == cbr(0) / cbr(0))
    var p = cbr(1, 1)                                   // (1 + i)^128 = 2^64, past any integer of the machine
    for _ in 0..<7 { p = p * p }
    println(p, " ", (p / cbr(1, 1)).real.den)
    return 0
}
// out: {real: (1n/2n), imag: (1n/3n)} {real: (3n/1n), imag: (-4n/1n)} cbr {real: (5n/1n), imag: (0n/1n)} true
// out: {real: (7n/2n), imag: (-11n/3n)} {real: (-5n/2n), imag: (13n/3n)} {real: (-1n/2n), imag: (-1n/3n)}
// out: {real: (17n/6n), imag: (-1n/1n)} {real: (1n/150n), imag: (3n/25n)} true
// out: {real: (3n/2n), imag: (1n/3n)} {real: (1n/2n), imag: (-1n/3n)} {real: (1n/1n), imag: (2n/3n)} {real: (1n/4n), imag: (1n/6n)} {real: (3n/25n), imag: (4n/25n)} {real: (3n/1n), imag: (2n/1n)}
// out: {real: (5n/2n), imag: (1n/3n)} {real: (0n/1n), imag: (1n/3n)} {real: (9n/25n), imag: (12n/25n)} {real: (3n/5n), imag: (-4n/5n)} {real: (-1n/6n), imag: (-1n/3n)} {real: (3n/1n), imag: (2n/1n)}
// out: {real: (1n/2n), imag: (-1n/3n)} {real: (1n/2n), imag: (-1n/3n)} (25n/1n) (25n/1n) {real: (-1n/3n), imag: (1n/2n)} {real: (0n/1n), imag: (1n/7n)} true
// out: {real: 3.0, imag: -4.0} 5.0 true true true
// out: {real: (1n/0n), imag: (-1n/0n)} {real: (0n/1n), imag: (0n/1n)} {real: (0n/0n), imag: (0n/0n)} false
// out: {real: (18446744073709551616n/1n), imag: (0n/1n)} 1n
