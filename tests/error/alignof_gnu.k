// GNU C's __alignof__ is refused, with Kelvin's spellings (#395)
let main():i32 {
    println(__alignof__(i64))
    return 0
}
// error: '__alignof__' is a C compiler keyword; use alignof(T) or x.align
