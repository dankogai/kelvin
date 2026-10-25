// a floating-point number's sign is set with a bool, never none (#383)
let main():int32 {
    var x:float64 = 1.0
    x.sign = none
    return 0
}
// error: '.sign' of a floating-point number is set with a bool: true for positive, false for negative
