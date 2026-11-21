// a literal shifted by its width or more is kelvinc's error (#665), where C
// only warned: a bare 1 is C's int here, 32 bits
let main():int32 {
    let x:i64 = 1 << 63
    println(x)
    return 0
}
// error: '<< 63' shifts an i32, a literal and so C's int here, by 63, its width or more, which C leaves undefined: write '1:i64 << 63'
