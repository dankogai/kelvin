// <BigNum> is the one library of the numbers of any size (#590): CBR, a
// complex number of two BigRats, BigFloat, a float of any precision, CBF,
// a complex number of two BigFloats, and math's functions of a BigRat, a
// CBR, a BigFloat and a CBF. It was <BigFloat> and two overlays before,
// read where <math> was imported beside <Rational> or <BigFloat>; now the
// one import brings all of it, with math and Rational, which it imports
#import <BigNum>
let main():int32 {
    // BigFloat, and math's functions of one
    let x = BigFloat(1) / 3
    println(x, " ", sqrt(BigFloat(2)), " ", BigFloat.pi(64), " ", x.round(8).hex)
    // CBF, of two, and its functions
    println(CBF(1, 2) * CBF(3, 4), " ", exp(CBF(0, 1), 64), " ", abs(CBF(3, 4)))
    // CBR, of two BigRats, exact, and a BigRat's functions, to a precision
    let z = CBR(1n.over(2n), 1n.over(3n))
    println(z * z, " ", z.conj(), " ", sqrt(1n.over(4n)), " ", BigRat.pi(16), " ", exp(CBR(0, 0)))
    // the type names stay: complexBigRat and complexBigFloat by their aliases too
    let w:complexBigFloat = CBF(BigFloat(2))
    let v:complexBigRat = CBR(2n.over(1n))
    println(w.typename, " ", v.typename, " ", x.typename, " ", w == CBF(v))
    // what it imports is the program's too: math's own, and Rational's
    println(sqrt(2.0), " ", abs(c64(3.0, 4.0)), " ", f64.tau, " ", rat64(1, 3) + rat64(1, 6), " ", 1n.over(3n) + 1n.over(6n))
    return 0
}
// out: 0.333333333333333333333333333333333333334 1.41421356237309504880168872420969807857 3.14159265358979323851280895940618620443 +0x1.56p-2
// out: (-5.0+10.0.i) (0.54030230586813971741400736137350691024+0.841470984807896506664590813295845350694.i) 5.0
// out: ((5n/36n)+(1n/3n).i) ((1n/2n)+(-1n/3n).i) (1n/2n) (205887n/65536n) ((1n/1n)+(0n/1n).i)
// out: CBF CBR BigFloat true
// out: 1.4142135623730951 5.0 6.2831853071795862 (1/2) (1n/2n)
