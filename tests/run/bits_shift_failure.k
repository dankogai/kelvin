// a Bits shifts by 0 or more places (#387, #455): a negative shift ends
// the program
let main():int32 {
    var k = -1
    println("before")
    let b = Bits(1) << k
    println("never ", b)
    return 0
}
// out: before
// exit: 1
// err: kelvin: a Bits shifts by 0 or more places, and this is less
