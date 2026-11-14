// error: ')' closes nothing: no '(' is open here
// A ) too many is said where it is (#555).
let f(a:i64):i64 {
    return (a + 1)) * 2
}
let main():int32 {
    println(f(3))
    return 0
}
