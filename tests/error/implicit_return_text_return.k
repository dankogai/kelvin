// error: '.hex' text lives in a buffer of this function, which is gone once it returns
hx(x:i64):cstr {
    return x.hex
}
main():i32 {
    println(hx(255))
    return 0
}
