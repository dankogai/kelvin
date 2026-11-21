// _ among a literal's digits (#671), as Swift has it: after a digit or
// another _, in the integer part, the fraction and the exponent, of every
// base, and of a BigInt's literal; 1_000 is 1000, as written without them
let main():int32 {
    let a:i32 = 0x7fff_ffff
    let b = 1_000_000
    let c = 1__0
    let d = 1_
    let e = 1_000.000_1
    let f = 1e1_0
    println(a, " ", b, " ", c, " ", d, " ", e, " ", f)
    let g = 0b1010_1010
    let h = 0o7_7
    let i = 0x1_0.8p1
    let j = 1_000n
    let k = 0xff_ffn
    let l = 1_e3
    println(g, " ", h, " ", i, " ", j, " ", k, " ", l)
    println(1_000.hex, " ", 2_5.5.typename, " ", a == 2147483647, " ", 0_10)
    let u:u8 = 2_55
    println(u, " ", i64("1_000"), " ", u64.max == 0xffff_ffff_ffff_ffff)
    return 0
}
// out: 2147483647 1000000 10 1 1000.0001 10000000000.0
// out: 170 63 33.0 1000n 65535n 1000.0
// out: +0x3e8 f64 true 8
// out: 255 1 true
