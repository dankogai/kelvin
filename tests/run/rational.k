// #import <Rational> (#538): rat64, a numerator over a denominator, two
// i64s in lowest terms, the denominator 0 or more; n.over(d) makes one;
// + - * / and unary -, of two and with an integer; == != < <= > >=; its
// text (num/den), .hex, .oct and .bin (num.hex/den.hex); .f64
#import <Rational>
let main():int32 {
    let a = 1.over(3)
    let b = 1.over(6)
    println(a, " ", b, " ", a + b, " ", a - b, " ", a * b, " ", a / b, " ", -a)
    println(2.over(4), " ", 3.over(-6), " ", (-4).over(-8), " ", 0.over(5), " ", rat64(6, 4), " ", rat64(5))
    println(a.hex, " ", (-10).over(4).oct, " ", 5.over(2).bin, " ", a.f64, " ", 3.over(4).f64)
    println(a == 2.over(6), " ", a != b, " ", a < b, " ", b < a, " ", a >= b, " ", a <= a, " ", b > a)
    println(a + 1, " ", 2 * a, " ", 1 / a, " ", a - 1, " ", a * 3, " ", a / 2)
    var acc = 0.over(1)
    for i in 1...10 { acc += 1.over(i * (i + 1)) }
    let n:i64 = 22
    println(acc, " ", `${a} and ${b}`, " ", a.cstr, " ", $[a, b], " ", a.typename, " ", n.over(7), " ", a.num, " ", a.den)
    println(a.isNaN, " ", a.isInfinite, " ", a.isFinite)
    return 0
}
// out: (1/3) (1/6) (1/2) (1/6) (1/18) (2/1) (-1/3)
// out: (1/2) (-1/2) (1/2) (0/1) (3/2) (5/1)
// out: (+0x1/+0x3) (-0o5/+0o2) (+0b101/+0b10) 0.33333333333333331 0.75
// out: true true false true true true false
// out: (4/3) (2/3) (3/1) (-2/3) (1/1) (1/6)
// out: (10/11) (1/3) and (1/6) (1/3) [(1/3), (1/6)] rat64 (22/7) 1 3
// out: false false true
