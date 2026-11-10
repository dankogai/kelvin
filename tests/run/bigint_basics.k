// BigInt (#507), the prelude's: integers of any size, two's complement in
// u64 limbs, with + - * / % (truncated toward zero, as Kelvin's integers),
// comparisons, & | ~ << >> and unary - and ~, an i64 on either side; text
// read as i64(s) reads it, in any base from 2 to 36
let factorial(n:i64):BigInt {
    var f = BigInt(1)
    for i in 2...n { f *= i }
    return f
}
let fibonacci(n:i64):BigInt {
    var a = BigInt(0)
    var b = BigInt(1)
    for i in 0..<n {
        let c = a + b
        a = b.copy()
        b = c.copy()
    }
    return a
}
let main():int32 {
    let f = factorial(50)
    println(f, " ", f.text(16), " ", f.text(36))
    println(fibonacci(200), " ", fibonacci(200) % 1000000007)
    let big = BigInt(1) << 200
    println(big, " ", big >> 190, " ", -big >> 199, " ", (big - 1).text(2).count, " ", ~BigInt(0), " ", ~big)
    println(BigInt(-7) / 2, " ", BigInt(-7) % 2, " ", 7 / BigInt(-2), " ", BigInt(7) % -2, " ", BigInt(-6) & 0xff, " ", BigInt(5) ~ 3, " ", 12 | BigInt(3))
    println(BigInt("  -0042abc"), " ", BigInt("ff", 16), " ", BigInt("0xFF", 16), " ", BigInt("zz", 36), " ", BigInt("x"), " ", BigInt("101", 2))
    let s = $"18446744073709551616"
    let u = BigInt(&s)
    println(u, " ", u.i64, " ", u.u64, " ", (u - 1).u64, " ", (u + 5).i64, " ", BigInt(-1).u64, " ", u.f64)
    println(BigInt(9223372036854775807) + 1, " ", BigInt(18446744073709551615 as u64), " ", BigInt(-9223372036854775807 - 1) - 1)
    println(u.isZero, " ", BigInt(0).isZero, " ", BigInt(-3).isNegative, " ", BigInt(-3).signum, " ", BigInt(0).signum, " ", BigInt(-3).abs, " ", (-u).abs)
    println(u > 1, " ", 1 < u, " ", u == u, " ", u != u + 0, " ", BigInt(3) <= 3, " ", 4 >= BigInt(5))
    var x = BigInt(10)
    x += 5
    x -= BigInt(3)
    x <<= 64
    x |= 1
    x %= 1000
    var xs:$[BigInt] = $[]
    xs.append(BigInt(1))
    xs.append(BigInt(-2))
    println(x, " ", xs, " ", `<${f}>`, " ", $`${big}`.count)
    return 0
}
// out: 30414093201713378043612608166064768844377641568960512000000000000 49eebc961ed279b02b1ef4f28d19a84f5973a1d2c7800000000000 4q7eyp9zizmtqt0648txt4fm720cc1s00000000000
// out: 280571172992510140037611932413038677189525 349361645
// out: 1606938044258990275541962092341162602522202993782792835301376 1024 -2 200 -1 -1606938044258990275541962092341162602522202993782792835301377
// out: -3 -1 -3 1 250 6 15
// out: -42 255 255 1295 0 5
// out: 18446744073709551616 0 0 18446744073709551615 5 18446744073709551615 1.8446744073709552e+19
// out: 9223372036854775808 18446744073709551615 -9223372036854775809
// out: false true true -1 0 3 18446744073709551616
// out: true true true false true false
// out: 393 [1, -2] <30414093201713378043612608166064768844377641568960512000000000000> 61
