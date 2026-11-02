// error: a template's text lives until this block ends, and 't' outlives it
let f(var t:cstr):i32 {
    if true { t := `${1}` }
    println(t)
    return 0
}
let main():i32 { return f("a") }
