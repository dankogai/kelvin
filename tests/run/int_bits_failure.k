// an integer's bit place is 0 to its width less 1 (#454): past it the
// program ends, as a Bits's does
let main():int32 {
    var x:i32 = 0
    var k = 32
    println("before")
    x.flip(k)
    println("never ", x)
    return 0
}
// out: before
// exit: 1
// err: kelvin: an integer of 32 bits has bits 0 to 31, and this place is past them
