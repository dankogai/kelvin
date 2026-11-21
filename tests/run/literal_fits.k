// what #663 leaves as it was: each type's least and greatest, a float
// with no fraction where an integer goes, hex, and an i64 that fits
let main():int32 {
    let a:u8 = 255
    let b:i8 = -128
    let c:i64 = 9223372036854775807
    let d:u64 = 18446744073709551615
    let e:i64 = 2.0
    let f:i64 = 1e3
    let g:u8 = 0xff
    println(a, " ", b, " ", c, " ", d, " ", e, " ", f, " ", g)
    return 0
}
// out: 255 -128 9223372036854775807 18446744073709551615 2 1000 255
