// .hex, .oct and .bin of a value whose top limb is full, 2 ** 64 - 1 and
// its kin, read back as the value (#518): they showed +0x-1n, the
// magnitude's full top bit read as a sign
let main():int32 {
    let a = 2n ** 64 - 1
    let b = -(2n ** 128 - 1)
    let c = 2n ** 63
    println(a.hex, " ", b.hex, " ", c.bin)
    println(a.oct, " ", b.oct)
    println(BigInt(a.hex, 16) == a, " ", BigInt(b.hex, 16) == b, " ", BigInt(c.bin, 2) == c, " ", BigInt(b.oct, 8) == b)
    return 0
}
// out: +0xffffffffffffffffn -0xffffffffffffffffffffffffffffffffn +0b1000000000000000000000000000000000000000000000000000000000000000n
// out: +0o1777777777777777777777n -0o3777777777777777777777777777777777777777777n
// out: true true true true
