// BigInt (#507), the prelude's: integers of any size, two's complement in
// u64 limbs, with + - * / % (truncated toward zero, as Kelvin's integers),
// comparisons, & | ~ << >> and unary - and ~, an i64 on either side; text
// read as i64(s) reads it, in any base from 2 to 36; its text is its
// literal, 123n, and .hex, .oct and .bin are +0xffn, +0o377n, -0b101n,
// each read back as it (#509)
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
    println(u.isZero, " ", BigInt(0).isZero, " ", BigInt(-3).isNegative, " ", BigInt(-3).sign, " ", BigInt(0).sign, " ", BigInt(-3).abs, " ", (-u).abs)
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
    var t = $`${-f}`
    var h = (-f).hex
    var o = BigInt(255).oct
    var b2 = BigInt(-5).bin
    println(BigInt(&t) == -f, " ", h, " ", BigInt(&h, 16) == -f, " ", o, " ", BigInt(&o, 8), " ", b2, " ", BigInt(&b2, 2), " ", BigInt(0).hex)
    return 0
}
// out: 30414093201713378043612608166064768844377641568960512000000000000n 49eebc961ed279b02b1ef4f28d19a84f5973a1d2c7800000000000 4q7eyp9zizmtqt0648txt4fm720cc1s00000000000
// out: 280571172992510140037611932413038677189525n 349361645n
// out: 1606938044258990275541962092341162602522202993782792835301376n 1024n -2n 200 -1n -1606938044258990275541962092341162602522202993782792835301377n
// out: -3n -1n -3n 1n 250n 6n 15n
// out: -42n 255n 255n 1295n 0n 5n
// out: 18446744073709551616n 0 0 18446744073709551615 5 18446744073709551615 1.8446744073709552e+19
// out: 9223372036854775808n 18446744073709551615n -9223372036854775809n
// out: false true true -1 0 3n 18446744073709551616n
// out: true true true false true false
// out: 393n [1n, -2n] <30414093201713378043612608166064768844377641568960512000000000000n> 62
// out: true -0x49eebc961ed279b02b1ef4f28d19a84f5973a1d2c7800000000000n true +0o377n 255n -0b101n -5n +0x0n
