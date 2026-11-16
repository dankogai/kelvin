// BigFloat, a floating-point number of any precision, with <BigFloat>
// (#576): a mantissa, a BigInt, times a power of 2. Every result, of its
// making and of + - * /, is rounded to BigFloat.precision significant
// bits, 128, which a program may set, to the nearest and the even one;
// x.round(precision) and x.round(precision, rule) round it to fewer, by
// one of six rules. It has a float's infinities and NaN and one 0;
// BigRat(x) is its value exactly and x.f64 the nearest f64
#import <BigFloat>
let main():int32 {
    // a mantissa that is odd, and an exponent
    let six = BigFloat(6)
    let tenth = BigFloat(0.1)
    println(six.mantissa, " ", six.exponent, " ", BigRat(six), " ", BigRat(BigFloat(-40)), " ", BigRat(tenth), " ", tenth.f64 == 0.1)
    // rounded to 128 bits, as an f64 is to 53
    let third = BigFloat(1) / 3
    println(third.mantissa.bits.count - 1, " ", third.exponent, " ", third.f64, " ", (third * 3).f64, " ", third * 3 == BigFloat(1), " ", BigRat(third) == 1n.over(3n))
    let big = BigInt(1) << 200
    println(BigFloat(big + 1) == BigFloat(big), " ", BigRat(BigFloat(big + 1, 256)) == BigRat(big + 1), " ", BigRat(BigFloat(7, 2)), " ", BigRat(BigFloat(0.1, 4)), " ", BigRat(BigFloat(1n.over(3n), 4)))
    // of a rational, and back
    let r = BigFloat(22n.over(7n))
    println(r.f64, " ", BigFloat(BigRat(r)) == r, " ", BigRat(BigFloat(3n.over(8n))), " ", BigRat(BigFloat(BigRat(1, 0))), " ", BigRat(BigFloat(BigRat(-1, 0))), " ", BigRat(BigFloat(BigRat(0, 0))))
    // x.round(precision), and by a rule: 1/3 is 0.0101...
    println(BigRat(third.round(8)), " ", BigRat(third.round(1)), " ", BigRat(third.round(2)), " ", BigRat(third.round(3)), " ", third.round(200) == third, " ", third.round(0) == third.round(1))
    println(BigRat(third.round(4, BigFloat.up)), " ", BigRat(third.round(4, BigFloat.down)), " ", BigRat(third.round(4, BigFloat.towardZero)), " ", BigRat(third.round(4, BigFloat.awayFromZero)), " ", BigRat(third.round(4, BigFloat.nearestEven)), " ", BigRat(third.round(4, BigFloat.nearestAway)))
    let minus = -third
    println(BigRat(minus.round(4, BigFloat.up)), " ", BigRat(minus.round(4, BigFloat.down)), " ", BigRat(minus.round(4, BigFloat.towardZero)), " ", BigRat(minus.round(4, BigFloat.awayFromZero)), " ", BigRat(minus.round(4)))
    // of two as near: 5/8 and 7/8 at 2 bits, 0.101 and 0.111
    let five = BigFloat(5) / 8
    let seven = BigFloat(7) / 8
    println(BigRat(five.round(2)), " ", BigRat(five.round(2, BigFloat.nearestAway)), " ", BigRat(seven.round(2)), " ", BigRat(seven.round(2, BigFloat.nearestAway)), " ", BigRat((-five).round(2)), " ", BigRat((-five).round(2, BigFloat.nearestAway)))
    // + - * /, with a BigInt and an integer on either side
    let x = BigFloat(1.5)
    let y = BigFloat(0.25)
    println(BigRat(x + y), " ", BigRat(x - y), " ", BigRat(x * y), " ", BigRat(x / y), " ", BigRat(-x), " ", BigRat(+x), " ", BigRat(y - x))
    println(BigRat(x + 1), " ", BigRat(1 - x), " ", BigRat(x * 3n), " ", BigRat(3n / x), " ", BigRat(2 * x), " ", BigRat(x / 4), " ", BigRat(1n + y))
    var z = x.copy()
    z += y
    z *= z
    z -= 1
    z /= 2
    println(BigRat(z), " ", z.f64, " ", z > x, " ", z < x, " ", z == z, " ", x != y, " ", y <= x, " ", y >= x)
    // one far below the last bit is lost, but for its side
    let small = BigFloat(1) / (BigInt(1) << 1000)
    println(BigFloat(1) + small == BigFloat(1), " ", BigFloat(1) - small == BigFloat(1), " ", small > BigFloat(0), " ", (small * small).exponent, " ", small + small == small * 2, " ", BigFloat(1) + small * (BigInt(1) << 873) > BigFloat(1))
    // it never grows: a product of two of 128 bits has 128
    var w = BigFloat(1) / 3
    for i in 0..<200 { w = w * w / 2 + third }           // to 1 less the square root of a third
    println(w.mantissa.bits.count - 1 <= 128, " ", w.f64, " ", w == w * w / 2 + third)
    // another precision
    BigFloat.precision = 8
    println(BigRat(BigFloat(1) / 3), " ", BigRat(BigFloat(1000)), " ", BigRat(BigFloat(1001)), " ", BigRat(BigFloat(255) + 1), " ", BigRat(BigFloat(257) * 3), " ", BigFloat.precision)
    BigFloat.precision = 256
    let wide = BigFloat(1) / 3
    println(wide.mantissa.bits.count - 1, " ", wide == third, " ", wide.round(128) == third, " ", BigRat(wide - third).den == BigInt(1) << 257)
    BigFloat.precision = 128
    // infinities and a NaN, as a float's; one 0
    let inf = BigFloat(1) / 0
    let nan = BigFloat(0) / 0
    println(inf.isInfinite, " ", inf.isFinite, " ", nan.isNaN, " ", x.isFinite, " ", inf.f64, " ", (-inf).f64, " ", nan.f64, " ", BigFloat(f64.infinity) == inf)
    println((inf + 1).f64, " ", (inf - inf).isNaN, " ", (inf * 0).isNaN, " ", (inf * -2).f64, " ", (inf / -2).f64, " ", (-inf / -2).f64, " ", (inf / inf).isNaN, " ", (inf / 0).f64)
    println(BigRat(1 / inf), " ", (-1 / BigFloat(0)).f64, " ", BigFloat(f64.nan).isNaN, " ", BigFloat(-f64.infinity) == -inf)
    println(nan == nan, " ", nan != nan, " ", nan < x, " ", x < nan, " ", nan >= nan, " ", -inf < inf, " ", x < inf, " ", -inf < x)
    println(inf <= inf, " ", inf == inf, " ", inf > x, " ", inf == -inf)
    println(BigRat(BigFloat(0)), " ", BigFloat(0).exponent, " ", BigFloat(-0.0) == BigFloat(0), " ", (BigFloat(0) * -1).f64, " ", BigRat(x - x), " ", inf.round(8).f64, " ", nan.round(8).isNaN)
    // the nearest f64, past its range an infinity and below it 0
    let tiny = BigFloat(5.0e-324)
    println(tiny.f64, " ", (tiny / 2).f64, " ", (tiny * 3 / 2).f64, " ", (tiny * 3 / 4).f64, " ", (BigFloat(1.7976931348623157e308) * 2).f64, " ", (BigFloat(1.7976931348623157e308) * 2).isFinite, " ", BigFloat(-2.5).f64)
    return 0
}
// out: 3n 1 (6n/1n) (-40n/1n) (3602879701896397n/36028797018963968n) true
// out: 128 -129 0.33333333333333331 1.0 true false
// out: true true (8n/1n) (13n/128n) (11n/32n)
// out: 3.1428571428571428 true (3n/8n) (1n/0n) (-1n/0n) (0n/0n)
// out: (171n/512n) (1n/4n) (3n/8n) (5n/16n) true true
// out: (11n/32n) (5n/16n) (5n/16n) (11n/32n) (11n/32n) (11n/32n)
// out: (-5n/16n) (-11n/32n) (-5n/16n) (-11n/32n) (-11n/32n)
// out: (1n/2n) (3n/4n) (1n/1n) (1n/1n) (-1n/2n) (-3n/4n)
// out: (7n/4n) (5n/4n) (3n/8n) (6n/1n) (-3n/2n) (3n/2n) (-5n/4n)
// out: (5n/2n) (-1n/2n) (9n/2n) (2n/1n) (3n/1n) (3n/8n) (5n/4n)
// out: (33n/32n) 1.03125 false true true true true false
// out: true true true -2000 true true
// out: true 0.42264973081037421 true
// out: (171n/512n) (1000n/1n) (1000n/1n) (256n/1n) (768n/1n) 8
// out: 256 false true true
// out: true false true true inf -inf nan true
// out: inf true true -inf -inf inf true inf
// out: (0n/1n) -inf true true
// out: false true false false false true true true
// out: true true true false
// out: (0n/1n) 0 true 0.0 (0n/1n) inf true
// out: 4.9406564584124654e-324 0.0 9.8813129168249309e-324 4.9406564584124654e-324 inf true -2.5
