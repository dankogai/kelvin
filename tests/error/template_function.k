// error: a template cannot show a function: a function has no text
let f():i64 { 1 }
let main():i32 {
    println(`${f}`)
    return 0
}
