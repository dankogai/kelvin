// error: a template's text lives in this function's block, which is gone once it returns
let label(n:i64):cstr { `#${n}`.cstr }
let main():i32 {
    println(label(1))
    return 0
}
