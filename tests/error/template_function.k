// error: a template cannot show a function: a function has no text
f():i64 { 1 }
main():i32 {
    println(`${f}`)
    return 0
}
