// a floating-point number has no flip and no bit (#454)
let main():int32 {
    var f = 1.5
    f.flip(1)
    return 0
}
// error: '.flip' is a bool's, '.flip()', or an integer's, '.flip(n)', and this is f64
