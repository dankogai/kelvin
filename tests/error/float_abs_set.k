// x.abs is worked out of the value, read and never set (#383)
let main():int32 {
    var x:float64 = 1.0
    x.abs = 2.0
    return 0
}
// error: '.abs' of a floating-point number is read, never set: it is worked out of the value
