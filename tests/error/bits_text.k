// a Bits's text is 0b and binary digits (#455), a literal checked
let main():int32 {
    let bv = Bits("0b12")
    println(bv)
    return 0
}
// error: Bits(x, ...) takes text of 0b and binary digits, as "0b101"
