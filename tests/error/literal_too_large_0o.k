// Kelvin's octal past u64 (#678)
let main():int32 {
    let x = 0o2000000000000000000000
    println(x)
    return 0
}
// error: integer literal '0o2000000000000000000000' is too large: u64's greatest is 18446744073709551615; a BigInt is written '0o2000000000000000000000n'
