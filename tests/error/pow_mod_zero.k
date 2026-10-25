// b.pow(e, m) takes a modulus other than 0, as Python's pow(b, e, m) (#380)
let main():int32 {
    println(3.pow(4, 0))
    return 0
}
// error: '.pow(e, m)' takes a modulus other than 0
