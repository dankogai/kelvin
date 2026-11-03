// a bit's place is 0 to the count less 1 (#387, #455): past it the program
// ends, as an index past an Array's count does
let main():int32 {
    var bv = Bits(0)
    var k = 64
    println("before")
    bv[k] = true
    println("never ", bv)
    return 0
}
// out: before
// exit: 1
// err: kelvin: place 64 is out of range: the Bits has 64 bits
