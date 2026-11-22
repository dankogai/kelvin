// a BigInt of a number past u64 is written with its n (#678)
let main():int32 {
    let b = BigInt(123456789012345678901234567890)
    println(b)
    return 0
}
// error: integer literal '123456789012345678901234567890' is too large: u64's greatest is 18446744073709551615; a BigInt is written '123456789012345678901234567890n'
