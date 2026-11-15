// a CBR's functions that are not rational, to a precision (#554), of
// modules/math+Rational.k, the overlay of math with Rational (#551): each
// part of f(z, precision) is within 2^-precision of the true value's, and
// f(z) is the same to BigRat.precision, 128 bits; abs and arg give a
// BigRat; each a method too. The inverses take their principal values,
// with C99's branch cuts, a point on a cut on the side a float's +0 is.
// Reckoned in BigInts alone, so every system prints the same; the values
// here agree with another reckoning of them.
#import <math>
#import <Rational>

// whether each part of a and of b are within 2^-bits of each other
let near(a:lent CBR, b:lent CBR, bits:i64):bool {
    let d = a - b
    let eps = BigRat(1n, 1n << bits)
    return d.real < eps && -d.real < eps && d.imag < eps && -d.imag < eps
}

let main():int32 {
    let z = CBR(1n.over(3n), 1n.over(7n))
    let w = CBR(1, 2)
    // to 32 bits: each part over 2^32, or less where it is not in lowest terms
    println(abs(w, 32), " ", arg(w, 32), " ", sqrt(w, 32))
    println(exp(w, 32), " ", log(w, 32))
    println(sin(w, 32), " ", cos(w, 32), " ", tan(w, 32))
    println(sinh(w, 32), " ", cosh(w, 32), " ", tanh(w, 32))
    println(asin(w, 32), " ", acos(w, 32), " ", atan(w, 32))
    println(asinh(w, 32), " ", acosh(w, 32), " ", atanh(w, 32))
    println(pow(w, z, 32), " ", pow(w, BigRat(1, 2), 32), " ", pow(BigRat(2), w, 32))
    // e^(i pi) is -1, to as many bits as pi has; i^i is e^(-pi/2), a real number
    println(exp(CBR(BigRat(0), BigRat.pi(200)), 64), " ", pow(CBR(0, 1), CBR(0, 1), 64))
    // a whole power is exact, then rounded: (1 + i)^128 is 2^64
    println(pow(CBR(1, 1), CBR(128), 0), " ", pow(CBR(1, 1), CBR(-2), 4), " ", pow(CBR(1n.over(2n), 1n.over(4n)), CBR(3), 64) == CBR(1n.over(32n), 11n.over(64n)))
    // on a branch cut, the side C99 gives a +0
    println(sqrt(CBR(-4), 8), " ", log(CBR(-1), 8), " ", arg(CBR(-1), 8))
    println(asin(CBR(2), 8), " ", asin(CBR(-2), 8), " ", acos(CBR(2), 8))
    println(asinh(CBR(0, 2), 8), " ", asinh(CBR(0, -2), 8), " ", atan(CBR(0, 2), 8), " ", atan(CBR(0, -2), 8))
    println(acosh(CBR(-2), 8), " ", acosh(CBR(1n.over(2n)), 8), " ", atanh(CBR(2), 8), " ", atanh(CBR(-2), 8))
    // a precision is of bits after the point; a large result has more bits in all
    println(exp(CBR(10, 1), 0), " ", exp(CBR(-100, 1), 64), " ", tan(CBR(1570796n.over(1000000n), 1n.over(1000000000n)), 0))
    // with no precision it is BigRat.precision; each is a method too
    println(exp(z) == exp(z, 128), " ", z.log() == log(z, BigRat.precision), " ", abs(z) == sqrt(norm(z)), " ", pow(z, z) == z.pow(z, 128))
    println(z.exp(16), " ", z.abs(16), " ", z.arg(16), " ", z.sqrt(16), " ", z.pow(CBR(2), 16), " ", z.atanh(16))
    // what they are of each other, to 120 bits of 128
    println(near(exp(log(z)), z, 120), " ", near(sqrt(z) * sqrt(z), z, 120), " ", near(sin(z) * sin(z) + cos(z) * cos(z), CBR(1), 120), " ",
            near(tan(atan(z)), z, 120), " ", near(sinh(asinh(z)), z, 120), " ", near(cosh(acosh(z)), z, 120), " ", near(tanh(atanh(z)), z, 120), " ",
            near(pow(z, w), exp(w * log(z)), 120))
    // an infinity and a NaN
    let nan = BigRat(0, 0)
    let inf = BigRat(1, 0)
    let ninf = BigRat(-1, 0)
    println(sqrt(CBR(0)), " ", sqrt(CBR(inf, BigRat(1))), " ", sqrt(CBR(ninf, BigRat(-1))), " ", sqrt(CBR(nan, BigRat(1))))
    println(exp(CBR(ninf, BigRat(1))), " ", exp(CBR(inf, BigRat(1))), " ", exp(CBR(BigRat(10000000000), BigRat(2))), " ", exp(CBR(BigRat(1), inf)))
    println(log(CBR(0)), " ", log(CBR(inf, BigRat(1)), 8), " ", atanh(CBR(1)), " ", atanh(CBR(-1)), " ", atan(CBR(0, 1)))
    println(sin(CBR(inf, BigRat(1))), " ", tanh(CBR(inf, BigRat(1))), " ", tanh(CBR(ninf, BigRat(1))), " ", pow(CBR(0), CBR(0)), " ", pow(CBR(0), CBR(2, 1)), " ", pow(CBR(0), CBR(-1)))
    // c64's own are as they were
    println(abs(c64(3.0, 4.0)), " ", exp(c64(0.0, 0.0)), " ", abs(CBR(3, 4), 0))
    return 0
}
// out: (9603838835n/4294967296n) (4755167535n/4294967296n) ((5463282795n/4294967296n)+(3376494457n/4294967296n).i)
// out: ((-4858485833n/4294967296n)+(10615985221n/4294967296n).i) ((3456241599n/4294967296n)+(4755167535n/4294967296n).i)
// out: ((13596915181n/4294967296n)+(4208211193n/2147483648n).i) ((8730478837n/4294967296n)+(-6553900619n/2147483648n).i) ((72612491n/2147483648n)+(2179252697n/2147483648n).i)
// out: ((-1050240319n/2147483648n)+(3013175647n/2147483648n).i) ((-2758005195n/4294967296n)+(4589633927n/4294967296n).i) ((1252773517n/1073741824n)+(-261411253n/1073741824n).i)
// out: ((1834288561n/4294967296n)+(6565162109n/4294967296n).i) ((4912230291n/4294967296n)+(-6565162109n/4294967296n).i) ((5750843193n/4294967296n)+(54003775n/134217728n).i)
// out: ((788852211n/536870912n)+(4567440123n/4294967296n).i) ((6565162109n/4294967296n)+(4912230291n/4294967296n).i) ((372130559n/2147483648n)+(5059889139n/4294967296n).i)
// out: ((1060999649n/1073741824n)+(2231144975n/4294967296n).i) ((5463282795n/4294967296n)+(3376494457n/4294967296n).i) ((1575883413n/4294967296n)+(1055517999n/536870912n).i)
// out: ((-1n/1n)+(0n/1n).i) ((3834701343093669495n/18446744073709551616n)+(0n/1n).i)
// out: ((18446744073709551616n/1n)+(0n/1n).i) ((0n/1n)+(-1n/2n).i) true
// out: ((0n/1n)+(2n/1n).i) ((0n/1n)+(201n/64n).i) (201n/64n)
// out: ((201n/128n)+(337n/256n).i) ((-201n/128n)+(337n/256n).i) ((0n/1n)+(-337n/256n).i)
// out: ((337n/256n)+(201n/128n).i) ((337n/256n)+(-201n/128n).i) ((201n/128n)+(141n/256n).i) ((201n/128n)+(-141n/256n).i)
// out: ((337n/256n)+(201n/64n).i) ((0n/1n)+(67n/64n).i) ((141n/256n)+(201n/128n).i) ((-141n/256n)+(201n/128n).i)
// out: ((11901n/1n)+(18535n/1n).i) ((0n/1n)+(0n/1n).i) ((3059995n/1n)+(9364n/1n).i)
// out: true true true true
// out: ((90531n/65536n)+(6511n/32768n).i) (23767n/65536n) (26535n/65536n) ((9665n/16384n)+(7935n/65536n).i) ((743n/8192n)+(3121n/32768n).i) ((5541n/16384n)+(10415n/65536n).i)
// out: true true true true true true true true
// out: ((0n/1n)+(0n/1n).i) ((1n/0n)+(0n/1n).i) ((0n/1n)+(-1n/0n).i) ((0n/0n)+(0n/0n).i)
// out: ((0n/1n)+(0n/1n).i) ((1n/0n)+(1n/0n).i) ((-1n/0n)+(1n/0n).i) ((0n/0n)+(0n/0n).i)
// out: ((-1n/0n)+(0n/1n).i) ((1n/0n)+(0n/1n).i) ((1n/0n)+(0n/1n).i) ((-1n/0n)+(0n/1n).i) ((0n/1n)+(1n/0n).i)
// out: ((0n/0n)+(0n/0n).i) ((1n/1n)+(0n/1n).i) ((-1n/1n)+(0n/1n).i) ((1n/1n)+(0n/1n).i) ((0n/1n)+(0n/1n).i) ((1n/0n)+(0n/1n).i)
// out: 5.0 (1.0+0.0.i) (5n/1n)
