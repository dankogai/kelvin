// Range<T> is of integers, i8 to i64 or u8 to u64 (#373)
let main():int32 {
    let r:Range<float64> = 0..<3
    return 0
}
// error: a Range is of integers, i8 to i64 or u8 to u64, and this is f64; convert its bounds, as in 'i64(n)'
