// exp of a BigFloat is had up to the greatest exponent there is (#588),
// with <BigNum>: exp(BigFloat("0x1p+62")) is a number of
// 2^6653256548922161245, where it was an infinity. e^x is 2^k times a
// number near 1, k the nearest whole number to x over ln 2, and an x of
// 2^62 and more was taken for past any exponent; but k is an i64's up to
// an x of 2^63 times ln 2, 6.39e18. Now it is the result that is tried
// against the exponents there are: it is an infinity past
// 6393154322601327917, at 128 bits, and 0 below -6393154322601327741,
// the stored exponent being of the last bit. pow, which is e^(y ln x),
// and sinh and cosh, which are of e^x, have their numbers with it, and
// sinh and cosh half of an e^x that is itself past
#import <BigNum>
let main():int32 {
    let x = BigFloat("0x1p+62")
    // from 2^62 up: numbers, where they were infinities and 0
    println(exp(x).hex, " ", exp(BigFloat("0x1.6p+62")).hex, " ", exp(-x).hex)
    // pow is e^(y ln x): a whole power of 2 is the power itself
    println(pow(BigFloat(2), BigFloat("0x1.cp+62")).hex, " ", pow(BigFloat(2), -BigFloat("0x1.cp+62")).hex, " ", pow(BigFloat(4), x).hex)
    // the last number, and an infinity past it
    println(exp(BigFloat("6393154322601327829")).hex, " ", exp(BigFloat("6393154322601327917")).hex, " ", exp(BigFloat("6393154322601327918")), " ", exp(BigFloat("0x1p+63")), " ", exp(BigFloat("0x1p+64")), " ", exp(BigFloat("0x1p+1000")))
    // the least number, and 0 below it
    println(exp(BigFloat("-6393154322601327741")).hex, " ", exp(BigFloat("-6393154322601327742")).hex, " ", exp(-BigFloat("0x1p+63")), " ", exp(-BigFloat("0x1p+1000")))
    // sinh and cosh are half of e^x, which is had where e^x is past; tanh is 1
    println(sinh(BigFloat("6393154322601327917")).hex, " ", cosh(BigFloat("6393154322601327918")).hex, " ", sinh(BigFloat("-6393154322601327918")).hex, " ", cosh(BigFloat("6393154322601327919")), " ", tanh(BigFloat("6393154322601327918")))
    // to a precision, and a method
    println(exp(x, 16).hex, " ", exp(x, 200).hex, " ", x.exp(64).hex)
    // e^x times e^-x, the log of e^x, and an x below 2^62, which is as it was
    println(exp(x) * exp(-x), " ", log(exp(x)).hex, " ", exp(BigFloat("0x1.fp+61")).hex)
    // a CBF's exp and pow are of it
    println(exp(CBF(x, BigFloat(1))).hex, " ", pow(CBF(BigFloat(2), BigFloat(0)), CBF(BigFloat("0x1.cp+62"), BigFloat(1))).hex)
    return 0
}
// out: +0x1.d492cbb9dcb3bb785d720eb50b16734p+6653256548922161245 +0x1.0d81de946e1c7d230c7eea53b2dfd352p+9148227754767971713 +0x1.17b9c38729d40a190b7e88b8f851a9d8p-6653256548922161246
// out: +0x1p+8070450532247928832 +0x1p-8070450532247928832 +inf
// out: +0x1.a2b3641e06196296147386d7cba4748cp+9223372036854775806 +0x1.96739336290ee86f4a9d3ca29035ad6ep+9223372036854775933 inf inf inf inf
// out: +0x1.2fe2e5d6d2df96e955fc43e2ceb07e26p-9223372036854775680 +0x0p+0 0.0 0.0
// out: +0x1.96739336290ee86f4a9d3ca29035ad6ep+9223372036854775932 +0x1.1436605cdc9db9a332776e29785d1122p+9223372036854775934 -0x1.1436605cdc9db9a332776e29785d1122p+9223372036854775934 inf 1.0
// out: +0x1.d492p+6653256548922161245 +0x1.d492cbb9dcb3bb785d720eb50b16733f9cd179eece338f91c2p+6653256548922161245 +0x1.d492cbb9dcb3bb78p+6653256548922161245
// out: 1.0 +0x1p+62 +0x1.eaad1545882a3be8fb434ba94c72a048p+6445342281768343706
// out: (+0x1.fa57b49eb287ab9b994198c87e4bff2ep+6653256548922161244+0x1.8a4a7aeba72982f8c415466a2c7e268ep+6653256548922161245.i) (+0x1.89d9ae6856a553167f6def3078b4f464p+8070450532247928831+0x1.4725eeb25adec71ebdc7d73eaa63863ep+8070450532247928831.i)
