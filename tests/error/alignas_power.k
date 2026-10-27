// an alignment is a power of two (#396), as C's
alignas(3) var x:i64
let main():i32 { return 0 }
// error: an alignment is a power of two, as C's: 1, 2, 4, 8, 16, ...
