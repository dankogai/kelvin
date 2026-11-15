// an infinity divided by a negative number is the other infinity (#574):
// BigRat(1, 0) / BigRat(-2) is (-1n/0n), where it was (1n/0n), the sign
// of the divisor lost in a denominator of 0, which has none; so of a
// rat64, a rat32, a rat16 and a rat8, by a rational, a BigInt or an
// integer, and of r /= d; by a positive number it is as it was, and so
// is every other quotient: by an infinity a NaN, by 0 itself, and a
// finite number by any
#import <math>
#import <Rational>
let main():int32 {
    let inf = BigRat(1, 0)
    let ninf = BigRat(-1, 0)
    println(inf / BigRat(-2), " ", ninf / BigRat(-2), " ", inf / BigRat(2), " ", ninf / BigRat(2))
    println(inf / -2, " ", inf / -2n, " ", ninf / -2, " ", ninf / -2n, " ", inf / BigRat(-1, 3), " ", inf / ninf.num)
    println(inf / inf, " ", inf / ninf, " ", ninf / ninf, " ", inf / BigRat(0), " ", ninf / BigRat(0), " ", BigRat(0, 0) / BigRat(-2))
    println(BigRat(3) / ninf, " ", BigRat(0) / BigRat(-2), " ", BigRat(1, 2) / BigRat(-3, 4), " ", BigRat(-1, 2) / BigRat(-3, 4), " ", 1 / BigRat(-2), " ", BigRat(-3) / BigRat(0))
    var r = BigRat(1, 0)
    r /= BigRat(-3)
    println(r, " ", r.f64, " ", r < BigRat(0), " ", r == ninf, " ", r.isInfinite, " ", (r / -1).f64)
    println(rat64(1, 0) / rat64(-2), " ", rat64(-1, 0) / rat64(-2), " ", rat64(1, 0) / -2, " ", rat64(1, 0) / rat64(2), " ", 1.over(0) / (-1).over(3))
    println(rat32(1, 0) / rat32(-2), " ", rat16(1, 0) / rat16(-2), " ", rat8(1, 0) / rat8(-2), " ", rat8(-1, 0) / rat8(-2), " ", rat8(1, 0) / rat8(-128))
    println(rat64(1, 0) / rat64(-9223372036854775807 - 1), " ", rat64(1, 0) / rat64(1, 0), " ", rat64(1, 0) / rat64(-1, 0), " ", rat64(1, 0) / rat64(0))
    println(rat64(1, 2) / rat64(-3, 4), " ", rat64(-1, 2) / rat64(-3, 4), " ", 1 / rat64(-2), " ", rat8(1) / rat8(-128), " ", rat8(-128) / rat8(-1), " ", rat64(3) / rat64(-1, 0))
    // a CBR by a negative BigRat, a BigInt and an i64 has its sign too, as by a CBR (#572)
    println(CBR(inf.copy(), BigRat(0)) / BigRat(-2), " ", CBR(inf.copy(), BigRat(0)) / -2, " ", CBR(BigRat(0), inf.copy()) / -2n, " ", CBR(inf.copy(), BigRat(0)) / CBR(-2))
    return 0
}
// out: (-1n/0n) (1n/0n) (1n/0n) (-1n/0n)
// out: (-1n/0n) (-1n/0n) (1n/0n) (1n/0n) (-1n/0n) (-1n/0n)
// out: (0n/0n) (0n/0n) (0n/0n) (1n/0n) (-1n/0n) (0n/0n)
// out: (0n/1n) (0n/1n) (-2n/3n) (2n/3n) (-1n/2n) (-1n/0n)
// out: (-1n/0n) -inf true true true inf
// out: (-1/0) (1/0) (-1/0) (1/0) (-1/0)
// out: (-1/0) (-1/0) (-1/0) (1/0) (-1/0)
// out: (-1/0) (0/0) (0/0) (1/0)
// out: (-2/3) (2/3) (-1/2) (0/0) (0/0) (0/1)
// out: ((-1n/0n)+(0n/1n).i) ((-1n/0n)+(0n/1n).i) ((0n/1n)+(-1n/0n).i) ((-1n/0n)+(0n/1n).i)
