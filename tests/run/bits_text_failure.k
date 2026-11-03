// a Bits's text is 0b and binary digits (#455): other text ends the program
let main():int32 {
    let t:cstr := "0x1"
    println("before")
    let bv = Bits(t)
    println("never ", bv)
    return 0
}
// out: before
// exit: 1
// err: kelvin: a Bits's text is 0b and binary digits, as "0b101", and this is not
