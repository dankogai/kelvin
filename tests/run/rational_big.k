// bigrat (#540): a rational of two BigInts, a fraction of any precision,
// which every result fits; 1n.over(3n) and 1n.over(3) make one; rat64's
// arithmetic, with a BigInt or an integer too, its comparisons, its
// infinities and NaN; its text (1n/3n), its parts as a BigInt shows;
// .f64 of any size; bigrat(r) of a rational of integers, and rat64(r) of
// a bigrat, a NaN where it does not fit
#import <Rational>
let main():int32 {
    let a = 1n.over(3n)
    let b = 1n.over(6)
    println(a, " ", b, " ", a + b, " ", a - b, " ", a * b, " ", a / b, " ", -a, " ", a.typename)
    var acc = bigrat(0)
    for i in 1...30 { acc = acc + 1n.over(i) }
    println(acc, " ", acc.f64, " ", a.f64, " ", a.hex, " ", (-10n).over(4).oct, " ", 5n.over(2).bin)
    let inf = 1n.over(0)
    let nan = 0n.over(0n)
    println(inf, " ", (-5n).over(0), " ", nan, " ", -inf, " ", inf.f64, " ", (-inf).f64, " ", nan.f64)
    println(inf + a, " ", inf + inf, " ", inf - inf, " ", inf * bigrat(0), " ", a / bigrat(0), " ", a / inf, " ", nan + a)
    println(a == 2n.over(6n), " ", a != b, " ", a < b, " ", b < a, " ", a >= b, " ", nan == nan, " ", nan != nan, " ", -inf < inf)
    println(a.isNaN, " ", nan.isNaN, " ", inf.isInfinite, " ", a.isFinite, " ", a + 1, " ", 2 * a, " ", 1n / a, " ", a - 5n)
    let big = (2n ** 200).over(3n ** 100)
    println(big, " ", big.f64, " ", (big * big * big * big * big * big * big * big * big * big).f64, " ", (1n.over(10n ** 400)).f64, " ", (10n ** 400).over(1).f64)
    println(bigrat(1, 3), " ", bigrat(6n, 4n), " ", bigrat(7n), " ", bigrat(rat64(22, 7)), " ", bigrat(rat8(1, 2)), " ", rat64(a))
    println(rat8(big), " ", rat64(big), " ", rat16(a), " ", rat32(1n.over(70000)))
    println(1.over(3) == rat64(a), " ", `${a} and ${b}`, " ", a.cstr, " ", $[a.f64, b.f64], " ", a.num, " ", a.den)
    return 0
}
// out: (1n/3n) (1n/6n) (1n/2n) (1n/6n) (1n/18n) (2n/1n) (-1n/3n) bigrat
// out: (9304682830147n/2329089562800n) 3.994987130920391 0.33333333333333331 (+0x1n/+0x3n) (-0o5n/+0o2n) (+0b101n/+0b10n)
// out: (1n/0n) (-1n/0n) (0n/0n) (-1n/0n) inf -inf nan
// out: (1n/0n) (1n/0n) (0n/0n) (0n/0n) (1n/0n) (0n/1n) (0n/0n)
// out: true true false true true false true true
// out: false true true true (4n/3n) (2n/3n) (3n/1n) (-14n/3n)
// out: (1606938044258990275541962092341162602522202993782792835301376n/515377520732011331036461129765621272702107522001n) 3117982410207.9419 8.6843358037744105e+124 0.0 inf
// out: (1n/3n) (3n/2n) (7n/1n) (22n/7n) (1n/2n) (1/3)
// out: (0/0) (0/0) (1/3) (1/70000)
// out: true (1n/3n) and (1n/6n) (1n/3n) [0.33333333333333331, 0.16666666666666666] 1n 3n
