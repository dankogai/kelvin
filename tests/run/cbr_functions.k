// a cbr's functions that are not rational, to a precision (#554), of
// modules/math+Rational.k, the overlay of math with Rational (#551): each
// part of f(z, precision) is within 2^-precision of the true value's, and
// f(z) is the same to bigrat.precision, 128 bits; abs and arg give a
// bigrat; each a method too. The inverses take their principal values,
// with C99's branch cuts, a point on a cut on the side a float's +0 is.
// Reckoned in BigInts alone, so every system prints the same; the values
// here agree with another reckoning of them.
#import <math>
#import <Rational>

// whether each part of a and of b are within 2^-bits of each other
let near(a:lent cbr, b:lent cbr, bits:i64):bool {
    let d = a - b
    let eps = bigrat(1n, 1n << bits)
    return d.real < eps && -d.real < eps && d.imag < eps && -d.imag < eps
}

let main():int32 {
    let z = cbr(1n.over(3n), 1n.over(7n))
    let w = cbr(1, 2)
    // to 32 bits: each part over 2^32, or less where it is not in lowest terms
    println(abs(w, 32), " ", arg(w, 32), " ", sqrt(w, 32))
    println(exp(w, 32), " ", log(w, 32))
    println(sin(w, 32), " ", cos(w, 32), " ", tan(w, 32))
    println(sinh(w, 32), " ", cosh(w, 32), " ", tanh(w, 32))
    println(asin(w, 32), " ", acos(w, 32), " ", atan(w, 32))
    println(asinh(w, 32), " ", acosh(w, 32), " ", atanh(w, 32))
    println(pow(w, z, 32), " ", pow(w, bigrat(1, 2), 32), " ", pow(bigrat(2), w, 32))
    // e^(i pi) is -1, to as many bits as pi has; i^i is e^(-pi/2), a real number
    println(exp(cbr(bigrat(0), bigrat.pi(200)), 64), " ", pow(cbr(0, 1), cbr(0, 1), 64))
    // a whole power is exact, then rounded: (1 + i)^128 is 2^64
    println(pow(cbr(1, 1), cbr(128), 0), " ", pow(cbr(1, 1), cbr(-2), 4), " ", pow(cbr(1n.over(2n), 1n.over(4n)), cbr(3), 64) == cbr(1n.over(32n), 11n.over(64n)))
    // on a branch cut, the side C99 gives a +0
    println(sqrt(cbr(-4), 8), " ", log(cbr(-1), 8), " ", arg(cbr(-1), 8))
    println(asin(cbr(2), 8), " ", asin(cbr(-2), 8), " ", acos(cbr(2), 8))
    println(asinh(cbr(0, 2), 8), " ", asinh(cbr(0, -2), 8), " ", atan(cbr(0, 2), 8), " ", atan(cbr(0, -2), 8))
    println(acosh(cbr(-2), 8), " ", acosh(cbr(1n.over(2n)), 8), " ", atanh(cbr(2), 8), " ", atanh(cbr(-2), 8))
    // a precision is of bits after the point; a large result has more bits in all
    println(exp(cbr(10, 1), 0), " ", exp(cbr(-100, 1), 64), " ", tan(cbr(1570796n.over(1000000n), 1n.over(1000000000n)), 0))
    // with no precision it is bigrat.precision; each is a method too
    println(exp(z) == exp(z, 128), " ", z.log() == log(z, bigrat.precision), " ", abs(z) == sqrt(norm(z)), " ", pow(z, z) == z.pow(z, 128))
    println(z.exp(16), " ", z.abs(16), " ", z.arg(16), " ", z.sqrt(16), " ", z.pow(cbr(2), 16), " ", z.atanh(16))
    // what they are of each other, to 120 bits of 128
    println(near(exp(log(z)), z, 120), " ", near(sqrt(z) * sqrt(z), z, 120), " ", near(sin(z) * sin(z) + cos(z) * cos(z), cbr(1), 120), " ",
            near(tan(atan(z)), z, 120), " ", near(sinh(asinh(z)), z, 120), " ", near(cosh(acosh(z)), z, 120), " ", near(tanh(atanh(z)), z, 120), " ",
            near(pow(z, w), exp(w * log(z)), 120))
    // an infinity and a NaN
    let nan = bigrat(0, 0)
    let inf = bigrat(1, 0)
    let ninf = bigrat(-1, 0)
    println(sqrt(cbr(0)), " ", sqrt(cbr(inf, bigrat(1))), " ", sqrt(cbr(ninf, bigrat(-1))), " ", sqrt(cbr(nan, bigrat(1))))
    println(exp(cbr(ninf, bigrat(1))), " ", exp(cbr(inf, bigrat(1))), " ", exp(cbr(bigrat(10000000000), bigrat(2))), " ", exp(cbr(bigrat(1), inf)))
    println(log(cbr(0)), " ", log(cbr(inf, bigrat(1)), 8), " ", atanh(cbr(1)), " ", atanh(cbr(-1)), " ", atan(cbr(0, 1)))
    println(sin(cbr(inf, bigrat(1))), " ", tanh(cbr(inf, bigrat(1))), " ", tanh(cbr(ninf, bigrat(1))), " ", pow(cbr(0), cbr(0)), " ", pow(cbr(0), cbr(2, 1)), " ", pow(cbr(0), cbr(-1)))
    // c64's own are as they were
    println(abs(c64(3.0, 4.0)), " ", exp(c64(0.0, 0.0)), " ", abs(cbr(3, 4), 0))
    return 0
}
// out: (9603838835n/4294967296n) (4755167535n/4294967296n) {real: (5463282795n/4294967296n), imag: (3376494457n/4294967296n)}
// out: {real: (-4858485833n/4294967296n), imag: (10615985221n/4294967296n)} {real: (3456241599n/4294967296n), imag: (4755167535n/4294967296n)}
// out: {real: (13596915181n/4294967296n), imag: (4208211193n/2147483648n)} {real: (8730478837n/4294967296n), imag: (-6553900619n/2147483648n)} {real: (72612491n/2147483648n), imag: (2179252697n/2147483648n)}
// out: {real: (-1050240319n/2147483648n), imag: (3013175647n/2147483648n)} {real: (-2758005195n/4294967296n), imag: (4589633927n/4294967296n)} {real: (1252773517n/1073741824n), imag: (-261411253n/1073741824n)}
// out: {real: (1834288561n/4294967296n), imag: (6565162109n/4294967296n)} {real: (4912230291n/4294967296n), imag: (-6565162109n/4294967296n)} {real: (5750843193n/4294967296n), imag: (54003775n/134217728n)}
// out: {real: (788852211n/536870912n), imag: (4567440123n/4294967296n)} {real: (6565162109n/4294967296n), imag: (4912230291n/4294967296n)} {real: (372130559n/2147483648n), imag: (5059889139n/4294967296n)}
// out: {real: (1060999649n/1073741824n), imag: (2231144975n/4294967296n)} {real: (5463282795n/4294967296n), imag: (3376494457n/4294967296n)} {real: (1575883413n/4294967296n), imag: (1055517999n/536870912n)}
// out: {real: (-1n/1n), imag: (0n/1n)} {real: (3834701343093669495n/18446744073709551616n), imag: (0n/1n)}
// out: {real: (18446744073709551616n/1n), imag: (0n/1n)} {real: (0n/1n), imag: (-1n/2n)} true
// out: {real: (0n/1n), imag: (2n/1n)} {real: (0n/1n), imag: (201n/64n)} (201n/64n)
// out: {real: (201n/128n), imag: (337n/256n)} {real: (-201n/128n), imag: (337n/256n)} {real: (0n/1n), imag: (-337n/256n)}
// out: {real: (337n/256n), imag: (201n/128n)} {real: (337n/256n), imag: (-201n/128n)} {real: (201n/128n), imag: (141n/256n)} {real: (201n/128n), imag: (-141n/256n)}
// out: {real: (337n/256n), imag: (201n/64n)} {real: (0n/1n), imag: (67n/64n)} {real: (141n/256n), imag: (201n/128n)} {real: (-141n/256n), imag: (201n/128n)}
// out: {real: (11901n/1n), imag: (18535n/1n)} {real: (0n/1n), imag: (0n/1n)} {real: (3059995n/1n), imag: (9364n/1n)}
// out: true true true true
// out: {real: (90531n/65536n), imag: (6511n/32768n)} (23767n/65536n) (26535n/65536n) {real: (9665n/16384n), imag: (7935n/65536n)} {real: (743n/8192n), imag: (3121n/32768n)} {real: (5541n/16384n), imag: (10415n/65536n)}
// out: true true true true true true true true
// out: {real: (0n/1n), imag: (0n/1n)} {real: (1n/0n), imag: (0n/1n)} {real: (0n/1n), imag: (-1n/0n)} {real: (0n/0n), imag: (0n/0n)}
// out: {real: (0n/1n), imag: (0n/1n)} {real: (1n/0n), imag: (1n/0n)} {real: (-1n/0n), imag: (1n/0n)} {real: (0n/0n), imag: (0n/0n)}
// out: {real: (-1n/0n), imag: (0n/1n)} {real: (1n/0n), imag: (0n/1n)} {real: (1n/0n), imag: (0n/1n)} {real: (-1n/0n), imag: (0n/1n)} {real: (0n/1n), imag: (1n/0n)}
// out: {real: (0n/0n), imag: (0n/0n)} {real: (1n/1n), imag: (0n/1n)} {real: (-1n/1n), imag: (0n/1n)} {real: (1n/1n), imag: (0n/1n)} {real: (0n/1n), imag: (0n/1n)} {real: (1n/0n), imag: (0n/1n)}
// out: 5.0 {real: 1.0, imag: 0.0} (5n/1n)
