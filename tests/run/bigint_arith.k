// the rest of BigInt's arithmetic (#511): b ** e of an i64 or a BigInt
// exponent, b.pow(e), Python's pow(b, e, m) in both forms, gcd, lcm, isqrt,
// .sign, b.exactI64 and b.exactU64, an i64? and a u64?; C's pow of
// doubles stays beside the BigInt's
let main():int32 {
    let a = 2n ** 127 - 1
    let m = 1000000007n
    println(a, " ", 3n ** 4n, " ", (-2n) ** 63, " ", a.pow(2) == a * a, " ", 10n ** 0)
    println(pow(a, 5, m), " ", a.pow(5, m), " ", pow(a, 5n, m), " ", pow(7, a, m), " ", pow(a, 2, -1000000007), " ", a, " ", m)
    println(pow(3n, -1, 7), " ", pow(-3n, 3, 7), " ", pow(2, 10n, 1000), " ", pow(2.0, 0.5))
    println(12n.gcd(18), " ", (-12n).gcd(18n), " ", 0n.gcd(0), " ", 12n.lcm(18), " ", (-4n).lcm(6n), " ", 0n.lcm(5))
    println(99n.isqrt(), " ", 100n.isqrt(), " ", (10n ** 40 + 1).isqrt(), " ", 0n.isqrt(), " ", (2n ** 200).isqrt() == 2n ** 100)
    println((-7n).sign, " ", 0n.sign, " ", 7n.sign)
    println(5n.exactI64, " ", (2n ** 63).exactI64, " ", (-(2n ** 63)).exactI64, " ", (2n ** 63).exactU64, " ", (2n ** 64).exactU64, " ", (-1n).exactU64)
    return 0
}
// out: 170141183460469231731687303715884105727n 81n -9223372036854775808n true 1n
// out: 207163927n 207163927n 207163927n 537694521n -581420963n 170141183460469231731687303715884105727n 1000000007n
// out: 5n 1n 24n 1.4142135623730951
// out: 6n 6n 0n 36n 12n 0n
// out: 9n 10n 100000000000000000000n 0n true
// out: -1 0 1
// out: some(5) none some(-9223372036854775808) some(9223372036854775808) none none
