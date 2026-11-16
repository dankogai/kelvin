// the text of a BigFloat far from 1 (#584), with <BigFloat>: print
// writes the fewest digits of 2^-1000000000000 as soon as of any other
// number, 1.044250726930468202952436781310171121576e-301029995664, and
// BigFloat("1e1000000000") reads it, where each took a rational as long
// as the exponent is large: minutes of a million places and no end of
// more. The digits are of 5^k to as many bits as tell them, and with
// more where those do not; the text reads back as the number, up to
// the largest exponent there is, and a decimal past that is an infinity
// or 0. A decimal is read exactly still where its exponent is near 0
#import <math>
#import <BigFloat>
let far(text:cstr):bool {
    let x = BigFloat(text)
    let y = BigFloat(1) / 3 * x
    return BigFloat(x.string) == x && BigFloat(x.dec) == x && BigFloat(y.string) == y && BigFloat(y.hex) == y && BigFloat((-y).string) == -y
}
let main():int32 {
    let tiny = BigFloat("0x1p-1000000000000")
    println(tiny, " ", tiny.dec, " ", BigFloat(tiny.string) == tiny, " ", BigFloat(tiny.string).hex)
    println(-tiny * 3, " ", BigFloat(1) / tiny, " ", BigFloat(1) / 3 / tiny)
    // a decimal with a large exponent, read: the nearest of 128 bits
    let big = BigFloat("1e1000000000")
    println(big, " ", big.hex, " ", big == pow(BigFloat(10), BigFloat(1000000000)), " ", BigFloat("1e-1000000000000"), " ", BigFloat("1e-1000000000000").hex)
    println(BigFloat("-2.5E+123456789012"), " ", BigFloat("0.000123e-999999999"), " ", BigFloat(" 123456789012345678901234567890123456789012345678901234567890e77777777777 "), " ", BigFloat("12.5e-400"), " ", BigFloat("1e193"))
    // it reads back, whatever the exponent
    println(far("0x1p+1000"), " ", far("0x1p-1300"), " ", far("0x1.8p+1000000"), " ", far("0x1.8p-1000000000"), " ", far("0x1.23456789abcdefp+1000000000000"), " ", far("0x1p-1000000000000000"), " ", far("0x1.fp+9000000000000000000"), " ", far("0x1.fp-9000000000000000000"))
    // up to the largest exponent, and past it
    let top = BigFloat("0x1p+9223372036854775807")
    let low = BigFloat("0x1p-9223372036854775807")
    println(top, " ", low, " ", BigFloat(top.string) == top, " ", BigFloat(low.string) == low)
    println(BigFloat("1e2776000000000000000").hex, " ", BigFloat("1e2777000000000000000"), " ", BigFloat("-1e99999999999999999999999999999"), " ", BigFloat("1e-99999999999999999999999999999"), " ", BigFloat("0e99999999999999999999999999999"))
    // text that is none is a NaN, and what else a BigRat is read from is read exactly
    println(BigFloat("1e1000000000x"), " ", BigFloat("1e+"), " ", BigFloat("1.5e3/2e3"), " ", BigFloat("(1e30)"))
    println(BigFloat("1e1000000000/3"), " ", BigFloat("(1/3e-1000000000)"), " ", BigFloat("1e1000000000/1e1000000000"), " ", BigFloat("5e-1000000000 / 2.5e-1000000000"), " ", BigFloat("1e1000000000/0"), " ", BigFloat("0/1e1000000000"), " ", BigFloat("1e1000000000/"))
    // a complex number's parts
    let z = CBF("(1e+1000000000-2.5e-1000000000.i)")
    println(z, " ", z.dec, " ", CBF(z.string) == z)
    // the fewest digits are of the precision
    BigFloat.precision = 53
    println(BigFloat("1e+1000000"), " ", BigFloat("9.999999999999999e-1000000000"), " ", BigFloat("9.9999999999999999e-1000000000"), " ", BigFloat(1) / 3 * big, " ", far("0x1.8p+500000"))
    BigFloat.precision = 8
    println(BigFloat("1e+1000000"), " ", BigFloat("9.99e+1000000"), " ", BigFloat("123456789e-1000000000000"), " ", tiny, " ", (BigFloat(1) / 3 * big).hex, " ", far("0x1.8p-500000"))
    BigFloat.precision = 1
    println(BigFloat("1e+1000000"), " ", BigFloat("7e-1000000"), " ", BigFloat("0x1p+1000000"), " ", BigFloat("3e+1000000").hex)
    BigFloat.precision = 128
    return 0
}
// out: 1.044250726930468202952436781310171121576e-301029995664 +1.044250726930468202952436781310171121576e-301029995664 true +0x1p-1000000000000
// out: -3.13275218079140460885731034393051336473e-301029995664 9.5762442314927432848050594956989483747e+301029995663 3.19208141049758109493501983189964945824e+301029995663
// out: 1e+1000000000 +0x1.d98be8b54ae7a60042f8305156b7f8bap+3321928094 true 1e-1000000000000 +0x1.8e48978e568a4f083d797f7bff68cbd8p-3321928094888
// out: -2.5e+123456789012 1.23e-1000000003 1.23456789012345678901234567890123456789e+77777777836 1.25e-399 1e+193
// out: true true true true true true true true
// out: 6.90466148990027132480002997655809470257e+2776511644261678565 1.44829692442234944867207849473162564294e-2776511644261678566 true true
// out: +0x1.9c6e2c40aa9965c287cda6a597be0c9ap+9221672391407317877 inf -inf 0.0 0.0
// out: nan nan 0.75 1000000000000000000000000000000.0
// out: 3.33333333333333333333333333333333333334e+999999999 3.33333333333333333333333333333333333334e+999999999 1.0 2.0 inf 0.0 nan
// out: (1e+1000000000-2.5e-1000000000.i) (+1e+1000000000-2.5e-1000000000.i) true
// out: 1e+1000000 9.999999999999999e-1000000000 1e-999999999 3.333333333333333e+999999999 true
// out: 1e+1000000 1e+1000001 1.233e-999999999992 1.044e-301029995664 +0x1.3cp+3321928093 true
// out: 1e+1000000 1e-999999 1e+301030 +0x1p+3321930
