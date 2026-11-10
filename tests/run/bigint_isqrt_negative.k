// a negative BigInt has no integer square root (#511)
let main():int32 {
    let a = 12n
    println("before")
    println((-a).isqrt())
    return 0
}
// out: before
// exit: 1
// err: kelvin: '.isqrt()' of a negative BigInt has none
