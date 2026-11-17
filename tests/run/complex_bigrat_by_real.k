// a CBR by a real CBR, or by an imaginary one (#572): part by part, as by
// a BigRat, so no 0 of the divisor's meets an infinity of the dividend's:
// CBR(inf, 0) / CBR(2) is ((1n/0n)+(0n/1n).i), where its imaginary part
// was 0 times an infinity, a NaN; what is finite is as it was
#import <BigNum>
let main():int32 {
    let inf = BigRat(1, 0)
    let nan = BigRat(0, 0)
    let o = BigRat(0)
    // an infinite one by a real one
    println(CBR(inf.copy(), o.copy()) / CBR(2), " ", CBR(o.copy(), inf.copy()) / CBR(2), " ", CBR(inf.copy(), o.copy()) / CBR(-2), " ", CBR(-inf, BigRat(3)) / CBR(2))
    println(CBR(inf.copy(), inf.copy()) / CBR(2), " ", CBR(inf.copy(), -inf) / CBR(-1n.over(3n), o.copy()))
    // and by an imaginary one, with a quarter turn
    println(CBR(inf.copy(), o.copy()) / CBR(0, 2), " ", CBR(o.copy(), inf.copy()) / CBR(0, 2), " ", CBR(inf.copy(), BigRat(3)) / CBR(0, -2), " ", CBR(inf.copy(), inf.copy()) / CBR(0, 1))
    // as by a BigRat, a BigInt and an i64, which were so
    println(CBR(inf.copy(), o.copy()) / BigRat(2), " ", CBR(inf.copy(), o.copy()) / 2n, " ", CBR(o.copy(), inf.copy()) / 2)
    // what is finite is as it was, exact
    println(CBR(1, 2) / CBR(2), " ", CBR(1, 2) / CBR(0, 2), " ", CBR(3, -4) / CBR(1n.over(2n), o.copy()), " ", CBR(1, 2) / CBR(3, -4), " ", CBR(0) / CBR(0, 5))
    println(CBR(1, 2) / CBR(2) == CBR(1, 2) * CBR(1n.over(2n), o.copy()), " ", CBR(1, 2) / CBR(0, 2) * CBR(0, 2) == CBR(1, 2))
    // a NaN part is one still, by 0 it is #571's, by an infinity 0, and by one neither real nor imaginary the formula's
    println(CBR(nan.copy(), o.copy()) / CBR(2), " ", CBR(1) / CBR(nan.copy(), o.copy()), " ", CBR(1) / CBR(o.copy(), nan.copy()), " ", CBR(1) / CBR(0), " ", CBR(1) / CBR(inf.copy(), o.copy()))
    println(CBR(inf.copy(), o.copy()) / CBR(1, 1), " ", CBR(inf.copy(), inf.copy()) / CBR(1, 1), " ", CBR(inf.copy(), o.copy()) / CBR(inf.copy(), o.copy()))
    // the products likewise (#573)
    println(CBR(1) * CBR(inf.copy(), o.copy()), " ", CBR(inf.copy(), o.copy()) * CBR(2))
    return 0
}
// out: ((1n/0n)+(0n/1n).i) ((0n/1n)+(1n/0n).i) ((-1n/0n)+(0n/1n).i) ((-1n/0n)+(3n/2n).i)
// out: ((1n/0n)+(1n/0n).i) ((-1n/0n)+(1n/0n).i)
// out: ((0n/1n)+(-1n/0n).i) ((1n/0n)+(0n/1n).i) ((-3n/2n)+(1n/0n).i) ((1n/0n)+(-1n/0n).i)
// out: ((1n/0n)+(0n/1n).i) ((1n/0n)+(0n/1n).i) ((0n/1n)+(1n/0n).i)
// out: ((1n/2n)+(1n/1n).i) ((1n/1n)+(-1n/2n).i) ((6n/1n)+(-8n/1n).i) ((-1n/5n)+(2n/5n).i) ((0n/1n)+(0n/1n).i)
// out: true true
// out: ((0n/0n)+(0n/1n).i) ((0n/0n)+(0n/0n).i) ((0n/0n)+(0n/0n).i) ((1n/0n)+(0n/1n).i) ((0n/1n)+(0n/1n).i)
// out: ((1n/0n)+(-1n/0n).i) ((1n/0n)+(0n/0n).i) ((0n/0n)+(0n/0n).i)
// out: ((1n/0n)+(0n/1n).i) ((1n/0n)+(0n/1n).i)
