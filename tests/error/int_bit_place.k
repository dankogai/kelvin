// a literal place past an integer's width is an error (#454)
let main():int32 {
    var x:u8 = 0
    x.bit(8) = true
    return 0
}
// error: a bit's place in u8 is 0 to 7, and this is 8
