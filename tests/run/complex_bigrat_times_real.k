// a CBR times a real CBR, or an imaginary one (#573): the other scaled,
// part by part, and times an infinity a part that is 0 stays 0 beside one
// that is none, so CBR(1) * CBR(inf, 0) is ((1n/0n)+(0n/1n).i), where its
// imaginary part was 0 times an infinity, a NaN; either way round, and
// times a BigRat too; 0 times an infinity is NaNs; what is finite is as
// it was
#import <math>
#import <Rational>
let main():int32 {
    let inf = BigRat(1, 0)
    let nan = BigRat(0, 0)
    let o = BigRat(0)
    let big = CBR(inf.copy(), o.copy())                 // a real infinity
    // a real one times a real infinity, either way round
    println(CBR(1) * big, " ", big * CBR(1), " ", big * CBR(2), " ", CBR(-2) * big, " ", big * big, " ", big * -big)
    // an imaginary one, and one of two parts
    println(CBR(0, 3) * big, " ", big * CBR(0, 3), " ", CBR(0, -3) * big, " ", CBR(1, 2) * big, " ", big * CBR(1, -2))
    // times an imaginary infinity, with a quarter turn
    let up = CBR(o.copy(), inf.copy())
    println(CBR(2) * up, " ", up * CBR(2), " ", CBR(0, 2) * up, " ", up * CBR(0, 2), " ", up * up, " ", big * up, " ", up * big)
    // times a BigRat, a BigInt and an i64, either way round
    println(CBR(1) * inf, " ", inf * CBR(1), " ", CBR(0, 1) * inf, " ", CBR(1) * -inf, " ", big * BigRat(2), " ", 2n * big, " ", big * -2, " ", -2 * up)
    // 0 times an infinity is NaNs, whichever is the 0
    println(CBR(0) * big, " ", big * CBR(0), " ", CBR(0) * up, " ", CBR(0) * inf, " ", big * o, " ", 0 * big, " ", big * 0n)
    // a NaN part makes no 0 of the other, and a NaN factor is NaNs
    println(CBR(nan.copy(), o.copy()) * big, " ", CBR(o.copy(), nan.copy()) * inf, " ", CBR(1) * nan, " ", CBR(1) * CBR(nan.copy(), o.copy()))
    // what is finite is as it was, exact
    println(CBR(1, 2) * CBR(3, -4), " ", CBR(1, 2) * CBR(2), " ", CBR(2) * CBR(1, 2), " ", CBR(1, 2) * CBR(0, 2), " ", CBR(0, 2) * CBR(1, 2), " ", CBR(0, 2) * CBR(0, 3), " ", CBR(1, 2) * CBR(0))
    println(CBR(1, 2) * 1n.over(2n), " ", 1n.over(2n) * CBR(1, 2), " ", CBR(1, 2) * 3, " ", 3n * CBR(1, 2), " ", CBR(1, 1) * CBR(1, -1), " ", norm(CBR(3, 4)))
    var p = CBR(1, 1)
    for k in 0..<7 { p = p * p }
    println(p, " ", p == CBR(BigInt(2).pow(64), 0n))
    // two parts each, the formula's, as it was
    println(CBR(inf.copy(), BigRat(1)) * CBR(1, 1), " ", CBR(inf.copy(), inf.copy()) * CBR(1, 1))
    return 0
}
// out: ((1n/0n)+(0n/1n).i) ((1n/0n)+(0n/1n).i) ((1n/0n)+(0n/1n).i) ((-1n/0n)+(0n/1n).i) ((1n/0n)+(0n/1n).i) ((-1n/0n)+(0n/1n).i)
// out: ((0n/1n)+(1n/0n).i) ((0n/1n)+(1n/0n).i) ((0n/1n)+(-1n/0n).i) ((1n/0n)+(1n/0n).i) ((1n/0n)+(-1n/0n).i)
// out: ((0n/1n)+(1n/0n).i) ((0n/1n)+(1n/0n).i) ((-1n/0n)+(0n/1n).i) ((-1n/0n)+(0n/1n).i) ((-1n/0n)+(0n/1n).i) ((0n/1n)+(1n/0n).i) ((0n/1n)+(1n/0n).i)
// out: ((1n/0n)+(0n/1n).i) ((1n/0n)+(0n/1n).i) ((0n/1n)+(1n/0n).i) ((-1n/0n)+(0n/1n).i) ((1n/0n)+(0n/1n).i) ((1n/0n)+(0n/1n).i) ((-1n/0n)+(0n/1n).i) ((0n/1n)+(-1n/0n).i)
// out: ((0n/0n)+(0n/0n).i) ((0n/0n)+(0n/0n).i) ((0n/0n)+(0n/0n).i) ((0n/0n)+(0n/0n).i) ((0n/0n)+(0n/0n).i) ((0n/0n)+(0n/0n).i) ((0n/0n)+(0n/0n).i)
// out: ((0n/0n)+(0n/0n).i) ((0n/0n)+(0n/0n).i) ((0n/0n)+(0n/0n).i) ((0n/0n)+(0n/0n).i)
// out: ((11n/1n)+(2n/1n).i) ((2n/1n)+(4n/1n).i) ((2n/1n)+(4n/1n).i) ((-4n/1n)+(2n/1n).i) ((-4n/1n)+(2n/1n).i) ((-6n/1n)+(0n/1n).i) ((0n/1n)+(0n/1n).i)
// out: ((1n/2n)+(1n/1n).i) ((1n/2n)+(1n/1n).i) ((3n/1n)+(6n/1n).i) ((3n/1n)+(6n/1n).i) ((2n/1n)+(0n/1n).i) (25n/1n)
// out: ((18446744073709551616n/1n)+(0n/1n).i) true
// out: ((1n/0n)+(1n/0n).i) ((0n/0n)+(1n/0n).i)
