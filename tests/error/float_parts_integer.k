// F(sign, exponent, significand) is of three integers (#598)
let main():int32 {
    let x = f64(1, 0, 1.5)
    println(x)
    return 0
}
// error: f64(sign, exponent, significand) is of three integers (#598), and its significand is a floating-point number
