// <Prime> (#668): n.isPrime, n.nextPrime and n.prevPrime of each integer
// type, and N.primes, an Iterator of N's primes, which ends after N's
// greatest prime
#import <Prime>
let main():int32 {
    println(97.isPrime, " ", 91.isPrime, " ", 2.isPrime, " ", 1.isPrime, " ", 0.isPrime, " ", (0 - 7).isPrime)
    println(100.nextPrime, " ", 100.prevPrime, " ", 3.prevPrime, " ", 2.prevPrime, " ", (0 - 9).nextPrime, " ", (0 - 9).prevPrime)
    let a:u8 = 250
    let b:i16 = 32749
    let c:u32 = 4294967291
    println(a.nextPrime, " ", a.prevPrime, " ", b.isPrime, " ", b.prevPrime, " ", c.isPrime, " ", c.prevPrime)
    println(u64.max.prevPrime, " ", (18446744073709551557 as u64).isPrime, " ", i64.max.prevPrime, " ", (1000000007 as i32).isPrime)
    // strong pseudoprimes to the first bases, each composite
    let ps:[u64](8) = [2047, 1373653, 25326001, 3215031751, 2152302898747, 3474749660383, 341550071728321, 3825123056546413051]
    print("pseudoprimes:")
    for i in 0..<8 { print(" ", ps[i].isPrime) }
    println()
    // 561, 1105 and 1729, Carmichael numbers; 7919, the 1000th prime
    println(561.isPrime, " ", 1105.isPrime, " ", 1729.isPrime, " ", 7919.isPrime, " ", 7919.isSurelyPrime, " ", 7919.isProbablePrime)
    print("above 200:")
    for p in u8.primes {
        if p > 200 { print(" ", p) }
    }
    println()
    println(i8.primes.map { $0 })
    var count = 0
    for p in u16.primes { count += 1 }
    var it = i64.primes
    println(count, " ", it.next(), " ", it.next(), " ", it.next())
    var odd = u32.primes.lazy.filter { $0 % 4 == 1 }
    println(odd.next(), " ", odd.next(), " ", odd.next())
    return 0
}
// out: true false true false false false
// out: 101 some(97) some(2) none 2 none
// out: 251 some(241) true some(32719) true some(4294967279)
// out: some(18446744073709551557) true some(9223372036854775783) true
// out: pseudoprimes: false false false false false false false false
// out: false false false true {isPrime: true, isProbable: false} true
// out: above 200: 211 223 227 229 233 239 241 251
// out: [2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37, 41, 43, 47, 53, 59, 61, 67, 71, 73, 79, 83, 89, 97, 101, 103, 107, 109, 113, 127]
// out: 6542 some(2) some(3) some(5)
// out: some(5) some(13) some(17)
