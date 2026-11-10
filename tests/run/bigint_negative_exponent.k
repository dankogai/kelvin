// '**' of a BigInt takes an exponent of 0 or more, as of integers (#511)
let main():int32 {
    let a = 12n
    println("before")
    println(a ** (0 - 2))
    return 0
}
// out: before
// exit: 1
// err: kelvin: '**' of a BigInt takes an exponent of 0 or more
