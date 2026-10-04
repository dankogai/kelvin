// error: a body returns its value without 'return' only when it is one expression
dbl(x:i64):i64 {
    let y:i64 = x * 2
    y
}
main():i32 {
    println(dbl(21))
    return 0
}
