// a floating-point number's sign is -1 or 1, and no other integer (#597)
let main():int32 {
    var x:float64 = 1.0
    x.sign = 0
    return 0
}
// error: '.sign' of an f64 is -1 or 1, and this is 0
