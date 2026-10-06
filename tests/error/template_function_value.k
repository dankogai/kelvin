// error: a template cannot show a function: a function has no text
let square(x:i64):i64 { x * x }
let main():i32 {
    let f:(i64):i64 := square
    println(`${f}`)
    return 0
}
