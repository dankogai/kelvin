// modules/Prime.k - primality of every integer type (#668): n.isPrime,
// n.nextPrime and n.prevPrime of an integer n, and N.primes, an Iterator of
// N's primes, of each integer type N and of BigInt, as swift-bignum has them.
//
//     #import <Prime>
//     println(97.isPrime, " ", 100.nextPrime, " ", 100.prevPrime)   // true 101 some(97)
//     for p in u8.primes { print(p, " ") }           // 2 3 5 ... 251, then none
//     println(((1n << 127) - 1).isPrime)              // true, by Lucas-Lehmer
//
// A type of 64 bits or fewer is tested exactly: small primes divide it, then
// Miller-Rabin of the seven bases Jim Sinclair found, which no composite below
// 2^64 passes. An i128, a u128 and a BigInt are tested as swift-bignum's
// Primality.swift tests them: below 2^64 as above; a Mersenne number,
// 2^p - 1, by Lucas-Lehmer; below 3317044064679887385961981 (OEIS A014233)
// by Miller-Rabin of the primes 2 to 41 as bases, exactly; past it by
// Baillie-PSW, Miller-Rabin of base 2 and a Lucas test of Selfridge's
// parameters, which no composite is known to pass, and n.isSurelyPrime says
// that it is only probable. n.isPrime is always a bool: true there too.
//
// BigInt.generatePrime(bits) (#672) is a random prime of that many bits, as
// OpenSSL's BN_generate_prime_ex makes one: a random number of the system's
// CSPRNG with its top two bits set, sieved by small primes, then Baillie-PSW
// and 64 rounds of Miller-Rabin of random bases, 128 past 2048 bits.

#import <stdio.h> as C
#import <stdlib.h> as C

// a check that failed: its reason on stderr, and the program ends with
// status 1, or aborts where KELVIN_ABORT is set, as the runtime's checks
// do (#174)
let prime_fail(what:const String^):() {
    fflush(stdout)
    fputs("kelvin: ", stderr)
    fputs(what^.cstr, stderr)
    fputs("\n", stderr)
    if getenv("KELVIN_ABORT") != nowhere { abort() }
    exit(1)
}

// whether n is prime, and whether that is only probable: isProbable is true
// only of a true of Baillie-PSW past what is proven, an i128's, a u128's or
// a BigInt's past 3317044064679887385961981 that is no Mersenne number
struct Primality {
    isPrime: bool
    isProbable: bool
}

// ---------- 64 bits and fewer, exactly ----------

let prime_mulmod(a:u64, b:u64, m:u64):u64 { ((a as u128) * (b as u128) % (m as u128)) as u64 }

let prime_powmod(b:u64, e:u64, m:u64):u64 {
    var r:u64 = 1
    var x:u64 = b % m
    var k:u64 = e
    while k > 0 {
        if (k & 1) == 1 { r = prime_mulmod(r, x, m) }
        x = prime_mulmod(x, x, m)
        k >>= 1
    }
    return r
}

// n odd and above 2, n - 1 = d * 2^s with d odd: true where base a does not
// witness that n is composite
let prime_mr64(n:u64, a:u64, d:u64, s:i64):bool {
    let b:u64 = a % n
    if b == 0 { return true }
    var y:u64 = prime_powmod(b, d, n)
    if y == 1 || y == n - 1 { return true }
    var i:i64 = 1
    while i < s {
        y = prime_mulmod(y, y, n)
        if y == n - 1 { return true }
        if y == 1 { return false }
        i += 1
    }
    return false
}

// n is prime, exactly: the primes to 37 divide it, and then the seven bases
// of Jim Sinclair, which no composite below 2^64 passes
let prime_u64(n:u64):bool {
    if n < 2 { return false }
    let small:[u64](12) = [2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37]
    for i in 0..<12 {
        if n % small[i] == 0 { return n == small[i] }
    }
    if n < 1369 { return true }                     // 37 * 37: no factor is left
    var d:u64 = n - 1
    var s:i64 = 0
    while (d & 1) == 0 {
        d >>= 1
        s += 1
    }
    let bases:[u64](7) = [2, 325, 9375, 28178, 450775, 9780504, 1795265022]
    for i in 0..<7 {
        if !prime_mr64(n, bases[i], d, s) { return false }
    }
    return true
}

