// runtime/pow.k - b.pow(e, m) (#380), Python's pow(b, e, m), written in
// Kelvin (#289): kelvinc --runtime builds it into libkelvin, each kv_
// function by the name kelvin_prelude.h declares. b, e and m are integers
// of 64 bits or fewer, each held in an i128; m's magnitude is 2^64 at
// most, so two values less than it multiply in a u128 without overflow.

// the inverse of a mod n, which shares no factor with n, by Euclid's
// algorithm extended: its coefficients stay within n, so an i128 holds
// them; one that shares a factor ends the program, as Python raises
let kv_pow_inverse(a:u128, n:u128):u128 {
    var r0:i128 = i128(n)
    var r1:i128 = i128(a)
    var t0:i128 = 0
    var t1:i128 = 1
    while r1 != 0 {
        let q:i128 = r0 / r1
        let r2:i128 = r0 - q * r1
        r0 = r1
        r1 = r2
        let t2:i128 = t0 - q * t1
        t0 = t1
        t1 = t2
    }
    if r0 != 1 {
        kv_array_fail("'.pow(e, m)' of a negative e takes the inverse of b mod m, and b has none: b and m share a factor")
    }
    return t0 < 0 ? u128(t0 + i128(n)) : u128(t0)
}

// b to the e, mod m, by squaring: from 0 up to |m|, then of m's sign, as
// Python's % gives; a negative e raises the inverse of b to -e
let kv_pow_mod(b:i128, e:i128, m:i128):i128 {
    if m == 0 { kv_array_fail("'.pow(e, m)' takes a modulus other than 0") }
    let n:u128 = m < 0 ? u128(-m) : u128(m)
    var x:u128 = b < 0 ? (n - u128(-b) % n) % n : u128(b) % n
    if e < 0 { x = kv_pow_inverse(x, n) }
    var k:u128 = e < 0 ? u128(-e) : u128(e)
    var r:u128 = 1 % n
    while k != 0 {
        if (k & 1) != 0 { r = r * x % n }
        x = x * x % n
        k = k >> 1
    }
    return m < 0 && r != 0 ? i128(r) - i128(n) : i128(r)
}
