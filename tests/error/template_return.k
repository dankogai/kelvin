// error: a template's text lives in this function's block, which is gone once it returns
label(n:i64):cstr { `#${n}` }
main():i32 {
    println(label(1))
    return 0
}
