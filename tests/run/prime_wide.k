// <Prime> of an i128, a u128 and a BigInt (#668): exact below 2^64, a
// Mersenne number by Lucas-Lehmer, exact below 3317044064679887385961981 by
// 13 bases, and past it Baillie-PSW, which isSurelyPrime says is probable
#import <Prime>
let main():int32 {
    println(i128.max.isPrime, " ", u128.max.prevPrime, " ", (u64.max as u128 + 1).nextPrime, " ", (0 as i128 - 5).prevPrime)
    let m89 = (1n << 89) - 1
    let m67 = (1n << 67) - 1
    println(m89.isPrime, " ", m67.isPrime, " ", ((1n << 521) - 1).isSurelyPrime, " ", ((1n << 523) - 1).isPrime)
    // strong pseudoprimes to the bases through 37, and through 41
    println(318665857834031151167461n.isSurelyPrime, " ", 3317044064679887385961981n.isPrime)
    let big = (1n << 200).nextPrime
    println(big - (1n << 200), " ", big.isSurelyPrime, " ", big.isProbablePrime, " ", (big + 2).isPrime)
    if let p = (1n << 200).prevPrime { println((1n << 200) - p) }
    println(1000000000000000000000000000057n.isSurelyPrime, " ", (1n << 64).nextPrime, " ", 2n.prevPrime, " ", 0n.isPrime)
    var it = BigInt.primes
    var sum = 0n
    for i in 0..<100 {
        if let p = it.next() { sum += p }
    }
    println(sum, " ", it.next())
    var wide = u128.primes
    var few = i128.primes.lazy.filter { $0 > 1000 }
    println(wide.next(), " ", wide.next(), " ", few.next(), " ", few.next())
    return 0
}
// out: true some(340282366920938463463374607431768211297) 18446744073709551629 none
// out: true false {isPrime: true, isProbable: false} false
// out: {isPrime: false, isProbable: false} false
// out: 235n {isPrime: true, isProbable: true} true false
// out: 75n
// out: {isPrime: true, isProbable: true} 18446744073709551629n none false
// out: 24133n some(547n)
// out: some(2) some(3) some(1009) some(1013)
