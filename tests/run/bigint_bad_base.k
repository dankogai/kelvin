// a BigInt's text has a base from 2 to 36 (#507)
let main():int32 {
    let a = BigInt(255)
    println(a.text(16))
    println(a.text(37))
    return 0
}
// out: ff
// exit: 1
// err: kelvin: a BigInt's text has a base from 2 to 36, and this is 37
