// a CBR by 0 (#571): each part is infinite by its sign, and a part that is
// 0 stays 0 beside one that is none, a rational's 0 being exactly 0, so
// CBR(1) / CBR(0) is ((1n/0n)+(0n/1n).i), where its imaginary part was
// 0 / 0, a NaN; 0 / 0 is NaNs still; a c64's is as it was, C's
#import <BigNum>
let main():int32 {
    // by a CBR that is 0
    println(CBR(1) / CBR(0), " ", CBR(0, 1) / CBR(0), " ", CBR(-1) / CBR(0), " ", CBR(0, -1) / CBR(0))
    println(CBR(1, -1) / CBR(0), " ", CBR(-3, 4) / CBR(0), " ", CBR(0) / CBR(0))
    // by a BigRat, a BigInt and an i64 that are 0, and of each by a CBR
    println(CBR(1) / BigRat(0), " ", CBR(0, 1) / 0n, " ", CBR(-1) / 0, " ", CBR(1, -1) / 0, " ", CBR(0) / 0)
    println(BigRat(1) / CBR(0), " ", -1n / CBR(0), " ", 1 / CBR(0), " ", 0 / CBR(0))
    // of a fraction, and z /= 0
    var z = CBR(1n.over(2n), BigRat(0))
    z /= CBR(0)
    println(z, " ", 1n.over(7n).i / CBR(0), " ", z.imag.isFinite, " ", z.real.isInfinite)
    // an infinite part is infinite still, and a NaN part makes no 0 of the other
    let inf = BigRat(1, 0)
    let nan = BigRat(0, 0)
    println(CBR(inf.copy(), BigRat(0)) / CBR(0), " ", CBR(BigRat(0), -inf) / CBR(0), " ", CBR(nan.copy(), BigRat(0)) / CBR(0), " ", CBR(BigRat(0), nan.copy()) / CBR(0), " ", CBR(nan.copy(), BigRat(1)) / CBR(0))
    // by what is not 0 it is as it was, and by an infinity 0
    println(CBR(1) / CBR(2), " ", CBR(1, 1) / CBR(0, 1), " ", CBR(1) / CBR(inf.copy(), BigRat(0)), " ", CBR(1) / inf)
    // a c64 and a c32, of floats, are as they were
    println(c64(1.0) / c64(0.0), " ", c64(0.0, 1.0) / c64(0.0), " ", c64(1.0, -1.0) / c64(0.0), " ", c64(1.0) / 0.0, " ", c32(1.0:f32) / c32(0.0:f32))
    return 0
}
// out: ((1n/0n)+(0n/1n).i) ((0n/1n)+(1n/0n).i) ((-1n/0n)+(0n/1n).i) ((0n/1n)+(-1n/0n).i)
// out: ((1n/0n)+(-1n/0n).i) ((-1n/0n)+(1n/0n).i) ((0n/0n)+(0n/0n).i)
// out: ((1n/0n)+(0n/1n).i) ((0n/1n)+(1n/0n).i) ((-1n/0n)+(0n/1n).i) ((1n/0n)+(-1n/0n).i) ((0n/0n)+(0n/0n).i)
// out: ((1n/0n)+(0n/1n).i) ((-1n/0n)+(0n/1n).i) ((1n/0n)+(0n/1n).i) ((0n/0n)+(0n/0n).i)
// out: ((1n/0n)+(0n/1n).i) ((0n/1n)+(1n/0n).i) true true
// out: ((1n/0n)+(0n/1n).i) ((0n/1n)+(-1n/0n).i) ((0n/0n)+(0n/0n).i) ((0n/0n)+(0n/0n).i) ((0n/0n)+(1n/0n).i)
// out: ((1n/2n)+(0n/1n).i) ((1n/1n)+(-1n/1n).i) ((0n/1n)+(0n/1n).i) ((0n/1n)+(0n/1n).i)
// out: (inf+nan.i) (nan+inf.i) (inf-inf.i) (inf+nan.i) (inf+nan.i)
