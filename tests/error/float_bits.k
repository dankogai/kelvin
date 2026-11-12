// a floating-point number has no .bits (#530): its fields are .sign,
// .exponent and .significand
let main():int32 {
    let f = 1.5
    println(f.bits)
    return 0
}
// error: '.bits' is an integer's bits, each a bool, and this is f64
