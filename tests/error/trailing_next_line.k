// error: a trailing function starts on the line of the call's ')': on the next line, '{' starts a block
var total:i64 = 0
let each(n:i64, f:(i64)) {
    for i in 0..<n {
        f(i)
    }
}
let main():i32 {
    each(3)
    {
        total += $0
    }
    return 0
}
