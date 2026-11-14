// error: expected ')', found '}'
// A ( left open, in a function called before it is written (#505): the
// parser says it where the block ends (#555).
let main():int32 {
    println(f(3))
    return 0
}
let f(a:i64):i64 {
    return ((a + 1) * 2
}
