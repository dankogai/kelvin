// x.isFinite is worked out of the value, read and never set (#384)
let main():int32 {
    var x:float64 = 1.0
    x.isFinite = false
    return 0
}
// error: '.isFinite' of a floating-point number is read, never set: it is worked out of the value
