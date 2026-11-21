// BigInt.generatePrime(bits) of fewer than 2 bits ends the program (#672):
// no prime has fewer, as OpenSSL's says BN_R_BITS_TOO_SMALL
#import <Prime>
let main():int32 {
    println(BigInt.generatePrime(2))
    println(BigInt.generatePrime(1))
    return 0
}
// out: 3n
// exit: 1
// err: kelvin: BigInt.generatePrime(1) has no value: a prime has 2 bits or more
