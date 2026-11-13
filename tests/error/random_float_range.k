// a floating-point type's random takes numbers, no range (#547): a Range
// is of integers
let main():int32 {
    println(f64.random(1...6))
    return 0
}
// error: f64.random(start, lim) takes numbers, and this is Range<i64>
