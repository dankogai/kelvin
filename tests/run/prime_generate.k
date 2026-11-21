// BigInt.generatePrime(bits) of <Prime> (#672): a random prime of exactly
// that many bits, its top two bits set, as OpenSSL's BN_generate_prime_ex
// makes one, so that a product of two has twice the bits
#import <Prime>
let main():int32 {
    var ok = true
    for b in 2...70 {
        let p = BigInt.generatePrime(b)
        if p.bits.count - 1 != b || p >> (b - 2) != 3 || !p.isPrime { ok = false }
    }
    println(ok, " ", BigInt.generatePrime(2), " ", BigInt.generatePrime(3))
    let p = BigInt.generatePrime(512)
    let q = BigInt.generatePrime(512)
    println(p.bits.count - 1, " ", p >> 510, " ", p.isProbablePrime, " ", p.isSurelyPrime.isProbable)
    println((p * q).bits.count - 1, " ", p != q, " ", (p % 2) == 1)
    return 0
}
// out: true 3n 7n
// out: 512 3n true true
// out: 1024 true true
