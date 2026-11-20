// A BigFloat's range is of its leading bit (#623), with <BigNum>: one of
// 2^(2^63) and more in size is an infinity, at any precision, and the
// bits below the least number, 2^-(2^63 - 1), are rounded off, as an
// f64 keeps fewer bits below 2^-1022. It was of the last bit, so that
// 0x1p+9223372036854775808 was an infinity and the greater
// 0x1.8p+9223372036854775808 a number, and a number whose low bits fell
// below the least was 0 while a less one of fewer bits was not
#import <BigNum>
let main():int32 {
    // its leading bit at 2^(2^63 - 1): a number, of any bits below it
    let big = BigFloat("0x1.8p+9223372036854775807")
    println(big.isFinite, " ", BigFloat("0x1.ffffp+9223372036854775807").isFinite, " ", BigFloat("0x1p+9223372036854775807", 512).isFinite)
    // and at 2^(2^63) an infinity, the greater too
    println(BigFloat("0x1p+9223372036854775808").isInfinite, " ", BigFloat("0x1.8p+9223372036854775808").isInfinite, " ", (big * BigFloat(2)).isInfinite)
    // the least number, and what is below it rounded to it or to 0
    let least = BigFloat("0x1p-9223372036854775807")
    println(least.hex, " ", (least / BigFloat(2)).hex, " ", (least * BigFloat(3) / BigFloat(4)).hex, " ", (least / BigFloat(4)).hex)
    // a number whose low bits fall below it keeps its upper bits
    println(BigFloat("0x1.8p-9223372036854775807").hex, " ", BigFloat("0x1.4p-9223372036854775806").hex, " ", BigFloat("0x1.fffp-9223372036854775800").hex)
    println(BigFloat("0x1p-9223372036854775808").hex, " ", BigFloat("0x1.0001p-9223372036854775808").hex)
    // exp's limits are 2^63 ln 2 either way, at any precision
    println(exp(BigFloat("6393154322601327829"), 64).isFinite, " ", exp(BigFloat("6393154322601327830"), 64), " ", exp(BigFloat("6393154322601327829"), 512).isFinite, " ", exp(BigFloat("-6393154322601327829"), 512).hex)
    return 0
}
// out: true true true
// out: true true true
// out: +0x1p-9223372036854775807 +0x0p0 +0x1p-9223372036854775807 +0x0p0
// out: +0x1p-9223372036854775806 +0x1p-9223372036854775806 +0x1p-9223372036854775799
// out: +0x0p0 +0x1p-9223372036854775807
// out: true inf true +0x1p-9223372036854775807
