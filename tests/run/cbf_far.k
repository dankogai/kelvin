// exp, the sines, the cosines and the tangents of a CBF take a part of
// any size (#585), with <BigNum>: exp(CBF(1, tiny)), tiny
// being 2^-1000000000000, is e + e tiny i, where it was NaNs, a part
// below 2^-67108864 or of 2^67108864 and more being past reckoning
// (#582). They are products and quotients of a BigFloat's functions,
// which take a number of any size (#583), and no rational is made. Near
// 0 a function is its first term; far out e^x is an infinity or 0, and
// sinh and cosh infinities; the sine and the cosine of a number of
// 2^67108864 and more are NaNs, and so is a part one is in, but where
// its other factor is 0. The inverses are as they were; log, arg and pow
// take a part of any size too (#586, cbf_far_log.k)
#import <BigNum>
let main():int32 {
    let tiny = BigFloat("0x1p-1000000000000")
    let huge = BigFloat("0x1p+1000000000000")
    let zero = BigFloat(0)
    let one = BigFloat(1)
    let two = BigFloat(2)
    let e = exp(one, 144)
    let c = cos(one, 144)
    // a part near 0: the first term
    println(exp(CBF(one, tiny)).hex, " ", exp(CBF(one, tiny)).imag == (e * tiny).round(128), " ", exp(CBF(tiny, one)) == CBF(cos(one), sin(one)), " ", exp(CBF(tiny, tiny)).hex)
    println(sin(CBF(tiny, one)).hex, " ", sin(CBF(one, tiny)).hex, " ", cos(CBF(tiny, tiny)).hex, " ", cos(CBF(one, -tiny)).hex)
    println(sinh(CBF(tiny, one)).hex, " ", cosh(CBF(tiny, one)).hex, " ", sinh(CBF(tiny, tiny)).hex, " ", cosh(CBF(one, tiny)).hex)
    println(tanh(CBF(tiny, one)).hex, " ", tanh(CBF(one, tiny)).hex, " ", tan(CBF(tiny, one)).hex, " ", tan(CBF(one, tiny)).hex)
    println(tanh(CBF(tiny, tiny)).hex, " ", tan(CBF(tiny, -tiny)).hex, " ", tanh(CBF(tiny, one)).real == (tiny / (c * c)).round(128), " ", tan(CBF(one, tiny)).imag == (tiny / (c * c)).round(128), " ", tanh(CBF(one, tiny)).real == tanh(one))
    // each a method, and to a precision
    println(CBF(one, tiny).exp(16).hex, " ", CBF(tiny, one).sin(16).hex, " ", exp(CBF(one, tiny), 200).imag.hex, " ", exp(one, 200).hex)
    // a part far out: e^x is an infinity or 0, each part with its factor's sign
    println(exp(CBF(huge, one)), " ", exp(CBF(-huge, one)), " ", exp(CBF(huge, two)), " ", exp(CBF(huge, tiny)), " ", exp(CBF(-huge, tiny)))
    println(sinh(CBF(huge, one)), " ", sinh(CBF(-huge, two)), " ", cosh(CBF(-huge, one)), " ", sin(CBF(one, huge)), " ", sin(CBF(one, -huge)), " ", cos(CBF(one, huge)), " ", cos(CBF(zero, huge)), " ", sin(CBF(tiny, huge)))
    println(tanh(CBF(huge, one)), " ", tanh(CBF(-huge, one)), " ", tan(CBF(one, -huge)), " ", tanh(CBF(huge, tiny)), " ", tan(CBF(tiny, huge)))
    // an angle of 2^67108864 and more has no sine: NaNs, but where the other factor is 0
    println(exp(CBF(one, huge)), " ", exp(CBF(huge, huge)), " ", exp(CBF(-huge, huge)), " ", sin(CBF(huge, one)), " ", sin(CBF(huge, zero)), " ", cos(CBF(huge, one)))
    println(sinh(CBF(one, huge)), " ", sinh(CBF(zero, huge)), " ", cosh(CBF(zero, huge)), " ", cosh(CBF(one, huge)))
    println(tanh(CBF(one, huge)), " ", tanh(CBF(zero, huge)), " ", tanh(CBF(BigFloat(200), huge)), " ", tanh(CBF(-huge, huge)), " ", tan(CBF(huge, one)), " ", tan(CBF(huge, zero)), " ", tan(CBF(huge, -huge)))
    // as they were: at the bound of old, and the inverses of a part past it
    let edge = BigFloat("0x1p-67108866")
    println(exp(CBF(one, edge)).hex, " ", exp(CBF(one, edge * 4)).hex, " ", sin(CBF(edge, one)).real == (edge * cosh(one, 144)).round(128))
    println(acos(CBF(tiny, one)), " ", atan(CBF(huge, one)), " ", asin(CBF(tiny, one)), " ", atanh(CBF(one, huge)), " ", acosh(CBF(tiny, tiny)).real, " ", abs(CBF(tiny, tiny)).hex, " ", sqrt(CBF(huge, zero)).hex)
    return 0
}
// out: (+0x1.5bf0a8b1457695355fb8ac404e7a79e4p+1+0x1.5bf0a8b1457695355fb8ac404e7a79e4p-999999999999.i) true true (+0x1p+0+0x1p-1000000000000.i)
// out: (+0x1.8b07551d9f5504c2bd28100196a4f66ap-1000000000000+0x1.2cd9fc44eb9825a80249487f064ffd5cp+0.i) (+0x1.aed548f090cee0418dd3d2138a1e7866p-1+0x1.14a280fb5068b923848cdb2ed0e37a54p-1000000000001.i) (+0x1p+0-0x1p-2000000000000.i) (+0x1.14a280fb5068b923848cdb2ed0e37a54p-1+0x1.aed548f090cee0418dd3d2138a1e7866p-1000000000001.i)
// out: (+0x1.14a280fb5068b923848cdb2ed0e37a54p-1000000000001+0x1.aed548f090cee0418dd3d2138a1e7866p-1.i) (+0x1.14a280fb5068b923848cdb2ed0e37a54p-1+0x1.aed548f090cee0418dd3d2138a1e7866p-1000000000001.i) (+0x1p-1000000000000+0x1p-1000000000000.i) (+0x1.8b07551d9f5504c2bd28100196a4f66ap+0+0x1.2cd9fc44eb9825a80249487f064ffd5cp-1000000000000.i)
// out: (+0x1.b67766959dae2755023832631f4ad3c2p-999999999999+0x1.8eb245cbee3a5b8acc7d41323140b3b6p+0.i) (+0x1.85efab514f394558632be293c4274fe6p-1+0x1.ae0dc0f990c44ca82a2d1971fa2778dcp-1000000000002.i) (+0x1.ae0dc0f990c44ca82a2d1971fa2778dcp-1000000000002+0x1.85efab514f394558632be293c4274fe6p-1.i) (+0x1.8eb245cbee3a5b8acc7d41323140b3b6p+0+0x1.b67766959dae2755023832631f4ad3c2p-999999999999.i)
// out: (+0x1p-1000000000000+0x1p-1000000000000.i) (+0x1p-1000000000000-0x1p-1000000000000.i) true true true
// out: (+0x1.5bfp+1+0x1.5bfp-999999999999.i) (+0x1.8b08p-1000000000000+0x1.2cdap+0.i) +0x1.5bf0a8b1457695355fb8ac404e7a79e3b1738b079c5a6d2b54p-999999999999 +0x1.5bf0a8b1457695355fb8ac404e7a79e3b1738b079c5a6d2b54p+1
// out: (inf+inf.i) (0.0+0.0.i) (-inf+inf.i) (inf+inf.i) (0.0+0.0.i)
// out: (inf+inf.i) (inf+inf.i) (inf-inf.i) (inf+inf.i) (inf-inf.i) (inf-inf.i) (inf+0.0.i) (inf+inf.i)
// out: (1.0+0.0.i) (-1.0+0.0.i) (0.0-1.0.i) (1.0+0.0.i) (0.0+1.0.i)
// out: (nan+nan.i) (nan+nan.i) (0.0+0.0.i) (nan+nan.i) (nan+0.0.i) (nan+nan.i)
// out: (nan+nan.i) (0.0+nan.i) (nan+0.0.i) (nan+nan.i)
// out: (nan+nan.i) (0.0+nan.i) (1.0+nan.i) (-1.0+0.0.i) (nan+nan.i) (nan+0.0.i) (0.0-1.0.i)
// out: (+0x1.5bf0a8b1457695355fb8ac404e7a79e4p+1+0x1.5bf0a8b1457695355fb8ac404e7a79e4p-67108865.i) (+0x1.5bf0a8b1457695355fb8ac404e7a79e4p+1+0x1.5bf0a8b1457695355fb8ac404e7a79e4p-67108863.i) true
// out: (nan+nan.i) (nan+nan.i) (nan+nan.i) (nan+nan.i) nan +0x1.6a09e667f3bcc908b2fb1366ea957d3ep-1000000000000 (+0x1p+500000000000+0x0p+0.i)
