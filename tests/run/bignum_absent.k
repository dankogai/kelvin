// with <math> and <Rational> and no <BigNum>, nothing of BigNum is read
// (#590): CBR, complexBigRat and BigFloat are the program's own names, a
// BigRat has no .i but the program's, and math has no function of a
// BigRat. The two together read an overlay before, math+Rational.k
// (#551, #552), which is a part of <BigNum> now; a BigRat's arithmetic
// is Rational's, and stays
#import <math>
#import <Rational>
struct CBR { carbon: f64; boron: f64 }
let complexBigRat(x:f64):f64 { x * 2.0 }
let BigFloat(x:f64):f64 { x + 1.0 }
extend BigRat {
    let i:i64 { 7 }
}
let conj(z:CBR):CBR { (CBR){z.boron, z.carbon} }
let sqrt(x:lent BigRat):i64 { 0 - 1 }
let main():int32 {
    let c:CBR = {1.5, 2.5}
    println(c, " ", conj(c), " ", complexBigRat(c.carbon), " ", BigFloat(c.boron))
    println(1n.over(2n).i, " ", sqrt(1n.over(4n)), " ", 1n.over(3n) + 1n.over(6n), " ", abs(c64(3.0, 4.0)), " ", sqrt(2.0))
    return 0
}
// out: {carbon: 1.5, boron: 2.5} {carbon: 2.5, boron: 1.5} 3.0 3.5
// out: 7 -1 (1n/2n) 5.0 1.4142135623730951
