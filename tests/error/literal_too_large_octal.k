// C's octal past u64: its BigInt is 0o's, as a BigInt has no leading 0 (#678)
let main():int32 {
    let x = 02000000000000000000000
    println(x)
    return 0
}
// error: integer literal '02000000000000000000000' is too large: u64's greatest is 18446744073709551615; a BigInt is written '0o2000000000000000000000n'
