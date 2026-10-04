// error: this value would be dropped: a body returns its value without 'return' only when it is one expression
twice(x:i64):i64 { x * 2 }
pick(n:i64):i64 {
    switch (n) {
    case 0:
        return 0
    default:
        twice(n)
    }
}
main():i32 {
    println(pick(1))
    return 0
}