// the least prime above n and not above max, or 0 where there is none
let prime_after(n:u64, max:u64):u64 {
    if n < 2 { return max >= 2 ? 2 : 0 }
    if n >= max { return 0 }
    var u:u64 = n + 1
    if u > 2 && (u & 1) == 0 {
        if u == max { return 0 }
        u += 1
    }
    while true {
        if prime_u64(u) { return u }
        if max - u < 2 { return 0 }
        u += 2
    }
    return 0
}

// the greatest prime below n, or 0 where there is none, of n 2 and below
let prime_before(n:u64):u64 {
    if n <= 2 { return 0 }
    if n == 3 { return 2 }
    var u:u64 = n - 1
    if (u & 1) == 0 { u -= 1 }
    while !prime_u64(u) { u -= 2 }                 // 3 is one
    return u
}

// the least prime above n of a type whose greatest is max, which tn names;
// where none fits, the program ends
let prime_next(n:u64, max:u64, tn:cstr):u64 {
    let p:u64 = prime_after(n, max)
    if p == 0 {
        let m = $`${n}.nextPrime has no value: no prime above ${n} fits ${tn}`
        prime_fail(&m)
    }
    return p
}

// ---------- any size: swift-bignum's Primality.swift ----------

let prime_u64_max():BigInt { BigInt(0xffffffffffffffff as i128) }

// n odd and above 2: true where base a does not witness that n is composite
let prime_mr(n:lent BigInt, a:i64):bool {
    let b = BigInt(a) % n
    return prime_mr_base(n, b)
}

// n odd and above 2: true where base b, below n, does not witness that n is
// composite
let prime_mr_base(n:lent BigInt, b:lent BigInt):bool {
    if b.isZero { return true }
    let last = n - 1
    var d = n - 1
    var s:i64 = 0
    while (d & 1) == 0 {
        d = d >> 1
        s += 1
    }
    var y = pow(b, d, n)
    if y == 1 || y == last { return true }
    var i:i64 = 1
    while i < s {
        y = y * y % n
        if y == last { return true }
        if y == 1 { return false }
        i += 1
    }
    return false
}

// the Jacobi symbol (a/n), n odd and positive
let prime_jacobi(a:i64, n:lent BigInt):i64 {
    var m = n.copy()
    var k = BigInt(a < 0 ? 0 - a : a)
    var j:i64 = 1
    if a < 0 && m % 4 == 3 { j = 0 - j }
    while !k.isZero {
        while (k & 1) == 0 {
            k = k >> 1
            let m8 = m % 8
            if m8 == 3 || m8 == 5 { j = 0 - j }
        }
        let t = m.copy()
        m = k.copy()
        k = t.copy()
        if k % 4 == 3 && m % 4 == 3 { j = 0 - j }
        k = k % m
    }
    return m == 1 ? j : 0
}

// n odd and above 2: a Lucas probable prime of Selfridge's parameters, D the
// first of 5, -7, 9, -11, ... with (D/n) = -1, P = 1 and Q = (1 - D) / 4;
// U(n + 1) is 0 mod n
let prime_lucas(n:lent BigInt):bool {
    let r = n.isqrt()
    if r * r == n { return false }                 // a square has no such D
    var d:i64 = 0
    var i:i64 = 2
    while i <= 256 && d == 0 {
        let c:i64 = ((i & 1) == 0 ? 1 : 0 - 1) * (2 * i + 1)
        if prime_jacobi(c, n) == 0 - 1 { d = c }
        i += 1
    }
    if d == 0 { return false }
    let bd = BigInt(d)
    var q = (1 - bd) / 4
    var q2 = q * 2
    var u = BigInt(0)
    var v = BigInt(2)
    var u2 = BigInt(1)
    var v2 = BigInt(1)
    var h = (n + 1) / 2
    while h > 0 {
        u2 = u2 * v2 % n
        v2 = (v2 * v2 - q2) % n
        if (h & 1) == 1 {
            let t = u.copy()
            u = u * v2 + u2 * v
            if (u & 1) != 0 { u += n }
            u = u / 2 % n
            v = v * v2 + u2 * t * bd
            if (v & 1) != 0 { v += n }
            v = v / 2 % n
        }
        q = q * q % n
        q2 = q * 2
        h = h >> 1
    }
    return u.isZero
}

