// b.pow takes an exponent, or an exponent and a modulus (#380)
let main():int32 {
    let n:int64 = 3
    println(n.pow(1, 2, 3))
    return 0
}
// error: '.pow' of an integer takes an exponent, '.pow(e)', or an exponent and a modulus, '.pow(e, m)'
