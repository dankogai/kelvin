// an integer's bit is set with a bool (#454, #530)
let main():int32 {
    var x:i32 = 0
    x.bits[1] = 1
    return 0
}
// error: a bit of an integer is set with a bool, and this is i64: '!!n' makes one of an integer 0 or 1
