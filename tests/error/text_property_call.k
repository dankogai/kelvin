// error: '.i64' takes no arguments: read text in a base with i64(text, base)
main():i32 {
    let s:cstr := "ff"
    println(s.i64(16))
    return 0
}
