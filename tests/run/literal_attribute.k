// an attribute of an integer, read on a literal or on arithmetic of
// literals, takes it as the i64 it is (#548), as a method does (#538):
// bare, C read 7 as an int, which no attribute of an i64 was of, and
// 7.half was C's error
extend i64 {
    let half:f64 { self as f64 / 2.0 }
    let sq:i64 { self * self }
    let twice():i64 { self * 2 }
}
extend f64 {
    let half:f64 { self / 2.0 }
}
extend i32 {
    let sq:i32 { self * 3 }
}
let main():int32 {
    let n:i32 = 2
    println(7.half, " ", 7.sq, " ", (-7).sq, " ", (1 << 20).sq, " ", (65536 * 65536).half, " ", 7.sq.sq, " ", 3.twice().sq)
    println(2.5.half, " ", 7.half.half, " ", n.sq, " ", 7.sq.typename, " ", (0x10).sq, " ", 7.hex, " ", 7.abs, " ", 255.bits.count)
    return 0
}
// out: 3.5 49 49 1099511627776 2147483648.0 2401 36
// out: 1.25 1.75 6 i64 256 +0x7 7 64
