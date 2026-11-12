// x.bits is a copy of x's bits (#530): it is not set whole
let main():int32 {
    var x:u8 = 5
    x.bits = $[true]
    return 0
}
// error: an integer's '.bits' is a copy of its bits, an Array<bool>: a bit is set with 'x.bits[n] = b', and all of them with 'x = u8(bools)'
