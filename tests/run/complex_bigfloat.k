// CBF, complexBigFloat by its alias (#581): a complex number of two
// BigFloats, of modules/math+BigFloat.k, the overlay read where <math>
// and <BigFloat> are both imported. Each part of + - * / is the exact
// one's, rounded once to BigFloat.precision bits, so z * w is
// CBF(CBR(z) * CBR(w)) whatever cancels; with a BigFloat, a BigInt or an
// i64 on either side; conj, norm, z.i and x.i, z.round; its text is a
// c64's, (0.1-0.2.i), which CBF(text) reads back, and .dec and .hex
#import <math>
#import <BigFloat>

struct pair {
    z: CBF
    n: i64
}

var seed:u64 = 88172645463325252
let rnd():u64 {
    seed = seed ~ (seed << 13)
    seed = seed ~ (seed >> 7)
    seed = seed ~ (seed << 17)
    return seed
}

// a BigFloat of up to bits bits, exactly, its exponent within span; none is 0
let some(bits:i64, span:i64):BigFloat {
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
    let e:i64 = (rnd() % ((2 * span + 1) as u64)) as i64 - span
    return BigFloat_make(m, e as i128, 100000, 0)
}

let main():int32 {
    let z = CBF(1, 2)
    let w:complexBigFloat = CBF(3, 4)
    println(z, " ", w, " ", z.typename, " ", CBF(5n), " ", CBF(2n, 3n) == CBF(2, 3), " ", CBF(1.5, -2.5), " ", CBF(BigFloat(7)))
    println(z + w, " ", z - w, " ", -z, " ", z * w, " ", z / w, " ", w / w == CBF(1))
    println(z + 1, " ", 1 - z, " ", z * 2n, " ", BigFloat("0.5") * z, " ", 1 / w, " ", z / BigFloat(4))
    println(2n + z, " ", z - BigFloat("0.5"), " ", 3n / w, " ", w / 5n, " ", BigFloat(3) - z, " ", z * 6)
    println(conj(z), " ", z.conj(), " ", norm(w), " ", w.norm(), " ", z.i, " ", BigFloat(7).i, " ", z.i.i == -z)
    println(z * z.conj() == CBF(norm(z)), " ", z != w, " ", sizeof(CBF) == sizeof(BigFloat) * 2)
    // a part has BigFloat.precision bits, 128, as a BigFloat
    let third = CBF(1, 1) / 3
    println(third, " ", third * 3 == CBF(1, 1), " ", third.real.mantissa.bits.count - 1)
    println(third.round(8), " ", third.round(8).hex, " ", third.round(8, BigFloat.up).hex, " ", third.round(1))
    // its text: print's, .dec's and .hex's, each read back
    let v = CBF(BigFloat("0.1"), BigFloat("-0.2"))
    println(v, " ", v.dec, " ", v.hex)
    println(`<${v}>`, " ", v.cstr, " ", v.string.count)
    let t = v.string
    let d = v.dec
    let h = v.hex
    println(CBF(&t) == v, " ", CBF(&d) == v, " ", CBF(&h) == v, " ", CBF(v.cstr) == v, " ", CBF(" ( 0.1 - 0.2.i ) ") == v, " ", CBF("0.1-0.2.i") == v, " ", CBF("{real: 0.1, imag: -0.2}") == v)
    println(CBF("1.5"), " ", CBF("2.0.i"), " ", CBF("(1e+40+1.5e-05.i)"), " ", CBF("(1E3+0X1P4.i)"), " ", CBF("(INF-Infinity.i)"), " ", CBF("(NaN+1.i)"))
    println(CBF("x"), " ", CBF(""), " ", CBF("(1+2)"), " ", CBF("1/3"), " ", CBF("(0.1+0.2.i)", 8), " ", CBF("(0.1+0.2.i)", 8).hex)
    // in a struct, an Optional and an Array
    let p:pair = {CBF(1, -1), 3}
    let maybe:CBF? = CBF(2, 3)
    let zs = $[CBF(1, 2), CBF(3, 4)]
    println(p, " ", maybe, " ", zs)
    // of a c64 and of a CBR, and back
    println(CBF(c64(0.5, 0.25)), " ", CBF(c64(0.1, 0.2), 24), " ", CBF(CBR(1n.over(3n), 2n.over(3n)), 8), " ", CBF(CBR(1n.over(4n), BigRat(3))))
    println(CBR(z / w), " ", c64(z / w), " ", CBF(CBR(z / w)) == z / w)
    // by 0 it is infinite, a part that is 0 staying 0; by an infinity 0; 0 by 0 a NaN, which equals nothing
    let inf = BigFloat(1) / 0
    println(w / CBF(0), " ", z / 0, " ", CBF(1) / CBF(0), " ", CBF(0, -1) / CBF(0), " ", w / (w / CBF(0)), " ", CBF(0) / CBF(0), " ", CBF(0) / CBF(0) == CBF(0) / CBF(0))
    println(CBF(1) * CBF(inf), " ", CBF(0, 1) * inf, " ", CBF(0) * CBF(inf), " ", CBF(inf) / CBF(2), " ", CBF(inf) / CBF(0, -2), " ", CBF(inf, inf) * CBF(1, 1))
    // nothing is lost where the products all but cancel: (1 + e)(1 - e) - 1 is -e^2, e = 2^-100,
    // which the parts' own arithmetic has as 0
    let e = BigFloat("0x1p-100")
    let more = CBF(BigFloat(1) + e, BigFloat(1))
    let less = CBF(BigFloat(1) - e, BigFloat(1))
    println((more * less).hex, " ", (more.real * less.real - more.imag * less.imag).hex)
    println((more / less.conj()).hex, " ", (more * more).hex, " ", norm(more).hex)
    // parts as far apart as any are no more work: 2^1000000000000 and 1
    let far = CBF(BigFloat("0x1p+1000000000000"), BigFloat(1))
    println((far * CBF(1, 1)).hex, " ", (far / CBF(1, 1)).hex)
    println((CBF(1, 1) / far).hex, " ", (far / far).hex, " ", norm(far).hex)
    // at 2 bits 5 is midway between 4 and 6: a part far below says which
    BigFloat.precision = 2
    let five = BigFloat("5", 8)
    let low = BigFloat("0x1p-1000000000000")
    println((CBF(five, low) * CBF(BigFloat(1), low)).real.hex, " ", (CBF(five, low) * CBF(BigFloat(1), -low)).real.hex, " ", (CBF(five) * CBF(1)).real.hex)
    println((CBF(five, low) / CBF(BigFloat(1), low)).real.hex, " ", (CBF(five, low * 8) / CBF(BigFloat(1), low)).real.hex, " ", (CBF(five) / CBF(1)).real.hex)
    // each of the four is the exact one, rounded: 2000 pairs at seven precisions, by a CBR's
    var bad:i64 = 0
    let precisions = $[1, 2, 3, 53, 64, 128, 200]
    let sizes = $[3, 8, 60, 300]
    let spans = $[2, 40, 400, 1500]
    for i in 0..<2000 {
        BigFloat.precision = 100000
        let size = sizes[i % 4]
        let span = spans[(i / 4) % 4]
        let a = CBF(some(size, span), some(size, span))
        let b = CBF(some(size, span), some(size, span))
        BigFloat.precision = precisions[i % 7]
        let ra = CBR(a)
        let rb = CBR(b)
        if !(a + b == CBF(ra + rb)) || !(a - b == CBF(ra - rb)) { bad += 1 }
        if !(a * b == CBF(ra * rb)) || !(a / b == CBF(ra / rb)) { bad += 1 }
        if !(norm(a) == BigFloat(norm(ra))) || !(a * b.real == CBF(ra * rb.real)) || !(a.imag / b == CBF(ra.imag / rb)) { bad += 1 }
    }
    println(bad)
    BigFloat.precision = 53
    println(CBF(1, 2) / CBF(3, 4), " ", CBF(c64(0.1, 0.2)), " ", CBF(1) / 3)
    return 0
}
// out: (1.0+2.0.i) (3.0+4.0.i) CBF (5.0+0.0.i) true (1.5-2.5.i) (7.0+0.0.i)
// out: (4.0+6.0.i) (-2.0-2.0.i) (-1.0-2.0.i) (-5.0+10.0.i) (0.44+0.08.i) true
// out: (2.0+2.0.i) (0.0-2.0.i) (2.0+4.0.i) (0.5+1.0.i) (0.12-0.16.i) (0.25+0.5.i)
// out: (3.0+2.0.i) (0.5+2.0.i) (0.36-0.48.i) (0.6+0.8.i) (2.0-2.0.i) (6.0+12.0.i)
// out: (1.0-2.0.i) (1.0-2.0.i) 25.0 25.0 (-2.0+1.0.i) (0.0+7.0.i) true
// out: true true true
// out: (0.333333333333333333333333333333333333334+0.333333333333333333333333333333333333334.i) true 128
// out: (0.333984375+0.333984375.i) (+0x1.56p-2+0x1.56p-2.i) (+0x1.56p-2+0x1.56p-2.i) (0.25+0.25.i)
// out: (0.1-0.2.i) (+0.1-0.2.i) (+0x1.9999999999999999999999999999999ap-4-0x1.9999999999999999999999999999999ap-3.i)
// out: <(0.1-0.2.i)> (0.1-0.2.i) 11
// out: true true true true true true true
// out: (1.5+0.0.i) (0.0+2.0.i) (1e+40+1.5e-05.i) (1000.0+16.0.i) (inf-inf.i) (nan+1.0.i)
// out: (nan+nan.i) (nan+nan.i) (nan+nan.i) (nan+nan.i) (0.10009765625+0.2001953125.i) (+0x1.9ap-4+0x1.9ap-3.i)
// out: {z: (1.0-1.0.i), n: 3} some((2.0+3.0.i)) [(1.0+2.0.i), (3.0+4.0.i)]
// out: (0.5+0.25.i) (0.100000001490116119384765625+0.20000000298023223876953125.i) (0.333984375+0.66796875.i) (0.25+3.0.i)
// out: ((299448482890425847847769654539956026081n/680564733841876926926749214863536422912n)+(54445178707350154154139937189082913833n/680564733841876926926749214863536422912n).i) (0.44+0.080000000000000002.i) true
// out: (inf+inf.i) (inf+inf.i) (inf+0.0.i) (0.0-inf.i) (0.0+0.0.i) (nan+nan.i) false
// out: (inf+0.0.i) (0.0+inf.i) (nan+nan.i) (inf+0.0.i) (0.0+inf.i) (nan+inf.i)
// out: (-0x1p-200+0x1p+1.i) +0x0p+0
// out: (-0x1.0000000000000000000000001p-201+0x1.0000000000000000000000001p+0.i) (+0x1.00000000000000000000000008p-99+0x1.0000000000000000000000001p+1.i) +0x1.0000000000000000000000001p+1
// out: (+0x1p+1000000000000+0x1p+1000000000000.i) (+0x1p+999999999999-0x1p+999999999999.i)
// out: (+0x1p-1000000000000+0x1p-1000000000000.i) (+0x1p+0+0x0p+0.i) +0x1p+2000000000000
// out: +0x1p+2 +0x1.8p+2 +0x1p+2
// out: +0x1p+2 +0x1.8p+2 +0x1p+2
// out: 0
// out: (0.44+0.08.i) (0.1+0.2.i) (0.3333333333333333+0.0.i)
