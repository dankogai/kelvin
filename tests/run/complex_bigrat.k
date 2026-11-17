// CBR, complexBigRat by its alias (#552): a complex number of two
// BigRats, of modules/BigNum.k, #import <BigNum> (#590), the overlay of
// math with Rational before (#551); what stays rational, and so
// exact: + - * /, unary -, == and !=, with a BigRat, a BigInt or an i64
// on either side, conj, norm, z.i and r.i; c64(z) for the rest of math's
#import <BigNum>
let main():int32 {
    let z = CBR(1n.over(2n), 1n.over(3n))
    let w:complexBigRat = CBR(3, -4)
    println(z, " ", w, " ", z.typename, " ", CBR(5n), " ", CBR(2n, 3n) == CBR(2, 3))
    println(z + w, " ", z - w, " ", -z)
    println(z * w, " ", z / w, " ", w / w == CBR(1))
    println(z + 1, " ", 1 - z, " ", z * 2n, " ", 1n.over(2n) * z, " ", 1 / w, " ", z / 1n.over(6n))
    println(2n + z, " ", z - 1n.over(2n), " ", 3n / w, " ", w / 5n, " ", 1n.over(3n) - z, " ", z * 6)
    println(conj(z), " ", z.conj(), " ", norm(w), " ", w.norm(), " ", z.i, " ", 1n.over(7n).i, " ", z.i.i == -z)
    println(c64(w), " ", abs(c64(w)), " ", z * z.conj() == CBR(norm(z)), " ", z != w, " ", sizeof(CBR) == sizeof(BigRat) * 2)
    // by 0 it is infinite, by an infinity 0, and 0 by 0 a NaN, which equals nothing, as c64's
    println(w / CBR(0), " ", w / (w / CBR(0)), " ", CBR(0) / CBR(0), " ", CBR(0) / CBR(0) == CBR(0) / CBR(0))
    var p = CBR(1, 1)                                   // (1 + i)^128 = 2^64, past any integer of the machine
    for _ in 0..<7 { p = p * p }
    println(p, " ", (p / CBR(1, 1)).real.den)
    return 0
}
// out: ((1n/2n)+(1n/3n).i) ((3n/1n)+(-4n/1n).i) CBR ((5n/1n)+(0n/1n).i) true
// out: ((7n/2n)+(-11n/3n).i) ((-5n/2n)+(13n/3n).i) ((-1n/2n)+(-1n/3n).i)
// out: ((17n/6n)+(-1n/1n).i) ((1n/150n)+(3n/25n).i) true
// out: ((3n/2n)+(1n/3n).i) ((1n/2n)+(-1n/3n).i) ((1n/1n)+(2n/3n).i) ((1n/4n)+(1n/6n).i) ((3n/25n)+(4n/25n).i) ((3n/1n)+(2n/1n).i)
// out: ((5n/2n)+(1n/3n).i) ((0n/1n)+(1n/3n).i) ((9n/25n)+(12n/25n).i) ((3n/5n)+(-4n/5n).i) ((-1n/6n)+(-1n/3n).i) ((3n/1n)+(2n/1n).i)
// out: ((1n/2n)+(-1n/3n).i) ((1n/2n)+(-1n/3n).i) (25n/1n) (25n/1n) ((-1n/3n)+(1n/2n).i) ((0n/1n)+(1n/7n).i) true
// out: (3.0-4.0.i) 5.0 true true true
// out: ((1n/0n)+(-1n/0n).i) ((0n/1n)+(0n/1n).i) ((0n/0n)+(0n/0n).i) false
// out: ((18446744073709551616n/1n)+(0n/1n).i) 1n