// n = 2^p - 1, p an odd prime: Lucas-Lehmer, s -> s^2 - 2 from 4, p - 2
// times, each reduced by folding, as 2^p is 1 mod n
let prime_lucas_lehmer(n:lent BigInt, p:i64):bool {
    var s = BigInt(4)
    var i:i64 = 0
    while i < p - 2 {
        let sq = s * s
        s = (sq & n) + (sq >> p)
        while s >= n { s -= n }
        if s >= 2 {
            s -= 2
        } else {
            s += n
            s -= 2
        }
        i += 1
    }
    return s.isZero
}

// a small prime divides n, which is above 2^64: 0 where none does
let prime_small_factor(n:lent BigInt):i64 {
    let small:[i64](12) = [2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37]
    for i in 0..<12 {
        if (n % small[i]).isZero { return small[i] }
    }
    return 0
}

// Baillie-PSW: true where neither Miller-Rabin of base 2 nor the Lucas test
// finds n composite; exact below 2^64
let prime_bpsw(n:lent BigInt):bool {
    if n < 2 { return false }
    if n <= prime_u64_max() { return prime_u64(n.u64) }
    if prime_small_factor(n) != 0 { return false }
    return prime_mr(n, 2) && prime_lucas(n)
}

// whether n is prime, and whether only probably
let prime_surely(n:lent BigInt):Primality {
    if n < 2 { return {false, false} }
    if n <= prime_u64_max() { return {prime_u64(n.u64), false} }
    if prime_small_factor(n) != 0 { return {false, false} }
    let next = n + 1
    if (next & n).isZero {                         // 2^p - 1, p its bits
        let p:i64 = n.bits.count as i64 - 1
        if !prime_u64(p as u64) { return {false, false} }
        return {prime_lucas_lehmer(n, p), false}
    }
    if n < 3317044064679887385961981n {            // OEIS A014233: 13 bases prove it
        let bases:[i64](13) = [2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37, 41]
        let k:i64 = n < 318665857834031151167461n ? 12 : 13
        for i in 0..<k {
            if !prime_mr(n, bases[i]) { return {false, false} }
        }
        return {true, false}
    }
    let p = prime_mr(n, 2) && prime_lucas(n)
    return {p, p}
}

// the least prime above n, probably past 2^64, as swift-bignum's
let prime_big_next(n:lent BigInt):BigInt {
    if n < 2 { return BigInt(2) }
    if n < prime_u64_max() {
        let p:u64 = prime_after(n.u64, 0xffffffffffffffff)
        if p != 0 { return BigInt(p as i128) }
    }
    var u = n + 1
    if (u & 1) == 0 { u += 1 }
    while !prime_bpsw(u) { u += 2 }
    return u
}

// the greatest prime below n, none of n 2 and below
let prime_big_prev(n:lent BigInt):BigInt? {
    if n <= 2 { return none }
    if n <= prime_u64_max() { return BigInt(prime_before(n.u64) as i128) }
    var u = n - 1
    if (u & 1) == 0 { u -= 1 }
    while !prime_bpsw(u) { u -= 2 }               // below 2^64 exactly, and 3 is one
    return u
}

// ---------- an i128 and a u128 ----------

let prime_big_of(x:u128):BigInt {
    let hi = BigInt((x >> 64) as i128)
    return (hi << 64) + BigInt((x & 0xffffffffffffffff) as i128)
}

let prime_u128_of(b:lent BigInt):u128 {
    let hi = b >> 64
    let lo = b & prime_u64_max()
    return ((hi.u64 as u128) << 64) | (lo.u64 as u128)
}

let prime_surely128(x:u128):Primality {
    if x <= 0xffffffffffffffff { return {prime_u64(x as u64), false} }
    let b = prime_big_of(x)
    return prime_surely(b)
}

// the least prime above n and not above max, or 0 where there is none
let prime_after128(n:u128, max:u128):u128 {
    if n >= max { return 0 }
    if n < 0xffffffffffffffff {                    // below 2^64, as a u64 is
        let p:u64 = prime_after(n as u64, 0xffffffffffffffff)
        if p != 0 { return p as u128 <= max ? p as u128 : 0 }
    }
    let b = prime_big_of(n)
    let p = prime_big_next(b)
    let m = prime_big_of(max)
    if p > m { return 0 }
    return prime_u128_of(p)
}

