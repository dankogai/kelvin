// BigInt's algorithms on large values (#518): text divided and conquered,
// Lehmer's gcd, isqrt with its precision doubled, powers with their
// factors of 2 shifted in, Karatsuba's squares and products, Knuth's
// division; each checked against Python's
let main():int32 {
    let p = 2n ** 100000
    let s = p.text(10)
    println(s.count, " ", p % 1000000007, " ", BigInt(&s) == p)
    let t = (3n ** 20000).text(36)
    println(t.count, " ", BigInt(&t, 36) == 3n ** 20000)
    let x = 7n ** 1183
    let y = 3n ** 2093
    let k = 2n ** 300 * 5n ** 77 + 1
    println(x.gcd(y), " ", (x * k).gcd(y * k) == k, " ", (x * 6).gcd(y * 4))
    let n = 10n ** 2001 + 12345
    let r = n.isqrt()
    println(r % 1000000007, " ", r * r <= n, " ", (r + 1) * (r + 1) > n, " ", (n * n).isqrt() == n, " ", (n * n - 1).isqrt() == n - 1)
    println(12n ** 1000 == 3n ** 1000 * 2n ** 2000, " ", (-6n) ** 333 % 1000000007, " ", 2n ** 5 ** 3 == 2n ** 125)
    let a = 3n ** 30000 + 1
    let b = 5n ** 20000 - 1
    println(a * a == a ** 2, " ", (a * b) % 1000000007, " ", (a * a) % 998244353)
    let q = a * a / b
    let m = a * a % b
    println(q * b + m == a * a, " ", m < b, " ", q % 1000000007, " ", (-(a * a) / b) == -q, " ", (-(a * a)) % b == -m)
    return 0
}
// out: 30103 607723520n true
// out: 6132 true
// out: 1n true 6n
// out: 507873625n true true true true
// out: true -321391156n true
// out: true 709356171n 952255703n
// out: true true 725646593n true true
