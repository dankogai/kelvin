# Prime: `#import <Prime>`

Whether an integer is prime, the primes beside it, and each integer
type's primes in order, of every integer type and of `BigInt`, as
[swift-bignum] has them; and a random prime of any size, as OpenSSL's
[libcrypto] makes one.

[swift-bignum]: https://github.com/dankogai/swift-bignum
[libcrypto]: https://github.com/openssl/openssl/blob/master/crypto/bn/bn_prime.c

## Synopsis

```swift
#import <Prime>

let main():int32 {
    println(97.isPrime, " ", 91.isPrime, " ", 100.nextPrime, " ", 100.prevPrime)   // true false 101 some(97)
    let b:u8 = 250
    println(b.nextPrime, " ", 2.prevPrime, " ", (0 - 7).isPrime)   // 251 none false
    for p in u8.primes {                                           // 2 3 5 ... 251, then none
        if p > 230 { print(p, " ") }                               // 233 239 241 251
    }
    println()
    var it = i64.primes
    println(it.next(), " ", it.next(), " ", it.next())             // some(2) some(3) some(5)
    let m = (1n << 127) - 1
    println(m.isPrime, " ", m.isSurelyPrime)                       // true {isPrime: true, isProbable: false}
    let big = (1n << 200).nextPrime
    println(big - (1n << 200), " ", big.isSurelyPrime)             // 235n {isPrime: true, isProbable: true}
    println(u64.max.prevPrime, " ", i128.max.isPrime)              // some(18446744073709551557) true
    let p = BigInt.generatePrime(512)                              // a random prime of 512 bits
    println(p.bits.count - 1, " ", p >> 510, " ", p.isProbablePrime)   // 512 3n true
    return 0
}
```

## Description

