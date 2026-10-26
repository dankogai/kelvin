// a Bits shifts by 0 to 63 (#387), as a bit's place is: past it the program ends
let main():int32 {
    var k = 64
    println("before")
    let b = Bits(1) << k
    println("never ", b)
    return 0
}
// out: before
// exit: 1
// err: kelvin: a Bits shifts by 0 to 63, and this is past it
