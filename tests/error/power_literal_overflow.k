// a power of two literals is an i64, as a literal is (#380)
let main():int32 {
    println(2 ** 63)
    return 0
}
// error: '**' of two literals is an i64, as a literal is, and this is past its largest: raise a floating-point number, as in '2.0 ** 64', or convert, as in 'u64(2) ** 63'
