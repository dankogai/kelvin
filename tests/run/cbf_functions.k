// math's functions of a CBF (#582), with <BigNum>: abs
// and arg, BigFloats, and sqrt, exp, log, pow, the trigonometric and
// hyperbolic functions and their inverses, CBFs, each a method too. Each
// part of a result has BigFloat.precision significant bits, or the
// precision written, whatever its size and however far below the other
// part it is; a part that is 0 is exactly 0; the inverses have a CBR's
// principal values and branch cuts, and with an infinity or a NaN in a
// part each is a CBR's
#import <BigNum>

var seed:u64 = 88172645463325252
let rnd():u64 {
    seed = seed ~ (seed << 13)
    seed = seed ~ (seed >> 7)
    seed = seed ~ (seed << 17)
    return seed
}

// a part: now and then 0, 1, -1, a half or a small whole number; else of
// up to bits bits, exactly, from 2^-span up to 16
let some(bits:i64, span:i64):BigFloat {
    let w:u64 = rnd() % 16
    if w == 0 { return BigFloat_zero() }
    if w == 1 { return BigFloat(1, 100) }
    if w == 2 { return BigFloat(-1, 100) }
    if w == 3 { return BigFloat("0.5", 100) }
    if w == 4 { return BigFloat((rnd() % 9) as i64 - 4, 100) }
    if w == 5 { return BigFloat("-1.5", 100) }
    var m = BigInt(0)
    let n:i64 = (rnd() % (bits as u64)) as i64 + 1
    var k:i64 = 0
    while k < n {
        m = (m << 32) + BigInt((rnd() >> 32) as i64)
        k += 32
    }
    m = m >> (k - n)
    if m.isZero { m = BigInt(1) }
    if rnd() % 2 == 0 { m = 0 - m }
    let e:i64 = 4 - (rnd() % ((span + 5) as u64)) as i64 - BigFloat_length(m)
    return BigFloat_make(m, e as i128, 100000, 0)
}

let size(r:lent BigRat):BigRat {
    if r.num.isNegative { return -r }
    return r.copy()
}

// whether x is ref to bits bits: within a half and a 32nd of its last
// place, ref being good to wide bits after the point; a 0 is a 0
let near(x:lent BigFloat, ref:lent BigRat, bits:i64, wide:i64):bool {
    if x.special == 2 { return ref.isNaN }
    if x.special == 1 { return ref.isInfinite && ref.num.sign == x.mantissa.sign }
    if !ref.isFinite { return false }
    let slack = BigFloat_two(4 - wide)
    if x.mantissa.isZero { return size(ref) < slack }
    let top:i64 = x.exponent + BigFloat_length(x.mantissa)
    return size(BigRat(x) - ref) * 64 <= BigFloat_two(top - bits) * 33 + slack
}

var bad:i64 = 0
let check(got:lent CBF, ref:lent CBR, bits:i64, wide:i64) {
    if !near(got.real, ref.real, bits, wide) || !near(got.imag, ref.imag, bits, wide) { bad += 1 }
}