`<Prime>` (#668) gives each integer type, `i8` to `i128` and `u8` to
`u128`, and `BigInt` the attributes below. Kelvin has no generics, so
the module writes them for each type; a program reads them as any
attribute.

- **`n.isPrime`** is whether `n` is prime, a `bool`: `97.isPrime` is
  true, and 0, 1 and a negative number are none.
  - It is a `bool` of every type, one API for all, where swift-bignum's
    is a `Bool?`; `n.isSurelyPrime` says where a true is only probable.
- **`n.nextPrime`** is the least prime above `n`, of `n`'s type: 2 of
  anything below 2.
  - Where none fits the type, the program ends, as swift-bignum's
    traps: `(127 as i8).nextPrime` would be 131, and is `kelvin:
    127.nextPrime has no value: no prime above 127 fits i8`, status 1.
    Where the program's environment has `KELVIN_ABORT`, it aborts
    instead, as the runtime's checks do.
  - A `BigInt`'s never ends the program.
- **`n.prevPrime`** is the greatest prime below `n`, a `T?`: `none` of
  2 and below, as swift-bignum's is a `Self?`.
- **`N.primes`** is an `Iterator<N>` of `N`'s primes from 2 up, a type
  attribute, computed at each read ([properties.md](properties.md)).
  - Of a fixed type it ends, `none`, after the type's greatest prime:
    `u8.primes` gives 54 primes, 2 to 251, and `u16.primes` 6542.
  - `BigInt.primes` never ends.
  - It is an Iterator ([iterators.md](iterators.md)): `for p in`,
    `it.next()`, `lazy.filter`, and `map` of one that ends.
- **`n.isProbablePrime`** is the Baillie-PSW test's answer, a `bool`:
  Miller-Rabin of base 2 and a Lucas probable-prime test, as
  swift-bignum's. No composite is known to pass it, and none below 2^64
  does.
- **`n.isSurelyPrime`** is a `Primality`, a struct of the module of two
  `bool`s, `isPrime` and `isProbable`: whether `n` is prime, and
  whether that is only probable.
  - `isProbable` is true only of a true that rests on Baillie-PSW, and
    false where a test proves the answer, as each false is.
  - `n.isPrime` is its `isPrime`.

### How it is tested

- **64 bits and fewer:** the primes to 37 divide `n`, then Miller-Rabin
  of the seven bases Jim Sinclair found, 2, 325, 9375, 28178, 450775,
  9780504 and 1795265022, which no composite below 2^64 passes: exact,
  and `isProbable` always false. Each step is in `u64`s, a product
  reduced in a `u128`.
- **An `i128`, a `u128` and a `BigInt`,** as swift-bignum's
  Primality.swift tests them:
  - below 2^64, as above;
  - a Mersenne number, `2^p - 1`, by Lucas-Lehmer, exactly:
    `((1n << 521) - 1).isPrime` is true, and `2^523 - 1`'s false;
  - below 3317044064679887385961981, the end of [OEIS A014233], by
    Miller-Rabin of the primes 2 to 41 as bases, exactly;
  - past it by Baillie-PSW, and `isProbable` is true where it is
    prime.
- `nextPrime` and `prevPrime` step by 2 and test each number, by
  Baillie-PSW past 2^64, as swift-bignum's: past it they are the next
  probable prime.

[OEIS A014233]: https://oeis.org/A014233

### A random prime: `BigInt.generatePrime(bits)`

`BigInt.generatePrime(bits)` (#672) is a random prime of exactly `bits`
bits, a function of the type, as OpenSSL's `BN_generate_prime_ex` makes
one.

- **A candidate** is drawn as OpenSSL's `probable_prime` draws it:
  - `bits` random bits of the system's CSPRNG, as `u64.random()` draws
    them (`arc4random_buf`, or `getrandom` on Linux);
  - its top two bits set, so that the product of two has `2 * bits`
    bits, as an RSA modulus wants, and its lowest, so that it is odd;
  - the remainders of the first small primes kept, 64 of them to 512
    bits, 128 to 1024, 384 to 2048, 1024 to 4096 and 2048 past, and the
    candidate stepped by 2 past each one a small prime divides; drawn
    again where it would grow past `bits` bits.
- **Each candidate is tested** by Baillie-PSW, then by rounds of
  Miller-Rabin of random bases, each from 2 to `p - 2`: 64 rounds, a
  false positive of 2^-128 at most, and 128 past 2048 bits, 2^-256, as
  OpenSSL's; FIPS 186-5 allows Miller-Rabin with a Lucas test.
  - A prime of 64 bits or fewer is tested exactly instead.
- **Fewer than 2 bits** ends the program, as OpenSSL's says
  `BN_R_BITS_TOO_SMALL`: `kelvin: BigInt.generatePrime(1) has no value:
  a prime has 2 bits or more`. `BigInt.generatePrime(2)` is 3, and
  `(3)` 7, the only ones with their top two bits set.
- It takes about a second for 1024 bits and for 2048, and some five for
  3072, as candidates come.
- Safe primes, `p` with `(p - 1) / 2` prime, are not made yet.

### For cryptography

The tests are strong, and not hardened:

- **Strong:** below 2^64 and below 3317044064679887385961981 they are
  exact, and a Mersenne number's by Lucas-Lehmer; past them Baillie-PSW
  is known to be passed by no composite, and `generatePrime` adds 64 or
  128 rounds of random bases.
- **The bases of `isPrime` are fixed:** 2, and Selfridge's parameters of
  the Lucas test, the standard one that swift-bignum ports, not the
  strong one of Baillie and Wagstaff. Against a number an adversary
  chose, one tests with random bases, which nobody can prepare for:
  `generatePrime` does, and `isPrime` does not.
- **Not constant-time:** `BigInt`'s arithmetic takes time by its
  values, so timing may tell of a secret prime, and a freed `BigInt`'s
  memory is not wiped.
- So `generatePrime` is good for primes where those do not matter, as
  in tests and in research; a key a service keeps is made by a library
  hardened for it, as libcrypto is.

## Where it lives

A module, modules/Prime.k, built by `make` into a header and a library,
modules/Prime.kh and `libkPrime`, which a program that imports it reads
and links; see [modules.md](modules.md). It is written in Kelvin, on the
prelude's `BigInt`, and its header brings in C's `<stdio.h>` and
`<stdlib.h>`, for the message of `nextPrime`, as `<Combinatorics>`'
does.

- `N.primes` is a computed attribute of an integer type, which a
  program may declare as well since #668: `static let i64.answer:i64 {
  42 }` ([properties.md](properties.md)).

## Properties and methods

| On | Property or method | Gives |
|---|---|---|
| each integer type and `BigInt` | `n.isPrime` | whether `n` is prime, a `bool` |
| | `n.nextPrime` | the least prime above `n`, of its type; the program ends where none fits |
| | `n.prevPrime` | the greatest prime below `n`, a `T?`; `none` of 2 and below |
| | `n.isProbablePrime` | Baillie-PSW's answer, a `bool` |
| | `n.isSurelyPrime` | a `Primality`: whether prime, and whether only probably |
| | `N.primes` | an `Iterator<N>` of the primes from 2, to the type's greatest; `BigInt`'s endless |
| `BigInt` | `BigInt.generatePrime(bits)` | a random prime of exactly `bits` bits, its top two bits set (#672) |
| `Primality` | `.isPrime` | whether prime |
| | `.isProbable` | whether that rests on Baillie-PSW alone |
