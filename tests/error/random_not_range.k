// what an integer type's random takes is a Range of the type (#547), no
// limit alone, as a floating-point type's takes
let main():int32 {
    println(i64.random(6))
    return 0
}
// error: i64.random(r) takes a Range<i64>, as in 'i64.random(1...6)', and this is not one
