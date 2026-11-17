// a floating-point number's sign is set with -1 or 1 (#597), where it
// was a bool (#383)
let main():int32 {
    var x:float64 = 1.0
    x.sign = false
    return 0
}
// error: '.sign' of a floating-point number is set with -1 or 1, an integer: -1 for negative, 1 for positive (#597)
