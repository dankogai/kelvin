// log, arg and pow of a CBF take a part of any size (#586), with <math>
// and <BigFloat>: log(CBF(1, tiny)), tiny being 2^-1000000000000, is
// tiny^2 / 2 + tiny i, where it was NaNs, a part below 2^-67108864 or of
// 2^67108864 and more being past reckoning (#582). The angle is a
// BigFloat's atan2, which takes any two numbers (#583), and the norm is
// had with an exponent of any size, past an i64's too. pow is
// e^(w log z), the angle of z kept as quarter turns and what is left of
// them, so that of a z beside an axis each part's bits are good,
// (tiny + i)^3 is -3 tiny - i; a whole power is the power itself where
// the parts of z are level, (huge + huge i)^2 is 2 huge^2 i; a w near 0
// makes 1 and a part near 0, and a w far out an infinity or 0, or NaNs
// where the angle is past reckoning. On a diagonal an even whole power
// has a part that is 0 exactly, past 65536 too, which did not end; and
// an infinite power has its signs of an angle past 2^64 too, which it had
// not, the angle's bits being cut to 64 where the real part was larger
#import <math>
#import <BigFloat>
let main():int32 {
    let tiny = BigFloat("0x1p-1000000000000")
    let huge = BigFloat("0x1p+1000000000000")
    let top = BigFloat("0x1p+9000000000000000000")
    let low = BigFloat("0x1p-9000000000000000000")
    let zero = BigFloat(0)
    let one = BigFloat(1)
    let two = BigFloat(2)
    // log: half the log of the norm, and the angle
    println(log(CBF(one, tiny)).hex, " ", log(CBF(tiny, one)).hex, " ", log(CBF(BigFloat(3), tiny)).hex)
    println(log(CBF(tiny, tiny)), " ", log(CBF(huge, one)), " ", log(CBF(-huge, huge)))
    // a norm whose exponent is past an i64's
    println(log(CBF(top, top)), " ", log(CBF(low, -low)), " ", log(CBF(low, top)), " ", log(CBF(top, top)).real == log(top, 160) + log(two, 160) / 2)
    // arg, and each a method, and to a precision
    println(arg(CBF(tiny, huge)), " ", arg(CBF(-huge, -tiny)), " ", arg(CBF(huge, tiny)).hex, " ", CBF(tiny, one).arg(16), " ", CBF(one, tiny).log(16).hex, " ", log(CBF(tiny, one), 200).imag.hex)
    // pow of a z beside an axis: each part's bits are good
    println(pow(CBF(one, tiny), CBF(2)).hex, " ", pow(CBF(tiny, one), CBF(3)).hex, " ", pow(CBF(tiny, -one), CBF(-3)).hex, " ", pow(CBF(-one, tiny), CBF(5)).hex)
    // a whole power of a z whose parts are level: the power itself
    println(pow(CBF(huge, huge), CBF(2)).hex, " ", pow(CBF(huge, -huge), CBF(4)).hex, " ", pow(CBF(tiny, tiny), CBF(-2)).hex, " ", pow(CBF(zero, huge), CBF(3)).hex, " ", pow(CBF(top, top), CBF(2)), " ", pow(CBF(low, low), CBF(2)))
    // a w near 0: 1, and w log z
    println(pow(CBF(1, 1), CBF(tiny)).hex, " ", pow(CBF(-2), CBF(tiny)).hex, " ", pow(CBF(2), CBF(tiny, tiny)).hex, " ", pow(CBF(tiny, tiny), CBF(tiny, tiny)).hex)
    // a w far out: (1 + tiny i)^huge is e^i; an infinity or 0, a part that is 0 exactly, and NaNs of an angle past reckoning
    println(pow(CBF(one, tiny), CBF(huge)) == CBF(cos(one), sin(one)), " ", pow(CBF(1, 1), CBF(huge)), " ", pow(CBF(1, 2), CBF(huge)), " ", pow(CBF(1, 2), CBF(-huge)), " ", pow(CBF(0, 2), CBF(huge)), " ", pow(CBF(-2), CBF(huge)))
    println(pow(CBF(tiny, huge), CBF(tiny, -huge)), " ", pow(CBF(huge, tiny), CBF(huge, tiny)), " ", pow(CBF(tiny, huge), CBF(-huge, tiny)))
    // a complex w
    let l = log(huge, 200)
    let p = pow(CBF(tiny, one), CBF(1, 1))
    println(pow(CBF(huge, one), CBF(1, 1)) == exp(CBF(l, l)), " ", p.hex, " ", p.real == tiny * p.imag, " ", p.imag == pow(CBF(0, 1), CBF(1, 1)).imag)
    // 0 to a w and a z to 0 read the other's signs alone; 1 to any w
    println(pow(CBF(0), CBF(tiny)), " ", pow(CBF(0), CBF(-huge)), " ", pow(CBF(0), CBF(zero, tiny)), " ", pow(CBF(huge, tiny), CBF(0)), " ", pow(CBF(1), CBF(huge, tiny)))
    // with a BigFloat on either side, a method, and to a precision
    let lt = log(tiny, 200)
    println(pow(CBF(one, tiny), two).hex, " ", pow(tiny, CBF(0, 1)) == CBF(cos(lt), sin(lt)), " ", CBF(tiny, one).pow(CBF(3), 8).hex, " ", pow(CBF(one, tiny), CBF(huge), 16).hex)
    // on a diagonal an even whole power has a part that is 0 exactly, past 65536 too
    println(pow(CBF(1, 1), CBF(131072)).hex, " ", pow(CBF(-3, 3), CBF(131074)).real, " ", pow(CBF(-3, 3), CBF(131074)).imag == -pow(BigFloat(18), BigFloat(65537)), " ", pow(CBF(huge, huge), CBF(131072)).imag)
    // an infinite power has its signs, of an angle past 2^64 too, which were not had
    println(pow(CBF(BigFloat(-2), BigFloat("0x1.8p+114")), CBF(BigFloat("0x1.aacp+270"))), " ", pow(CBF(BigFloat("-0x1.940f27d9d147e3cc4p-1001"), zero), CBF(BigFloat("-0x1.06d85bc3dbc34p+275"), BigFloat(3))), " ", pow(CBF(BigFloat("0x1.9c2e337fp+640"), BigFloat("0x1.9c2e337fp+640")), CBF(BigFloat("0x1.fp+244"), BigFloat(-4))))
    return 0
}
// out: (+0x1p-2000000000001+0x1p-1000000000000.i) (+0x1p-2000000000001+0x1.921fb54442d18469898cc51701b839a2p+0.i) (+0x1.193ea7aad030a976a4198d55053b7cb6p+0+0x1.55555555555555555555555555555556p-1000000000002.i)
// out: (-693147180559.598735826952148803467952014+0.78539816339744830961566084581987572105.i) (693147180559.945309417232121458176568076+1.044250726930468202952436781310171121576e-301029995664.i) (693147180560.291883007512094112885184137+2.35619449019234492884698253745962716315.i)
// out: (6238324625039507785.1016626834035617674+0.78539816339744830961566084581987572105.i) (-6238324625039507784.40851550284361645796-0.78539816339744830961566084581987572105.i) (6238324625039507784.75508909312358911268+1.5707963267948966192313216916397514421.i) true
// out: 1.5707963267948966192313216916397514421 -3.1415926535897932384626433832795028842 +0x1p-2000000000000 1.57080078125 (+0x1p-2000000000001+0x1p-1000000000000.i) +0x1.921fb54442d18469898cc51701b839a252049c1114cf98e804p+0
// out: (+0x1p+0+0x1p-999999999999.i) (-0x1.8p-999999999999-0x1p+0.i) (-0x1.8p-999999999999-0x1p+0.i) (-0x1p+0+0x1.4p-999999999998.i)
// out: (+0x0p+0+0x1p+2000000000001.i) (-0x1p+4000000000002+0x0p+0.i) (+0x0p+0-0x1p+1999999999999.i) (+0x0p+0-0x1p+3000000000000.i) (0.0+inf.i) (0.0+0.0.i)
// out: (+0x1p+0+0x1.921fb54442d18469898cc51701b839a2p-1000000000001.i) (+0x1p+0+0x1.921fb54442d18469898cc51701b839a2p-999999999999.i) (+0x1p+0+0x1.62e42fefa39ef35793c7673007e5ed5ep-1000000000001.i) (+0x1p+0-0x1.42c5953c1da06dcb53251d5fa793e126p-999999999961.i)
// out: true (inf+0.0.i) (nan+nan.i) (0.0+0.0.i) (inf+0.0.i) (inf+0.0.i)
// out: (nan+nan.i) (inf+inf.i) (0.0+0.0.i)
// out: true (+0x1.a9bcc46f767df3b6d8adbb620cbe8d4ep-1000000000003+0x1.a9bcc46f767df3b6d8adbb620cbe8d4ep-3.i) true true
// out: (0.0+0.0.i) (inf+0.0.i) (nan+nan.i) (1.0+0.0.i) (1.0+0.0.i)
// out: (+0x1p+0+0x1p-999999999999.i) true (-0x1.8p-999999999999-0x1p+0.i) (+0x1.14a2p-1+0x1.aed6p-1.i)
// out: (+0x1p+65536+0x0p+0.i) 0.0 true 0.0
// out: (inf+inf.i) (inf-inf.i) (inf+inf.i)
