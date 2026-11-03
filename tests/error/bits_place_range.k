// a bit's place is 0 or more (#387, #455): a negative literal is an error
let main():int32 {
    var bv = Bits(0)
    bv[-1] = true
    return 0
}
// error: a bit's place in a Bits is 0 or more, and this is -1
