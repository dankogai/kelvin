// !!n (#387): the bool of an integer 0 or 1, a bit, false or true, of any
// integer type; i64(b) and b.i64 the way back, 0 or 1; two nots are '! !b'
let main():int32 {
    var zero = 0
    var one:u8 = 1
    let yes = true
    println(!!zero, " ", !!one, " ", !!0, " ", !!1, " ", ! !yes)
    var bv = Bits()
    bv[2] = !!one
    println(i64(bv[2]), " ", bv[2].i64, " ", u8(!!zero), " ", bv)
    return 0
}
// out: false true false true true
// out: 1 1 0 Bits(0b100)
