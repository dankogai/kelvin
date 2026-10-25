// a floating-point number's exponent is its biased field, 0 to 2047 of an f64 (#383)
let main():int32 {
    var x:float64 = 1.0
    x.exponent = 3000
    return 0
}
// error: '.exponent' of an f64 is 0 to 2047, and this is 3000
