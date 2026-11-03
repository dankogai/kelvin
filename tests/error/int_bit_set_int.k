// an integer's bit is set with a bool, as a Bits's is (#454)
let main():int32 {
    var x:i32 = 0
    x.bit(1) = 1
    return 0
}
// error: a bit of an integer is set with a bool, and this is i64: '!!n' makes one of an integer 0 or 1
