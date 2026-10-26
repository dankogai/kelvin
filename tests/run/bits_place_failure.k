// a bit's place is 0 to 63 (#387): past it the program ends, as an index does
let main():int32 {
    var bv = Bits()
    var k = 64
    println("before")
    bv[k] = true
    println("never ", bv)
    return 0
}
// out: before
// exit: 1
// err: kelvin: a Bits has bits 0 to 63, and this place is past them
