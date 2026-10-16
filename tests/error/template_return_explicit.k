// error: a template's text lives in this function's block, which is gone once it returns
let label(n:int64):cstr {
    return `#${n}`
}
let main():int32 {
    println(label(1))
    return 0
}
