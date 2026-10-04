// error: this value would be dropped: a body returns its value without 'return' only when it is one expression
area(w:i64, h:i64):i64 {
    let unused:i64 = 1
    w * h
}
main():i32 {
    println(area(2, 3))
    return 0
}
