// a negative e takes the inverse of b mod m, which b and m sharing a factor have none of (#511)
let main():int32 {
    let a = 12n
    println("before")
    println(pow(a, -1, 18n))
    return 0
}
// out: before
// exit: 1
// err: kelvin: '.pow(e, m)' of a negative e takes the inverse of b mod m, and b has none: b and m share a factor
