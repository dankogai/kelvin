// error: ']' closes nothing: no '[' is open here
// A ] too many is said where it is, as a ) is (#555).
let f(a:[i64]):i64 {
    return a[0]] + 1
}
let main():int32 {
    println(f([3]))
    return 0
}
