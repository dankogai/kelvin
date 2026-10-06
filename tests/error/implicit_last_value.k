// error: a body returns its value without 'return' only when it is one expression
let dbl(x:i64):i64 {
    let y:i64 = x * 2
    y
}
let main():i32 {
    println(dbl(21))
    return 0
}
