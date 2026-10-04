// error: a trailing function starts on the line of the call's ')', and on the next line '{' starts a block
var total:i64 = 0
each(n:i64, f:(i64)) {
    for i in 0..<n {
        f(i)
    }
}
main():i32 {
    each(3)
    {
        total += $0
    }
    return 0
}
