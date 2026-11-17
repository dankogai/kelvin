// x.sign is -1 or 1, an i64, of every number of the family (#597): of an
// f64 and an f32 by the sign bit, a zero's and a NaN's too; of a rational
// and a BigFloat -1 where it is negative, the negative infinity too, and
// 1 of all else, as each has one 0 and one NaN, with no sign. It is set in
// a floating-point variable, with -1 or 1, or the program ends
#import <BigNum>
let main():int32 {
    var x:float64 = -2.5
    let nz:float64 = -0.0
    println(x.sign, " ", 2.5.sign, " ", nz.sign, " ", 0.0.sign, " ", f64.nan.sign, " ", (-f64.nan).sign, " ", (-f64.infinity).sign, " ", (2.5 as f32).sign)
    println(rat64(-1, 2).sign, " ", rat64(1, 2).sign, " ", rat64.zero.sign, " ", rat64.nan.sign, " ", (-rat64.infinity).sign, " ", rat8(-3).sign, " ", rat16(3).sign, " ", rat32(-3).sign)
    println(BigRat(-1, 2).sign, " ", BigRat(1, 2).sign, " ", BigRat.zero.sign, " ", BigRat.nan.sign, " ", (-BigRat.infinity).sign)
    println(BigFloat(-2).sign, " ", BigFloat(2).sign, " ", BigFloat.zero.sign, " ", BigFloat(-0.0).sign, " ", BigFloat.nan.sign, " ", (-BigFloat.infinity).sign)
    println(x.sign.typename, " ", rat8(1).sign.typename, " ", BigRat(1).sign.typename, " ", BigFloat(1).sign.typename, " ", (-3).sign, " ", 0.sign, " ", (-3n).sign)
    x.sign = 1                          // set: the bit, in the variable
    print(x, " ")
    x.sign *= -1                        // and flipped
    print(x, " ")
    x.sign = nz.sign                    // another's, C's copysign
    var z:float32 = 0.0
    z.sign = -1                         // a zero's too
    println(x, " ", z, " ", x.abs * x.sign as f64 == x)
    var s:int64 = 2
    x.sign = s
    return 0
}
// out: -1 1 -1 1 1 -1 -1 1
// out: -1 1 1 1 -1 -1 1 -1
// out: -1 1 1 1 -1
// out: -1 1 1 1 1 -1
// out: i64 i64 i64 i64 -1 0 -1
// out: 2.5 -2.5 -2.5 -0.0 true
// exit: 1
// err: kelvin: '.sign' of an f64 is -1 or 1, and this set is neither
