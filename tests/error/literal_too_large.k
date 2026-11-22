// an integer literal past u64's greatest, which C has no type for: kelvinc's error (#678)
let main():int32 {
    let x = 99999999999999999999
    println(x)
    return 0
}
// error: integer literal '99999999999999999999' is too large: u64's greatest is 18446744073709551615; a BigInt is written '99999999999999999999n'
