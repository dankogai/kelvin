// error: which is gone once it returns: the caller takes the text itself, as in 'println(x.hex)'
hx(x:i64):cstr { x.hex }
main():i32 {
    println(hx(255))
    return 0
}
