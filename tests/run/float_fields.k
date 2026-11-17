// x.sign, x.exponent and x.significand of a floating-point number: x is
// its sign times its significand times 2 to its exponent (#598), three
// integers, the sign -1 or 1 by its bit (#597) and the significand odd,
// or 0 of a zero with an exponent of 0, as a BigFloat's mantissa and
// exponent are; each is set in the var that holds x. They were IEEE 754's
// raw fields, the exponent biased (#383)
let main():int32 {
    var x:float64 = -2.5
    let f:float32 = 3.0
    println(x.sign, " ", f.sign, " ", 0.0.sign, " ", (-0.0).sign, " ", nan.sign, " ", (-inf).sign, " ", (-3).sign)
    println(x.exponent, " ", x.significand, " ", f.exponent, " ", f.significand, " ", 1.0.exponent, " ", 1.0.significand, " ", 1.5.exponent, " ", 1.5.significand)
    println(8.0.exponent, " ", 3.0.exponent, " ", 0.75.exponent, " ", 0.75.significand, " ", 0.1.exponent, " ", 0.1.significand, " ", 0.0.exponent, " ", 0.0.significand)
    println(inf.exponent, " ", inf.significand, " ", nan.exponent, " ", nan.significand)   // as a BigFloat keeps them: 1 times 2^0, and 0
    println(f64.leastNonzeroMagnitude.exponent, " ", f64.leastNonzeroMagnitude.significand, " ", f64.greatestFiniteMagnitude.exponent, " ", f64.greatestFiniteMagnitude.significand)
    println(f32.leastNonzeroMagnitude.exponent, " ", f32.greatestFiniteMagnitude.exponent, " ", f32.greatestFiniteMagnitude.significand, " ", x.exponent.typename, " ", f.significand.typename)
    x.sign = 1
    print(x, " ")
    x.exponent += 1                     // doubled
    print(x, " ")
    x.significand = 3                   // its sign and its exponent kept
    print(x, " ")
    x.exponent = -2
    println(x, " ", x.exponent, " ", x.significand, " ", x.sign > 0)
    var g:float32 = 1.0
    g.exponent = 127
    print(g, " ")
    g.exponent += 1                     // past the greatest: an infinity
    print(g, " ")
    g = 1.0
    g.exponent = -149
    print(g == f32.leastNonzeroMagnitude, " ")
    g.exponent -= 1                     // below the least: 0
    println(g, " ", g.exponent)
    var y:float64 = 1.0
    y.sign = -1
    y.significand = 6                   // 6 is 3 times 2: the significand read is the odd 3
    println(y, " ", y.significand, " ", y.exponent, " ", y.sign)
    return 0
}
// out: -1 1 1 -1 1 -1 -1
// out: -1 5 0 3 0 1 -1 3
// out: 3 0 -2 3 -55 3602879701896397 0 0
// out: 0 1 0 0
// out: -1074 1 971 9007199254740991
// out: -149 104 16777215 i64 i64
// out: 2.5 5.0 3.0 0.75 -2 3 true
// out: 1.70141183e+38 inf true 0.0 0
// out: -6.0 3 1 -1
