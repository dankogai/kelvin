// bench.k - Kelvin's BigInt, the cases of swift-bigint-gmp's Benchmarks
// (https://github.com/dankogai/swift-bigint-gmp), best of 3; run.sh builds
// it with kelvinc -O and races it against bench.c (GMP), bench.rb, bench.py
// and bench.mjs.  Each line is a case's id, its best time in seconds and
// its result mod 1000000007, which run.sh checks the five agree on.
#import <time.h> as C

var gDigits:String      // 10,000 decimal digits
var gA:BigInt
var gB:BigInt
var gBig:BigInt         // gA * gA, about 20,000 digits
var gPow:BigInt         // 2 ** 100000, 30,103 digits
var gX:BigInt           // 7 ** 1183 and 3 ** 2093, coprime, about 1,000 digits
var gY:BigInt
var gMod:BigInt         // about 2060 bits, odd
var gBase:BigInt
var gExp:BigInt

let now():f64 {
    var ts:struct timespec
    clock_gettime(CLOCK_MONOTONIC_RAW, &ts)
    return f64(ts.tv_sec) + f64(ts.tv_nsec) * 1e-9
}

let case_sum():BigInt {
    var s = BigInt(0)
    for i in 1...100000 { s += i }
    return s
}

let case_fib():BigInt {                 // 10,000 additions: a is fib(10000)
    var a = BigInt(0)
    var b = BigInt(1)
    for _ in 0..<5000 {
        a += b
        b += a
    }
    return a
}

let case_factorial():BigInt {
    var f = BigInt(1)
    for i in 2...1000 { f *= i }
    return f
}

let case_power():BigInt {
    let two = BigInt(2)
    return two.pow(100000)
}

let case_mul():BigInt {
    var r = BigInt(0)
    for _ in 0..<100 { r = gA * gB }
    return r
}

let case_div():BigInt {
    var r = BigInt(0)
    for _ in 0..<100 { r = gBig / gB }
    return r
}

let case_powmod():BigInt {
    return gBase.pow(gExp, gMod)
}

let case_gcd():BigInt {
    var r = BigInt(0)
    for _ in 0..<10 { r = gX.gcd(gY) }
    return r
}

let case_isqrt():BigInt {
    var r = BigInt(0)
    for _ in 0..<10 { r = gBig.isqrt() }
    return r
}

let case_tostr():BigInt {
    let s = gPow.text(10)
    return BigInt(s.count)
}

let case_parse():BigInt {
    var r = BigInt(0)
    for _ in 0..<100 { r = BigInt(&gDigits) }
    return r
}

let bench(id:cstr, f:():BigInt) {
    var best = 1e300
    var check = BigInt(0)
    for _ in 0..<3 {
        let t0 = now()
        let r = f()
        let t:f64 = now() - t0
        if t < best { best = t }
        check = r % 1000000007
    }
    println(id, "\t", best, "\t", check.text(10))
}

let main():int32 {
    gDigits = String()
    for _ in 0..<1000 { gDigits += "9876543210" }
    gA = BigInt(&gDigits)
    gB = gA + 1
    gBig = gA * gA
    let two = BigInt(2)
    gPow = two.pow(100000)
    let seven = BigInt(7)
    let three = BigInt(3)
    gX = seven.pow(1183)
    gY = three.pow(2093)
    var digits620 = String()
    for _ in 0..<62 { digits620 += "9876543210" }
    gMod = BigInt(&digits620) + 1
    gBase = gMod - 12346
    gExp = gMod >> 1

    bench("sum", case_sum)
    bench("fib", case_fib)
    bench("factorial", case_factorial)
    bench("power", case_power)
    bench("mul", case_mul)
    bench("div", case_div)
    bench("powmod", case_powmod)
    bench("gcd", case_gcd)
    bench("isqrt", case_isqrt)
    bench("tostr", case_tostr)
    bench("parse", case_parse)
    return 0
}
