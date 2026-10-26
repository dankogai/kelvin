// a bit is set with a bool, which !!n makes of an integer 0 or 1 (#387)
let main():int32 {
    var bv = Bits()
    bv[0] = 1
    return 0
}
// error: a bit of a Bits is set with a bool, and this is i64: '!!n' makes one of an integer 0 or 1
