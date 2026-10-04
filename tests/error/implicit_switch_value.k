// error: this value would be dropped: a body returns its value without 'return' only when it is one expression
name(n:i64):cstr {
    switch (n) {
    case 0:
        "zero"
    default:
        "many"
    }
}
main():i32 {
    println(name(0))
    return 0
}