let prime_next128(n:u128, max:u128, tn:cstr):u128 {
    let p:u128 = prime_after128(n, max)
    if p == 0 {
        let b = prime_big_of(n)
        let m = $`${b.text(10)}.nextPrime has no value: no prime above ${b.text(10)} fits ${tn}`
        prime_fail(&m)
    }
    return p
}

let prime_before128(n:u128):u128 {
    if n <= 0xffffffffffffffff { return prime_before(n as u64) as u128 }
    let b = prime_big_of(n)
    if let p = prime_big_prev(b) { return prime_u128_of(p) }
    return 0
}

// ---------- each type ----------

extend i8 {
    let isPrime:bool { self > 1 && prime_u64(self as u64) }
    let isProbablePrime:bool { self > 1 && prime_u64(self as u64) }
    let isSurelyPrime:Primality { return {self > 1 && prime_u64(self as u64), false} }
    let nextPrime:i8 { prime_next(self < 2 ? 0 : self as u64, i8.max as u64, "i8") as i8 }
    let prevPrime:i8? {
        let p:u64 = prime_before(self < 0 ? 0 : self as u64)
        if p == 0 { return none }
        return p as i8
    }
    static let primes:Iterator<i8> {
        return Iterator<i8>(0 as u64) {
            let p:u64 = prime_after($0, i8.max as u64)
            if p == 0 { return none }
            $0 = p
            return p as i8
        }
    }
}

extend i16 {
    let isPrime:bool { self > 1 && prime_u64(self as u64) }
    let isProbablePrime:bool { self > 1 && prime_u64(self as u64) }
    let isSurelyPrime:Primality { return {self > 1 && prime_u64(self as u64), false} }
    let nextPrime:i16 { prime_next(self < 2 ? 0 : self as u64, i16.max as u64, "i16") as i16 }
    let prevPrime:i16? {
        let p:u64 = prime_before(self < 0 ? 0 : self as u64)
        if p == 0 { return none }
        return p as i16
    }
    static let primes:Iterator<i16> {
        return Iterator<i16>(0 as u64) {
            let p:u64 = prime_after($0, i16.max as u64)
            if p == 0 { return none }
            $0 = p
            return p as i16
        }
    }
}

extend i32 {
    let isPrime:bool { self > 1 && prime_u64(self as u64) }
    let isProbablePrime:bool { self > 1 && prime_u64(self as u64) }
    let isSurelyPrime:Primality { return {self > 1 && prime_u64(self as u64), false} }
    let nextPrime:i32 { prime_next(self < 2 ? 0 : self as u64, i32.max as u64, "i32") as i32 }
    let prevPrime:i32? {
        let p:u64 = prime_before(self < 0 ? 0 : self as u64)
        if p == 0 { return none }
        return p as i32
    }
    static let primes:Iterator<i32> {
        return Iterator<i32>(0 as u64) {
            let p:u64 = prime_after($0, i32.max as u64)
            if p == 0 { return none }
            $0 = p
            return p as i32
        }
    }
}

extend i64 {
    let isPrime:bool { self > 1 && prime_u64(self as u64) }
    let isProbablePrime:bool { self > 1 && prime_u64(self as u64) }
    let isSurelyPrime:Primality { return {self > 1 && prime_u64(self as u64), false} }
    let nextPrime:i64 { prime_next(self < 2 ? 0 : self as u64, i64.max as u64, "i64") as i64 }
    let prevPrime:i64? {
        let p:u64 = prime_before(self < 0 ? 0 : self as u64)
        if p == 0 { return none }
        return p as i64
    }
    static let primes:Iterator<i64> {
        return Iterator<i64>(0 as u64) {
            let p:u64 = prime_after($0, i64.max as u64)
            if p == 0 { return none }
            $0 = p
            return p as i64
        }
    }
}

extend u8 {
    let isPrime:bool { self > 1 && prime_u64(self as u64) }
    let isProbablePrime:bool { self > 1 && prime_u64(self as u64) }
    let isSurelyPrime:Primality { return {self > 1 && prime_u64(self as u64), false} }
    let nextPrime:u8 { prime_next(self as u64, u8.max as u64, "u8") as u8 }
    let prevPrime:u8? {
        let p:u64 = prime_before(self as u64)
        if p == 0 { return none }
        return p as u8
    }
    static let primes:Iterator<u8> {
        return Iterator<u8>(0 as u64) {
            let p:u64 = prime_after($0, u8.max as u64)
            if p == 0 { return none }
            $0 = p
            return p as u8
        }
    }
}

