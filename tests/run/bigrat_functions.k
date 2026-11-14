// the functions of a bigrat that are not rational, to a precision (#553),
// of modules/math+Rational.k, the overlay of math with Rational (#551):
// f(x, precision) is a bigrat of 2^precision parts within one of them of
// the true value, and f(x) the same to bigrat.precision, 128 bits; each a
// method too. They are reckoned in BigInts alone, so every system prints
// the same; the values here agree with another reckoning of them.
#import <math>
#import <Rational>

// the first digits of r after its point, cut: of r times 10^digits
let digits(r:lent bigrat, count:i64):BigInt {
    let scaled = r * 10n ** count
    return scaled.num / scaled.den
}
// whether a and b are within 2^-bits of each other
let near(a:lent bigrat, b:lent bigrat, bits:i64):bool {
    let d = a - b
    let eps = bigrat(1n, 1n << bits)
    return d < eps && -d < eps
}

let main():int32 {
    // constants, 60 digits of each from 256 bits
    println(digits(bigrat.pi(256), 60))
    println(digits(exp(bigrat(1), 256), 60))
    println(digits(sqrt(bigrat(2), 256), 60))
    println(digits(log(bigrat(2), 256), 60))
    // to 64 bits: over 2^64, or less where it is not in lowest terms
    println(bigrat.pi(64), " ", sqrt(bigrat(2), 64))
    println(exp(bigrat(1), 64), " ", log(bigrat(10), 64))
    println(sin(bigrat(1), 64), " ", cos(bigrat(1), 64), " ", tan(bigrat(1), 64))
    println(atan(bigrat(1), 64), " ", asin(bigrat(1, 2), 64), " ", acos(bigrat(1, 2), 64), " ", atan2(bigrat(1), bigrat(-1), 64))
    println(sinh(bigrat(1), 64), " ", cosh(bigrat(1), 64), " ", tanh(bigrat(1), 64))
    println(asinh(bigrat(1), 64), " ", acosh(bigrat(2), 64), " ", atanh(bigrat(1, 2), 64), " ", pow(bigrat(2), bigrat(1, 2), 64))
    // a precision is of bits after the point: few, none, and below none
    println(bigrat.pi(0), " ", bigrat.pi(1), " ", bigrat.pi(4), " ", bigrat.pi(8), " ", exp(bigrat(1), 0), " ", exp(bigrat(1), -5), " ", exp(bigrat(10), 0))
    // a large argument, a small one, a large result
    println(sin(bigrat(10n ** 20), 64), " ", sin(bigrat(1n, 10n ** 30), 100), " ", exp(bigrat(100), 0), " ", exp(bigrat(-100), 64))
    println(tan(bigrat(11, 7), 32), " ", pow(bigrat(3, 2), bigrat(100, 7), 16), " ", pow(bigrat(2), bigrat(10), 0), " ", pow(bigrat(-3), bigrat(3), 0), " ", pow(bigrat(2), bigrat(-2), 4))
    // with no precision it is bigrat.precision; each is a method too
    let r = bigrat(1, 3)
    println(bigrat.precision, " ", exp(r) == exp(r, 128), " ", r.log() == log(r, 128), " ", bigrat.pi() == bigrat.pi(128), " ", sqrt(r).den == 1n << 128)
    println(r.exp(16), " ", r.sin(16), " ", r.atan2(bigrat(1), 16), " ", r.pow(bigrat(1, 2), 16), " ", r.sqrt(16), " ", r.cosh(16), " ", r.atanh(16))
    println(r.pow(r, 16), " ", r.atan2(r, 16), " ", r)   // a method is lent its other operand, which is still r's
    // what they are of each other, to 120 bits of 128
    let s = sin(r)
    let c = cos(r)
    println(near(s * s + c * c, bigrat(1), 120), " ", near(exp(log(r)), r, 120), " ", near(tan(atan(r)), r, 120), " ", near(sqrt(r) * sqrt(r), r, 120), " ",
            near(atan(bigrat(1)) * 4, bigrat.pi(), 120), " ", near(cosh(r) * cosh(r) - sinh(r) * sinh(r), bigrat(1), 120), " ", near(pow(r, r), exp(r * log(r)), 120))
    // an infinity and a NaN, as a float's functions give them
    let nan = bigrat(0, 0)
    let inf = bigrat(1, 0)
    let ninf = bigrat(-1, 0)
    println(sqrt(bigrat(-1)), " ", sqrt(inf), " ", sqrt(nan), " ", exp(inf), " ", exp(ninf), " ", exp(nan))
    println(log(bigrat(0)), " ", log(bigrat(-2)), " ", log(inf))
    println(sin(inf), " ", cos(nan), " ", tan(ninf), " ", atan(inf, 8), " ", atan(ninf, 8), " ", atan2(inf, inf, 8), " ", atan2(bigrat(0), bigrat(0)))
    println(asin(bigrat(2)), " ", acos(bigrat(-2)), " ", atanh(bigrat(1)), " ", atanh(bigrat(-1)), " ", atanh(bigrat(3)), " ", acosh(bigrat(1, 2)))
    println(sinh(inf), " ", sinh(ninf), " ", cosh(ninf), " ", tanh(inf), " ", tanh(ninf), " ", asinh(ninf), " ", acosh(inf))
    println(pow(bigrat(0), bigrat(0)), " ", pow(bigrat(0), bigrat(2)), " ", pow(bigrat(0), bigrat(-1)), " ", pow(bigrat(-8), bigrat(1, 3)), " ", pow(bigrat(2), inf), " ", pow(bigrat(1, 2), inf), " ", pow(bigrat(2), ninf), " ", pow(inf, bigrat(-1)))
    // past what is reckoned, e^(2^32) and more, an infinity; far below, 0
    println(exp(bigrat(10000000000)), " ", exp(bigrat(-10000000000)), " ", sinh(bigrat(-10000000000)), " ", pow(bigrat(10), bigrat(100000000000, 3)))
    // math's own are as they were
    println(sin(0.5) < 0.48, " ", sqrt(16.0), " ", abs(c64(3.0, 4.0)))
    return 0
}
// out: 3141592653589793238462643383279502884197169399375105820974944n
// out: 2718281828459045235360287471352662497757247093699959574966967n
// out: 1414213562373095048801688724209698078569671875376948073176679n
// out: 693147180559945309417232121458176568075500134360255254120680n
// out: (57952155664616982739n/18446744073709551616n) (26087635650665564425n/18446744073709551616n)
// out: (50143449209799256683n/18446744073709551616n) (10618799479599967255n/4611686018427387904n)
// out: (15522399902203605025n/18446744073709551616n) (4983409179392355913n/9223372036854775808n) (28729101715127294859n/18446744073709551616n)
// out: (14488038916154245685n/18446744073709551616n) (9658692610769497123n/18446744073709551616n) (9658692610769497123n/9223372036854775808n) (21732058374231368527n/9223372036854775808n)
// out: (2709829456783148213n/2305843009213693952n) (28464813555534070979n/18446744073709551616n) (3512233120737208491n/4611686018427387904n)
// out: (16258472993076885089n/18446744073709551616n) (12146792640211428575n/9223372036854775808n) (10132909862646469819n/18446744073709551616n) (26087635650665564425n/18446744073709551616n)
// out: (3n/1n) (3n/1n) (25n/8n) (201n/64n) (3n/1n) (3n/1n) (22026n/1n)
// out: (-5951392661265007055n/9223372036854775808n) (1n/1267650600228229401496703205376n) (26881171418161354484126255515800135873611119n/1n) (0n/1n)
// out: (-1698300979937n/1073741824n) (21481735n/65536n) (1024n/1n) (-27n/1n) (1n/4n)
// out: 128 true true true true
// out: (91463n/65536n) (21443n/65536n) (10543n/32768n) (37837n/65536n) (37837n/65536n) (69211n/65536n) (22713n/65536n)
// out: (355n/512n) (3217n/4096n) (1n/3n)
// out: true true true true true true true
// out: (0n/0n) (1n/0n) (0n/0n) (1n/0n) (0n/1n) (0n/0n)
// out: (-1n/0n) (0n/0n) (1n/0n)
// out: (0n/0n) (0n/0n) (0n/0n) (201n/128n) (-201n/128n) (201n/256n) (0n/1n)
// out: (0n/0n) (0n/0n) (1n/0n) (-1n/0n) (0n/0n) (0n/0n)
// out: (1n/0n) (-1n/0n) (1n/0n) (1n/1n) (-1n/1n) (-1n/0n) (1n/0n)
// out: (1n/1n) (0n/1n) (1n/0n) (0n/0n) (1n/0n) (0n/1n) (0n/1n) (0n/1n)
// out: (1n/0n) (0n/1n) (-1n/0n) (1n/0n)
// out: true 4.0 5.0
