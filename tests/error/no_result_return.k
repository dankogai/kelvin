// a function with no result returns no value (#427), which kelvinc says
// at the value, not C at its return
// error: 'f' has no result, so it returns no value: write its result's type, as in 'let f(...):T', or 'return' alone
let f(n:int64) {
    if n < 0 { return false }
    println(n)
}
let main():int32 {
    f(1)
    return 0
}