extend u16 {
    let isPrime:bool { self > 1 && prime_u64(self as u64) }
    let isProbablePrime:bool { self > 1 && prime_u64(self as u64) }
    let isSurelyPrime:Primality { return {self > 1 && prime_u64(self as u64), false} }
    let nextPrime:u16 { prime_next(self as u64, u16.max as u64, "u16") as u16 }
    let prevPrime:u16? {
        let p:u64 = prime_before(self as u64)
        if p == 0 { return none }
        return p as u16
    }
    static let primes:Iterator<u16> {
        return Iterator<u16>(0 as u64) {
            let p:u64 = prime_after($0, u16.max as u64)
            if p == 0 { return none }
            $0 = p
            return p as u16
        }
    }
}

extend u32 {
    let isPrime:bool { self > 1 && prime_u64(self as u64) }
    let isProbablePrime:bool { self > 1 && prime_u64(self as u64) }
    let isSurelyPrime:Primality { return {self > 1 && prime_u64(self as u64), false} }
    let nextPrime:u32 { prime_next(self as u64, u32.max as u64, "u32") as u32 }
    let prevPrime:u32? {
        let p:u64 = prime_before(self as u64)
        if p == 0 { return none }
        return p as u32
    }
    static let primes:Iterator<u32> {
        return Iterator<u32>(0 as u64) {
            let p:u64 = prime_after($0, u32.max as u64)
            if p == 0 { return none }
            $0 = p
            return p as u32
        }
    }
}

extend u64 {
    let isPrime:bool { self > 1 && prime_u64(self as u64) }
    let isProbablePrime:bool { self > 1 && prime_u64(self as u64) }
    let isSurelyPrime:Primality { return {self > 1 && prime_u64(self as u64), false} }
    let nextPrime:u64 { prime_next(self as u64, u64.max as u64, "u64") as u64 }
    let prevPrime:u64? {
        let p:u64 = prime_before(self as u64)
        if p == 0 { return none }
        return p as u64
    }
    static let primes:Iterator<u64> {
        return Iterator<u64>(0 as u64) {
            let p:u64 = prime_after($0, u64.max as u64)
            if p == 0 { return none }
            $0 = p
            return p as u64
        }
    }
}

extend i128 {
    let isPrime:bool { self > 1 && prime_surely128(self as u128).isPrime }
    let isProbablePrime:bool {
        if self < 2 { return false }
        let b = prime_big_of(self as u128)
        return prime_bpsw(b)
    }
    let isSurelyPrime:Primality {
        if self < 2 { return {false, false} }
        return prime_surely128(self as u128)
    }
    let nextPrime:i128 { prime_next128(self < 2 ? 0 : self as u128, i128.max as u128, "i128") as i128 }
    let prevPrime:i128? {
        let p:u128 = prime_before128(self < 0 ? 0 : self as u128)
        if p == 0 { return none }
        return p as i128
    }
    static let primes:Iterator<i128> {
        return Iterator<i128>(0 as u128) {
            let p:u128 = prime_after128($0, i128.max as u128)
            if p == 0 { return none }
            $0 = p
            return p as i128
        }
    }
}

extend u128 {
    let isPrime:bool { self > 1 && prime_surely128(self as u128).isPrime }
    let isProbablePrime:bool {
        if self < 2 { return false }
        let b = prime_big_of(self as u128)
        return prime_bpsw(b)
    }
    let isSurelyPrime:Primality {
        if self < 2 { return {false, false} }
        return prime_surely128(self as u128)
    }
    let nextPrime:u128 { prime_next128(self as u128, u128.max as u128, "u128") as u128 }
    let prevPrime:u128? {
        let p:u128 = prime_before128(self as u128)
        if p == 0 { return none }
        return p as u128
    }
    static let primes:Iterator<u128> {
        return Iterator<u128>(0 as u128) {
            let p:u128 = prime_after128($0, u128.max as u128)
            if p == 0 { return none }
            $0 = p
            return p as u128
        }
    }
}

// ---------- a random prime (#672), as OpenSSL's ----------

