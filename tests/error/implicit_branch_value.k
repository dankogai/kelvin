// error: this value would be dropped: a body returns its value without 'return' only when it is one expression
let sign(x:i64):i64 {
    if x < 0 { -1 } else { 1 }
}
let main():i32 {
    println(sign(-5))
    return 0
}