let main():int32 {
    let z = CBF(1, 2)
    let i = CBF(0, 1)
    println(abs(CBF(3, 4)), " ", abs(z), " ", arg(z), " ", arg(i) * 2 == BigFloat.pi())
    println(sqrt(z), " ", sqrt(CBF(3, 4)), " ", sqrt(CBF(-9)), " ", sqrt(CBF(0, 2)))
    println(exp(z))
    println(log(z))
    println(sin(z), " ", cos(z))
    println(tan(z), " ", tanh(z))
    println(sinh(z), " ", cosh(z))
    println(asin(z), " ", acos(z))
    println(atan(z), " ", asinh(z))
    println(acosh(z), " ", atanh(z))
    println(pow(z, CBF(2)), " ", pow(z, z), " ", pow(z, BigFloat("0.5")) == sqrt(z), " ", pow(BigFloat(2), i))
    // to a precision, and as methods
    println(exp(z, 16), " ", z.exp(16), " ", z.sqrt(8), " ", z.abs(8), " ", z.arg(8), " ", z.pow(z, 12), " ", sqrt(z, 0) == sqrt(z, 1))
    println(z.exp() == exp(z), " ", z.log() == log(z), " ", z.sin() == sin(z), " ", z.atanh() == atanh(z), " ", z.pow(z) == pow(z, z), " ", z.abs() == abs(z), " ", z.arg() == arg(z))
    println(sqrt(z, 256))
    // each part has its bits whatever its size, and however far below the other it is
    println(pow(CBF(10), CBF(1000000000, 1)).hex)
    println(pow(CBF(10), CBF(-1000000000, 1)).hex)
    println(exp(CBF(1000000, 1)).hex, " ", exp(CBF(-1000000, 1)).hex)
    let low = BigFloat("0x1p-1000")
    println(exp(CBF(BigFloat(1), low)).hex, " ", sin(CBF(BigFloat(1), low)).hex)
    println(log(CBF(BigFloat(1), low)).hex, " ", log(CBF(BigFloat("0x1p+1000"), BigFloat(1))).hex)
    println(sqrt(CBF(BigFloat(-1), low)).hex, " ", sqrt(CBF(BigFloat(-1), -low)).hex, " ", pow(CBF(2), CBF(BigFloat("0.5"), low)).hex)
    println(tanh(CBF(1000, 1)).hex, " ", tan(CBF(1, 1000)).hex, " ", atan(CBF(BigFloat("0x1p+1000"), BigFloat(1))).hex)
    // a part that is 0 is exactly 0
    println(pow(i, CBF(2)), " ", pow(i, CBF(3)), " ", pow(CBF(-4), BigFloat("0.5")), " ", pow(CBF(-8), BigFloat("1.5")), " ", pow(CBF(-1), i), " ", pow(i, CBF(100001)), " ", pow(CBF(1), CBF(2, 3)))
    println(exp(CBF(0)), " ", exp(CBF(1)), " ", log(CBF(1)), " ", log(i) * 2 == CBF(BigFloat(0), BigFloat.pi()), " ", sin(i), " ", cos(i), " ", exp(CBF(BigFloat(0), BigFloat.pi())).real)
    // the inverses on their cuts, on the side a CBR's are
    println(asin(CBF(2)), " ", acos(CBF(2)))
    println(acosh(CBF("0.5")), " ", atanh(CBF(2)))
    println(asinh(CBF(0, 2)), " ", atan(CBF(0, 2)))
    println(atanh(CBF(1)), " ", atan(i), " ", asin(CBF(1)).real * 2 == BigFloat.pi(), " ", acos(CBF(1)), " ", acosh(CBF(1)), " ", asinh(i).imag * 2 == BigFloat.pi(), " ", acosh(CBF(-1)).imag == BigFloat.pi())
    // of a real number where a real function is, a BigFloat's
    let x = BigFloat("0.7")
    println(sin(CBF(x)).real == sin(x), " ", exp(CBF(x)).real == exp(x), " ", asin(CBF(x)).real == asin(x), " ", atanh(CBF(x)).real == atanh(x), " ", sqrt(CBF(x)).real == sqrt(x), " ", log(CBF(x)).real == log(x), " ", abs(CBF(x)) == x, " ", acosh(CBF(2)).real == acosh(BigFloat(2)))
    println(pow(CBF(x), CBF(x)).real == pow(x, x), " ", pow(CBF(x), CBF(x)).imag, " ", tan(CBF(x)).real == tan(x), " ", tanh(CBF(x)).real == tanh(x), " ", cosh(CBF(x)).real == cosh(x))
    // an infinity and a NaN in a part, a CBR's
    let inf = BigFloat(1) / 0
    println(exp(CBF(inf)), " ", exp(CBF(-inf)), " ", log(CBF(0)), " ", sqrt(CBF(inf)), " ", sqrt(CBF(-inf)), " ", tanh(CBF(inf)), " ", sin(CBF(inf)), " ", abs(CBF(inf, inf)))
    println(pow(CBF(0), CBF(2)), " ", pow(CBF(0), CBF(-1)), " ", pow(CBF(0), CBF(0)), " ", pow(CBF(inf), CBF(2)), " ", log(CBF(inf)), " ", asin(CBF(inf)), " ", arg(CBF(-inf)) == BigFloat.pi())
    // a part past 2^67108864 in size, or below 2^-67108864, is past reckoning for the inverses; abs and sqrt take any, and exp and its kin (#585), and log, arg and pow (#586)
    let past = BigFloat("0x1p-1000000000")
    println(acos(CBF(BigFloat(1), past)), " ", asin(CBF(BigFloat(1), past)), " ", atan(CBF(BigFloat(1), past)), " ", sqrt(CBF(BigFloat(1), past)).hex, " ", abs(CBF(BigFloat("0x1p+1000000000"), BigFloat(1))).hex)
    // each of the eighteen is a CBR's function of 400 bits more, rounded: 60 values at three precisions
    let precisions = $[8, 53, 128]
    let spans = $[2, 12, 60]
    for k in 0..<60 {
        BigFloat.precision = 100000
        let span = spans[k % 3]
        let a = CBF(some(100, span), some(100, span))
        let b = CBF(some(20, 4), some(20, 4))
        let bits = precisions[(k / 3) % 3]
        BigFloat.precision = bits
        let wide:i64 = bits + 400 + 2 * span
        let r = CBR(a)
        check(sqrt(a), sqrt(r, wide), bits, wide)
        check(exp(a), exp(r, wide), bits, wide)
        check(log(a), log(r, wide), bits, wide)
        check(sin(a), sin(r, wide), bits, wide)
        check(cos(a), cos(r, wide), bits, wide)
        check(tan(a), tan(r, wide), bits, wide)
        check(sinh(a), sinh(r, wide), bits, wide)
        check(cosh(a), cosh(r, wide), bits, wide)
        check(tanh(a), tanh(r, wide), bits, wide)
        check(asin(a), asin(r, wide), bits, wide)
        check(acos(a), acos(r, wide), bits, wide)
        check(atan(a), atan(r, wide), bits, wide)
        check(asinh(a), asinh(r, wide), bits, wide)
        check(acosh(a), acosh(r, wide), bits, wide)
        check(atanh(a), atanh(r, wide), bits, wide)
        check(pow(a, b), pow(r, CBR(b), wide), bits, wide)
        check(CBF(abs(a)), CBR(abs(r, wide)), bits, wide)
        check(CBF(arg(a)), CBR(arg(r, wide)), bits, wide)
    }
    println(bad)
    return 0
}
// out: 5.0 2.23606797749978969640917366873127623544 1.10714871779409050301706546017853704007 true
// out: (1.272019649514068964252422461737491491716+0.786151377757423286069558585842958929524.i) (2.0+1.0.i) (0.0+3.0.i) (1.0+1.0.i)
// out: (-1.13120438375681363843125525551079471063+2.47172667200481892761693089355166453273.i)
// out: (0.804718956217050187300379666613093819762+1.10714871779409050301706546017853704007.i)
// out: (3.16577851321616814674073461719190553838+1.959601041421605897070352049989358278437.i) (2.03272300701966552943634344849951426373-3.05189779915180005751211568689510545289.i)
// out: (0.0338128260798966902843705597252873016401+1.014793616146633568117054175417967614164.i) (1.16673625724091988181007039714498424859-0.243458201185725252702610388652151601455.i)
// out: (-0.489056259041293673586454568548515921158+1.40311925062204058801949085976771294407.i) (-0.64214812471551996484480068696227878947+1.068607421382778339597440033783951588664.i)
// out: (0.427078586392476125480646883318956859303+1.52857091948099816127245618479367339329.i) (1.143717740402420493750674808320794582796-1.52857091948099816127245618479367339329.i)
// out: (1.338972522294493561124193575909144241086+0.402359478108525093650189833306546909881.i) (1.469351744368185273255844317361647616785+1.06344002357775205618949199708955100285.i)
// out: (1.52857091948099816127245618479367339329+1.143717740402420493750674808320794582796.i) (0.173286795139986327354308030364544142019+1.178097245096172464423491268729813581575.i)
// out: (-3.0+4.0.i) (-0.222517156801772608397104761146679039505+0.100709131136075383712307754461575791125.i) true (0.76923890136397212657832999366127070144+0.638961276313634801150032911464701784257.i)
// out: (-1.131195068359375+2.47174072265625.i) (-1.131195068359375+2.47174072265625.i) (1.2734375+0.78515625.i) 2.234375 1.109375 (-0.2225341796875+0.1007080078125.i) true
// out: true true true true true true true
// out: (1.27201964951406896425242246173749149171560804184009624861664038253929757553607+0.78615137775742328606955858584295892952312205783772323766490197010118204762231.i)
// out: (-0x1.3c6cac0073eabe3333eda2b20ca59e28p+3321928094+0x1.604f2e3bb5c6d730bb184dc794d91c64p+3321928094.i)
// out: (-0x1.71e67c6abf9b4beaa3ae625abec0852ap-3321928096+0x1.9bd984799a854aa306b86959f0e9131p-3321928096.i)
// out: (+0x1.1c965c58b1c60e42927cb3eeabca709cp+1442694+0x1.bb37f1b5550151cfe47fc1560a0e8e76p+1442694.i) (+0x1.0ce7898ecc9fc153859022d2af7cc9ep-1442696+0x1.a2cb3a2a4554c5879d9ba362899b3766p-1442696.i)
// out: (+0x1.5bf0a8b1457695355fb8ac404e7a79e4p+1+0x1.5bf0a8b1457695355fb8ac404e7a79e4p-999.i) (+0x1.aed548f090cee0418dd3d2138a1e7866p-1+0x1.14a280fb5068b923848cdb2ed0e37a54p-1001.i)
// out: (+0x1p-2001+0x1p-1000.i) (+0x1.5a92d6d005c939a38650bac4e7b689cep+9+0x1p-1000.i)
// out: (+0x1p-1001+0x1p0.i) (+0x1p-1001-0x1p0.i) (+0x1.6a09e667f3bcc908b2fb1366ea957d3ep0+0x1.f5e46537ab906ae0edd02b8f22d0e43cp-1001.i)
// out: (+0x1p0+0x1.6343400a8dabf7d7069aaf4fbb0f89cp-2885.i) (+0x1.6343400a8dabf7d7069aaf4fbb0f89cp-2885+0x1p0.i) (+0x1.921fb54442d18469898cc51701b839a2p0+0x1p-2000.i)
// out: (-1.0+0.0.i) (0.0-1.0.i) (0.0+2.0.i) (0.0-22.6274169979695207808270195873551692571.i) (0.0432139182637722497744177371717280112758+0.0.i) (0.0+1.0.i) (1.0+0.0.i)
// out: (1.0+0.0.i) (2.71828182845904523536028747135266249776+0.0.i) (0.0+0.0.i) true (0.0+1.175201193643801456882381850595600815153.i) (1.5430806348152437784779056207570616826+0.0.i) -1.0
// out: (1.5707963267948966192313216916397514421+1.316957896924816708625046347307968444025.i) (0.0-1.316957896924816708625046347307968444025.i)
// out: (0.0+1.047197551196597746154214461093167628063.i) (0.549306144334054845697622618461262852324+1.5707963267948966192313216916397514421.i)
// out: (1.316957896924816708625046347307968444025+1.5707963267948966192313216916397514421.i) (1.5707963267948966192313216916397514421+0.549306144334054845697622618461262852324.i)
// out: (inf+0.0.i) (0.0+inf.i) true (0.0+0.0.i) (0.0+0.0.i) true true
// out: true true true true true true true true
// out: true 0.0 true true true
// out: (inf+0.0.i) (0.0+0.0.i) (-inf+0.0.i) (inf+0.0.i) (0.0+inf.i) (1.0+0.0.i) (nan+nan.i) inf
// out: (0.0+0.0.i) (inf+0.0.i) (1.0+0.0.i) (nan+nan.i) (inf+0.0.i) (nan+nan.i) true
// out: (nan+nan.i) (nan+nan.i) (nan+nan.i) (+0x1p0+0x1p-1000000001.i) +0x1p+1000000000
// out: 0
