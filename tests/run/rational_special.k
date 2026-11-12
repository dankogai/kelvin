// a rational is treated a little like a float (#538): a denominator of 0
// is no division by zero but an infinity, (1/0) and (-1/0), and (0/0) is
// a NaN, which equals nothing and has no order; a result whose parts do
// not fit an i64 is a NaN too
#import <Rational>
let main():int32 {
    let a = 1.over(3)
    let inf = 1.over(0)
    let nan = 0.over(0)
    println(inf, " ", (-7).over(0), " ", nan, " ", -inf, " ", inf.f64, " ", (-inf).f64, " ", nan.f64)
    println(inf + a, " ", inf + inf, " ", inf - inf, " ", inf * 0.over(1), " ", inf * -a, " ", a / 0.over(1), " ", a / inf, " ", nan + a)
    println(a / 0, " ", 0.over(1) / 0, " ", -a / 0, " ", inf / inf, " ", 1 / inf)
    println(nan == nan, " ", nan != nan, " ", nan < a, " ", a < nan, " ", nan >= nan)
    println(-inf < inf, " ", inf <= inf, " ", a < inf, " ", -inf < a, " ", inf < a)
    println(inf == inf, " ", inf == -inf, " ", nan.isNaN, " ", inf.isNaN, " ", inf.isInfinite, " ", inf.isFinite, " ", nan.isFinite)
    let big = 9223372036854775807.over(1)
    let least = (-9223372036854775807 - 1).over(1)
    println(big, " ", big + 1, " ", big * big, " ", a + 1.over(5000000000000000000), " ", least, " ", -least, " ", (-9223372036854775807 - 1).over(-1))
    println(big - big, " ", big / big, " ", 1.over(9223372036854775807) * 1.over(2), " ", (big + 1).isNaN)
    return 0
}
// out: (1/0) (-1/0) (0/0) (-1/0) inf -inf nan
// out: (1/0) (1/0) (0/0) (0/0) (-1/0) (1/0) (0/1) (0/0)
// out: (1/0) (0/0) (-1/0) (0/0) (0/1)
// out: false true false false false
// out: true true true true false
// out: true false true false true false false
// out: (9223372036854775807/1) (0/0) (0/0) (0/0) (-9223372036854775808/1) (0/0) (0/0)
// out: (0/1) (1/1) (0/0) true
