// error: '.hex' text lives in a buffer of this function, which is gone once it returns
let hx(x:i64):cstr {
    return x.hex
}
let main():i32 {
    println(hx(255))
    return 0
}
