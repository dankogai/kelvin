// how print and ${x} show floats: the shortest text that reads back the
// same, as in Swift. Plain decimal from 0.0001 up to 2^53 for f64 and
// 2^24 for f32, where every integer is exact, and an exponent otherwise
main():i32 {
    // whole numbers keep their digits and get a .0
    println(10.0, " ", 100.0, " ", 1500.0, " ", 123456.0, " ", -2500.0)
    println(0.0, " ", -0.0, " ", 1e15, " ", 1.5e15)

    // the top of the plain range: 2^53, then the next f64 above it
    let top = 9007199254740992.0
    println(top, " ", -top, " ", top + 2, " ", 9.5e15, " ", 1e16, " ", 1e21)

    // fractions: plain down to 0.0001, then an exponent
    println(1500.25, " ", 0.5, " ", 0.001, " ", 0.0001, " ", 0.00012)
    println(0.000099, " ", 0.00001, " ", 1e-7, " ", 1.25e-300)

    // f32 has its own range, up to 2^24
    println(10:f32, " ", 1500.5:f32, " ", 16777216:f32, " ", 16777218:f32)
    println(1e8:f32, " ", 0.0001:f32, " ", 0.00001:f32, " ", 1e38:f32)

    // nan and the infinities are as they were
    var zero = 0.0
    println(zero / zero, " ", 1 / zero, " ", -1 / zero)

    // template literals show what print shows
    let x = 1500.0
    let y:f32 = 0.00001
    println(`${x} ${10.0} ${top} ${top * 2} ${y} ${0.0001}`)
}
// out: 10.0 100.0 1500.0 123456.0 -2500.0
// out: 0.0 -0.0 1000000000000000.0 1500000000000000.0
// out: 9007199254740992.0 -9007199254740992.0 9.007199254740994e+15 9.5e+15 1e+16 1e+21
// out: 1500.25 0.5 0.001 0.0001 0.00012
// out: 9.9e-05 1e-05 1e-07 1.25e-300
// out: 10.0 1500.5 16777216.0 1.6777218e+07
// out: 1e+08 0.0001 1e-05 1e+38
// out: nan inf -inf
// out: 1500.0 10.0 9007199254740992.0 1.8014398509481984e+16 1e-05 0.0001
