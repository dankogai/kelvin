// error: bool(...) reads no text, and this text is never nullptr, so it would always be true
let main():int32 {
    println(bool("true"))
    return 0
}
