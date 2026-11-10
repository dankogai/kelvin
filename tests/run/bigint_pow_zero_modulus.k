// pow(b, e, m) of a BigInt takes a modulus other than 0, as Python's (#511)
let main():int32 {
    let a = 12n
    println("before")
    println(pow(a, 3, 0n))
    return 0
}
// out: before
// exit: 1
// err: kelvin: '.pow(e, m)' takes a modulus other than 0
