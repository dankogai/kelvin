// a bit's place is 0 to 63 (#387)
let main():int32 {
    var bv = Bits()
    bv[64] = true
    return 0
}
// error: a bit's place in a Bits is 0 to 63, and this is 64
