// past u64 in hex, quoted as written (#678)
let main():int32 {
    let x:u64 = 0x1_0000_0000_0000_0000
    println(x)
    return 0
}
// error: integer literal '0x1_0000_0000_0000_0000' is too large: u64's greatest is 18446744073709551615; a BigInt is written '0x1_0000_0000_0000_0000n'
