// F(sign, exponent, significand) (#598) is the number sign * significand *
// 2^exponent, of three integers: what x.sign, x.exponent and x.significand
// read gives x back, a negative zero and a subnormal too. Of an f64 and an
// f32 it is the nearest, ties to the even one, an infinity past the
// greatest and a zero below the least; of a BigFloat it is rounded to
// BigFloat.precision; of a rational it is exact, or a NaN where it does
// not fit. A BigFloat's and a BigRat's significand may be a BigInt. A sign
// that is neither -1 nor 1 makes a NaN
#import <BigNum>
let back(x:float64):bool { f64(x.sign, x.exponent, x.significand) == x && f64(x.sign, x.exponent, x.significand).sign == x.sign }
let back(x:float32):bool { f32(x.sign, x.exponent, x.significand) == x && f32(x.sign, x.exponent, x.significand).sign == x.sign }
let main():int32 {
    println(f64(1, 0, 1), " ", f64(1, -1, 3), " ", f64(-1, -1, 5), " ", f64(1, 3, 1), " ", f64(1, 0, 6), " ", f64(1, 1, -3), " ", f64(-1, 0, 0), " ", f32(1, 1, 3))
    println(f64(1, 0, 1).typename, " ", f32(1, 0, 1).typename, " ", float64(1, -2, 1), " ", float32(-1, -2, 1))
    println(back(0.1), " ", back(-2.5), " ", back(-0.0), " ", back(0.0), " ", back(f64.leastNonzeroMagnitude), " ", back(f64.greatestFiniteMagnitude), " ", back(1e-310))
    println(back(0.1 as f32), " ", back(f32.leastNonzeroMagnitude), " ", back(f32.greatestFiniteMagnitude), " ", back(-0.0 as f32))
    println(f64(1, 1024, 1), " ", f64(-1, 5000, 1), " ", f64(1, -1075, 1), " ", f64(-1, -5000, 1), " ", f64(1, -1075, 3) == f64.leastNonzeroMagnitude * 2.0, " ", f32(1, 128, 1))
    println(f64(1, 0, 9007199254740993), " ", f64(1, 0, 9007199254740995) == 9007199254740996.0, " ", f64(1, -1076, 3) == f64.leastNonzeroMagnitude, " ", f64(1, -1076, 1))   // rounded once, ties to the even one
    println(f64(2, 0, 1), " ", f64(0, 0, 1), " ", f32(3, 0, 1), " ", BigFloat(2, 0, 1), " ", BigRat(0, 0, 1), " ", rat64(2, 0, 1))                          // no sign: a NaN
    let x = BigFloat(-1, -1, 5n)
    println(x, " ", x.sign, " ", x.exponent, " ", x.significand, " ", x.mantissa, " ", BigFloat(x.sign, x.exponent, x.significand) == x)
    println(BigFloat(1, 10, 3), " ", BigFloat(1, 0, 6n).exponent, " ", BigFloat(1, 0, 6n).significand, " ", BigFloat.infinity.significand, " ", BigFloat.nan.significand, " ", BigFloat(1, 200, 1).hex)
    println(BigRat(1, 0, 1), " ", BigRat(1, -1, 3n), " ", BigRat(-1, -2, 6), " ", BigRat(1, 70, 1n), " ", BigRat(1, -70, 3n))
    println(rat64(1, -1, 3), " ", rat64(-1, -2, 6), " ", rat64(1, 3, 5), " ", rat64(1, 62, 1), " ", rat64(1, 63, 1), " ", rat64(1, -70, 1), " ", rat64(-1, 0, 0))
    println(rat8(1, -3, 5), " ", rat8(1, 6, 1), " ", rat8(1, 7, 1), " ", rat16(-1, -10, 3), " ", rat32(1, 20, 3))
    let y:float64 = 0.1                 // the three of an f64 are the three of any of them
    println(BigFloat(y.sign, y.exponent, y.significand) == BigFloat(y), " ", BigRat(y.sign, y.exponent, y.significand) == BigRat(BigFloat(y)), " ", rat64(1, -1, 3).f64 == f64(1, -1, 3))
    return 0
}
// out: 1.0 1.5 -2.5 8.0 6.0 -6.0 -0.0 6.0
// out: f64 f32 0.25 -0.25
// out: true true true true true true true
// out: true true true true
// out: inf -inf 0.0 -0.0 true inf
// out: 9007199254740992.0 true true 0.0
// out: nan nan nan nan (0n/0n) (0/0)
// out: -2.5 -1 -1 5n -5n true
// out: 3072.0 1 3n 1n 0n +0x1p+200
// out: (1n/1n) (3n/2n) (-3n/2n) (1180591620717411303424n/1n) (3n/1180591620717411303424n)
// out: (3/2) (-3/2) (40/1) (4611686018427387904/1) (0/0) (0/0) (0/1)
// out: (5/8) (64/1) (0/0) (-3/1024) (3145728/1)
// out: true true true
