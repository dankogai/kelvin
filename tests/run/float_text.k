// how print and ${x} show floats: every digit the type holds, %.17g's for
// an f64 and %.9g's for an f32, which is what the value is (#259), with
// a point, trailing zeros gone. Plain decimal from 0.0001 up to 2^53 for f64 and
// 2^24 for f32, where every integer is exact, and an exponent otherwise
let main():int32 {
    // whole numbers keep their digits and get a .0
    println(10.0, " ", 100.0, " ", 1500.0, " ", 123456.0, " ", -2500.0)
    println(0.0, " ", -0.0, " ", 1e15, " ", 1.5e15)

    // the top of the plain range: 2^53, then the next f64 above it
    let top = 9007199254740992.0
    println(top, " ", -top, " ", top + 2, " ", 9.5e15, " ", 1e16, " ", 1e21)

    // fractions: plain down to 0.0001, then an exponent
    println(1500.25, " ", 0.5, " ", 0.001, " ", 0.0001, " ", 0.00012)
    println(0.000099, " ", 0.00001, " ", 1e-7, " ", 1.25e-300)

    // negative numbers keep their sign in front, in both forms
    println(-1500.25, " ", -0.5, " ", -0.0015, " ", -0.0001, " ", -0.00001)
    println(-1.25e-300, " ", -1.5e16, " ", -0.0015:float32, " ", -1e8:float32)

    // the extremes keep every digit of their exponents
    println(5e-324, " ", 1.7976931348623157e308, " ", 1e-45:float32, " ", 3.4028235e38:float32)

    // f32 has its own range, up to 2^24
    println(10:float32, " ", 1500.5:float32, " ", 16777216:float32, " ", 16777218:float32)
    println(1e8:float32, " ", 0.0001:float32, " ", 0.00001:float32, " ", 1e38:float32)

    // nan and the infinities are as they were
    var zero = 0.0
    println(zero / zero, " ", 1 / zero, " ", -1 / zero)

    // template literals show what print shows
    let x = 1500.0
    let y:float32 = 0.00001
    println(`${x} ${10.0} ${top} ${top * 2} ${y} ${0.0001}`)
}
// out: 10.0 100.0 1500.0 123456.0 -2500.0
// out: 0.0 -0.0 1000000000000000.0 1500000000000000.0
// out: 9007199254740992.0 -9007199254740992.0 9.007199254740994e+15 9.5e+15 1e+16 1e+21
// out: 1500.25 0.5 0.001 0.0001 0.00012
// out: 9.8999999999999994e-05 1.0000000000000001e-05 9.9999999999999995e-08 1.25e-300
// out: -1500.25 -0.5 -0.0015 -0.0001 -1.0000000000000001e-05
// out: -1.25e-300 -1.5e+16 -0.00150000001 -1e+08
// out: 4.9406564584124654e-324 1.7976931348623157e+308 1.40129846e-45 3.40282347e+38
// out: 10.0 1500.5 16777216.0 1.6777218e+07
// out: 1e+08 9.99999975e-05 9.99999975e-06 9.99999968e+37
// out: nan inf -inf
// out: 1500.0 10.0 9007199254740992.0 1.8014398509481984e+16 9.99999975e-06 0.0001
