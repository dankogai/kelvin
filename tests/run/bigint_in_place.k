// x += y, x -= y and x *= n of a BigInt in place (#518), the limbs x holds
// reused: of an i64 and of a BigInt, s += s of s itself, across the signs
// and past a limb's top
let main():int32 {
    var s = BigInt(0)
    for i in 1...100000 { s += i }
    var f = BigInt(1)
    for i in 2...30 { f *= i }
    println(s, " ", f)
    var t = 2n ** 64 - 1
    t += 1
    let u = t.copy()
    t -= 1
    println(t, " ", u, " ", t.hex)
    var n = BigInt(5)
    n -= 12
    n *= -3
    n -= 2n ** 100
    n += n
    println(n)
    var m = -(2n ** 130)
    m += 2n ** 130
    m -= 1
    println(m)
    m *= 0
    println(m, " ", m.isZero)
    var g = 3n ** 50
    g *= 9223372036854775807
    g += -(3n ** 50 * 9223372036854775807)
    var h = -(2n ** 63)
    h -= 1
    h *= 2
    println(g, " ", h)
    return 0
}
// out: 5000050000n 265252859812191058636308480000000n
// out: 18446744073709551615n 18446744073709551616n +0xffffffffffffffffn
// out: -2535301200456458802993406410710n
// out: -1n
// out: 0n true
// out: 0n -18446744073709551618n
