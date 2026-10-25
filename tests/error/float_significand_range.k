// a floating-point number's significand is its fraction's bits, 0 to 2^23 - 1 of an f32 (#383)
let main():int32 {
    var x:float32 = 1.0
    x.significand = 8388608
    return 0
}
// error: '.significand' of an f32 is 0 to 8388607, and this is 8388608
