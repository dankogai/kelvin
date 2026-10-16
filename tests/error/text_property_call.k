// error: '.i64' takes no arguments: read text in a base with i64(text, base)
let main():int32 {
    let s:cstr := "ff"
    println(s.int64(16))
    return 0
}
