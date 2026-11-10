// a BigInt divided by zero ends the program, said, as a failed check does
// (#174, #507)
let main():int32 {
    let a = BigInt(7)
    println("before")
    println(a / (a - 7))
    return 0
}
// out: before
// exit: 1
// err: kelvin: division of a BigInt by zero
