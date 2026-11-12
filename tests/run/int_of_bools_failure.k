// T(bools) of an integer type is of its width of bools or fewer (#530):
// more end the program
let main():int32 {
    var bs = u8(255).bits
    println(u8(bs))
    bs.append(false)
    println(u16(bs))
    println(u8(bs))
    println("never")
    return 0
}
// out: 255
// out: 255
// exit: 1
// err: kelvin: an integer of 8 bits is of 8 bools or fewer, and this [bool] has more
