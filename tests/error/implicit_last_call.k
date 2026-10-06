// error: this value would be dropped: a body returns its value without 'return' only when it is one expression
let compute(y:i64):i64 { y * 2 }
let next(x:i64):i64 {
    let y:i64 = x + 1
    compute(y)
}
let main():i32 {
    println(next(1))
    return 0
}
