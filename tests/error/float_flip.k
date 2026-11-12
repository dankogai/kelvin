// a floating-point number has no flip and no bits (#454, #530)
let main():int32 {
    var f = 1.5
    f.flip(1)
    return 0
}
// error: '.flip' is a bool's, '.flip()', as an integer's bit is, 'x.bits[n].flip()', and this is f64
