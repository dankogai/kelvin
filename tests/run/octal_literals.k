// 0o52, an octal number (#561): the text n.oct writes, which pastes
// back; C's own, 052, is read as before, and both are the same number.
// With an n it is a BigInt, 0o17n
#import <BigInt>
let main():int32 {
    let b:u8 = 255
    let h:i16 = -42
    println(0o52, " ", 0O52, " ", -0o52, " ", +0o52, " ", 0o0, " ", 0o777, " ", 0o52 == 052, " ", 0o52.typename)
    // what .oct writes is read back
    println(b.oct, " ", h.oct, " ", 0o377 == b, " ", -0o52 == h, " ", 0o52.oct, " ", 0o52.hex, " ", (0o17:u8).bin)
    // wherever a number is: a declared type, an inferred one, an array's size and elements, an index
    let k:u8 = 0o377
    var x = 0o17
    let a:[i32](0o3) = [0o1, 0o2, 0o10]
    println(k, " ", x, " ", x.typename, " ", a[0o2], " ", 0o10 + 0o10, " ", 2 ** 0o3, " ", 0o7...0o11)
    println(0o1777777777777777777777, " ", 0o777777777777777777777, " ", 0o52 as f64, " ", `${0o52}`, " ", 0o17.cstr)
    switch x {
    case 0o17: println("fifteen")
    default: println("other")
    }
    // a BigInt's, of any length, and its .oct read back
    println(0o17n, " ", (0o17n).typename, " ", -0o17n, " ", 0o17n.oct, " ", 0o17n == 15n, " ", 0O17n)
    println(0o777777777777777777777777777777n, " ", (1n << 100).oct, " ", 0o2000000000000000000000000000000000n == 1n << 100)
    // and the converters read the text, as they did
    println(i64("0o17", 8), " ", i64(h.oct, 8), " ", BigInt("0o17", 8))
    return 0
}
// out: 42 42 -42 42 0 511 true i32
// out: 0o377 -0o52 true true +0o52 +0x2a 0b1111
// out: 255 15 i64 8 16 8 7...9
// out: 18446744073709551615 9223372036854775807 42.0 42 15
// out: fifteen
// out: 15n BigInt -15n +0o17n true 15n
// out: 1237940039285380274899124223n +0o2000000000000000000000000000000000n true
// out: 15 -42 15n
