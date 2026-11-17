// abs and sqrt of a CBF take a part of any exponent (#587), with
// <BigNum>: abs(CBF(top, top)), top being 2^9000000000000000000,
// is the root of 2 times top, where it was an infinity, and
// abs(CBF(low, low)), low being 1 over top, was 0. Both are of the norm,
// whose exponent is twice a part's: past 2^(2^62) either way it is past
// an i64's, and no BigFloat holds it. abs is the root of the norm as it
// is summed, with its exponent in full; sqrt is of z over 4^k, whose
// greater part is near 1, times 2^k, and of parts further apart than
// 2^(2^40) it is of the greater alone. sqrt(CBF(top, 1)) was wrong by
// the root of 2
#import <BigNum>
let main():int32 {
    let top = BigFloat("0x1p+9000000000000000000")
    let low = BigFloat("0x1p-9000000000000000000")
    let big = BigFloat("0x1p+9223372036854775806")
    let half = BigFloat("0x1p+4500000000000000000")
    let one = BigFloat(1)
    // abs: the root of the norm, whose exponent is past an i64's
    println(abs(CBF(top, one)).hex, " ", abs(CBF(top, top)).hex, " ", abs(CBF(low, low)).hex, " ", abs(CBF(low, top)).hex, " ", abs(CBF(BigFloat(3) * top, BigFloat(-4) * top)).hex)
    // sqrt of parts far apart: of the greater alone
    println(sqrt(CBF(top, one)).hex, " ", sqrt(CBF(-top, one)).hex, " ", sqrt(CBF(-top, low)).hex)
    println(sqrt(CBF(one, top)).hex, " ", sqrt(CBF(low, -top)).hex, " ", sqrt(CBF(-one, top)).hex)
    // of parts that are level: sqrt(1 + i) times 2^k, and a whole root
    println(sqrt(CBF(top, top)).hex, " ", sqrt(CBF(top, top)).real == sqrt(CBF(1, 1)).real * half, " ", sqrt(CBF(top, top)).imag == sqrt(CBF(1, 1)).imag * half)
    println(sqrt(CBF(low, low)).hex, " ", sqrt(CBF(-top, top)).hex, " ", sqrt(CBF(-top, -top)).imag == -sqrt(CBF(-1, 1)).imag * half)
    println(sqrt(CBF(BigFloat(-7) * top, BigFloat(24) * top)).hex, " ", sqrt(CBF(BigFloat(-7) * low, BigFloat(-24) * low)).hex)
    // at the greatest exponent there is
    println(abs(CBF(big, big)).hex, " ", sqrt(CBF(big, big)).hex, " ", abs(CBF(big * 2, big * 2)), " ", sqrt(CBF(big * 2, big * 2)).hex)
    // each a method, and to a precision; a power of a half is the root
    println(abs(CBF(top, top), 16).hex, " ", CBF(top, one).sqrt(8).hex, " ", CBF(low, low).abs().hex, " ", pow(CBF(top, one), BigFloat("0.5")) == sqrt(CBF(top, one)))
    // as they were
    println(sqrt(CBF(3, 4)), " ", abs(CBF(3, 4)), " ", sqrt(CBF(0, 2)), " ", sqrt(CBF(BigFloat(0), top)).hex, " ", abs(CBF(BigFloat(0), low)).hex)
    return 0
}
// out: +0x1p+9000000000000000000 +0x1.6a09e667f3bcc908b2fb1366ea957d3ep+9000000000000000000 +0x1.6a09e667f3bcc908b2fb1366ea957d3ep-9000000000000000000 +0x1p+9000000000000000000 +0x1.4p+9000000000000000002
// out: (+0x1p+4500000000000000000+0x1p-4500000000000000001.i) (+0x1p-4500000000000000001+0x1p+4500000000000000000.i) (+0x0p+0+0x1p+4500000000000000000.i)
// out: (+0x1.6a09e667f3bcc908b2fb1366ea957d3ep+4499999999999999999+0x1.6a09e667f3bcc908b2fb1366ea957d3ep+4499999999999999999.i) (+0x1.6a09e667f3bcc908b2fb1366ea957d3ep+4499999999999999999-0x1.6a09e667f3bcc908b2fb1366ea957d3ep+4499999999999999999.i) (+0x1.6a09e667f3bcc908b2fb1366ea957d3ep+4499999999999999999+0x1.6a09e667f3bcc908b2fb1366ea957d3ep+4499999999999999999.i)
// out: (+0x1.19435caffa9f8b578507839adceaf36ap+4500000000000000000+0x1.d203138f6c8282677cc6f007597e001ap+4499999999999999998.i) true true
// out: (+0x1.19435caffa9f8b578507839adceaf36ap-4500000000000000000+0x1.d203138f6c8282677cc6f007597e001ap-4500000000000000002.i) (+0x1.d203138f6c8282677cc6f007597e001ap+4499999999999999998+0x1.19435caffa9f8b578507839adceaf36ap+4500000000000000000.i) true
// out: (+0x1.8p+4500000000000000001+0x1p+4500000000000000002.i) (+0x1.8p-4499999999999999999-0x1p-4499999999999999998.i)
// out: +0x1.6a09e667f3bcc908b2fb1366ea957d3ep+9223372036854775806 (+0x1.19435caffa9f8b578507839adceaf36ap+4611686018427387903+0x1.d203138f6c8282677cc6f007597e001ap+4611686018427387901.i) 9.764665922612184750545391836932272037e+2776511644261678565 (+0x1.8dc42193d5c02bf164393f9cb34a737p+4611686018427387903+0x1.49852f983efdd57b4bab8f320d16e6c8p+4611686018427387902.i)
// out: +0x1.6a0ap+9000000000000000000 (+0x1p+4500000000000000000+0x1p-4500000000000000001.i) +0x1.6a09e667f3bcc908b2fb1366ea957d3ep-9000000000000000000 true
// out: (2.0+1.0.i) 5.0 (1.0+1.0.i) (+0x1.6a09e667f3bcc908b2fb1366ea957d3ep+4499999999999999999+0x1.6a09e667f3bcc908b2fb1366ea957d3ep+4499999999999999999.i) +0x1p-9000000000000000000