// a random BigInt of bits bits, of the system's CSPRNG, as u64.random()
// draws (#547): arc4random_buf, or getrandom on Linux
let prime_random(bits:i64):BigInt {
    var r = BigInt(0)
    var have:i64 = 0
    while have < bits {
        r = (r << 64) + BigInt(u64.random() as i128)
        have += 64
    }
    return r >> (have - bits)
}

// the count of a BigInt's bits, 0 of 0, of one above 0
let prime_bit_count(n:lent BigInt):i64 { n.bits.count as i64 - 1 }

// the primes OpenSSL's calc_trial_divisions sieves by for a prime of bits
// bits: 64 to 512 bits, 128 to 1024, 384 to 2048, 1024 to 4096, 2048 past
let prime_sieve_primes(bits:i64):$[i64] {
    let count:i64 = bits <= 512 ? 64 : bits <= 1024 ? 128 : bits <= 2048 ? 384 : bits <= 4096 ? 1024 : 2048
    var ps:$[i64] = $[]
    var k:i64 = 2
    while ps.count as i64 < count {
        if prime_u64(k as u64) { ps += k }
        k += 1
    }
    return ps
}

// a candidate of bits bits, as OpenSSL's probable_prime draws it: random,
// its top two bits set, so that a product of two has 2 * bits bits, and odd;
// then stepped by 2 past each one a small prime divides, by the remainders
// kept, and drawn again where the step grows past 2^40 or past bits bits
let prime_candidate(bits:i64, ps:const $[i64]^):BigInt {
    while true {
        var r = prime_random(bits)
        r = r | (BigInt(3) << (bits - 2))
        r = r | BigInt(1)
        var mods:$[i64] = $[]
        for i in 0..<ps^.count as i64 { mods += (r % ps^[i]).i64 }
        let small:i64 = bits <= 31 ? r.i64 : 0           // of a word, a small prime may be the candidate itself
        var delta:i64 = 0
        var clean = false
        while !clean && delta < (1:i64 << 40) {
            clean = true
            for i in 1..<ps^.count as i64 {             // 2 is not asked: the candidate is odd
                let p:i64 = ps^[i]
                if bits <= 31 && p * p > small + delta { break }
                if (mods[i] + delta) % p == 0 {
                    clean = false
                    delta += 2
                    break
                }
            }
        }
        if clean {
            let c = r + delta
            if prime_bit_count(c) == bits { return c }
        }
    }
    return BigInt(0)
}

// rounds of Miller-Rabin of random bases from 2 to n - 2, n odd past 2^64
let prime_random_rounds(n:lent BigInt, rounds:i64):bool {
    let span = n - 3
    let width:i64 = prime_bit_count(n) + 64            // 64 bits more than n has, so that % leaves no bias to speak of
    for i in 0..<rounds {
        let b = prime_random(width) % span + 2
        if !prime_mr_base(n, b) { return false }
    }
    return true
}

// BigInt.generatePrime(bits) (#672): Baillie-PSW and OpenSSL's rounds of
// Miller-Rabin of random bases, 64, 128 past 2048 bits, of each candidate
// past 2^64; one of 64 bits or fewer is tested exactly
let prime_generate(bits:i64):BigInt {
    if bits < 2 {
        let m = $`BigInt.generatePrime(${bits}) has no value: a prime has 2 bits or more`
        prime_fail(&m)
    }
    let ps = prime_sieve_primes(bits)
    let rounds:i64 = bits > 2048 ? 128 : 64
    while true {
        let c = prime_candidate(bits, &ps)
        if bits <= 64 {
            if prime_u64(c.u64) { return c }
        } else if prime_bpsw(c) && prime_random_rounds(c, rounds) {
            return c
        }
    }
    return BigInt(0)
}

extend BigInt {
    static let generatePrime(bits:i64):BigInt { prime_generate(bits) }
    let isPrime:bool { prime_surely(self).isPrime }
    let isProbablePrime:bool { prime_bpsw(self) }
    let isSurelyPrime:Primality { prime_surely(self) }
    let nextPrime:BigInt { prime_big_next(self) }
    let prevPrime:BigInt? { prime_big_prev(self) }
    static let primes:Iterator<BigInt> {
        return Iterator<BigInt>(BigInt(0)) {
            let p = prime_big_next($0)
            $0 = p.copy()
            return p
        }
    }
}
