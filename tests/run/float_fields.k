// x.sign, x.exponent and x.significand of a floating-point number (#383):
// IEEE 754's fields, read and set; the sign -1 or 1 by its bit (#597),
// a NaN's too; the exponent biased and the significand the fraction's
// bits, i64s within their fields, or a set ends the program
let main():int32 {
    var x:float64 = -2.5
    let f:float32 = 3.0
    println(x.sign, " ", f.sign, " ", 0.0.sign, " ", (-0.0).sign, " ", nan.sign, " ", (-inf).sign, " ", (-3).sign)
    println(x.exponent, " ", x.significand, " ", f.exponent, " ", f.significand, " ", 1.0.exponent, " ", 1.5.significand)
    x.sign = 1
    print(x, " ")
    x.significand = 0
    print(x, " ")
    x.exponent += 2
    println(x, " ", x.sign > 0, " ", x.sign == 1)
    var g:float32 = 1.0
    g.exponent = 255
    print(g, " ", g.isNaN, " ")
    g.significand = 1
    println(g, " ", g.isNaN, " ", g.sign)
    var y:float64 = 1.0
    y.sign = -1
    y.exponent = 0
    y.significand = 1
    println(y, " ", y.sign)
    var e:int64 = 4000
    x.exponent = e
    return 0
}
// out: -1 1 1 -1 1 -1 -1
// out: 1024 1125899906842624 128 4194304 1023 2251799813685248
// out: 2.5 2.0 8.0 true true
// out: inf false nan true 1
// out: -4.9406564584124654e-324 -1
// exit: 1
// err: kelvin: '.exponent' of an f64 is 0 to 2047, and this set is past it
