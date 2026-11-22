// what #678 leaves as it was: u64's greatest where a u64 is written, of
// every base, C's octal too, which kc read as decimal digits; i64's least
// and greatest inferred; and a BigInt literal past u64
let main():int32 {
    let a:u64 = 18446744073709551615
    let b:u64 = 0xffff_ffff_ffff_ffff
    let c:u64 = 0o1777777777777777777777
    let d:u64 = 01777777777777777777777
    let e = 9223372036854775807
    let f = -9223372036854775808
    let g = 99999999999999999999n
    let h:u8 = 0377
    println(a, " ", b, " ", c, " ", d, " ", h)
    println(e, " ", f, " ", g)
    return 0
}
// out: 18446744073709551615 18446744073709551615 18446744073709551615 18446744073709551615 255
// out: 9223372036854775807 -9223372036854775808 99999999999999999999n
