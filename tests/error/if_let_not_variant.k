// if let takes an Optional or a Result (#74)
let main():i32 {
    var n:i64 = 1
    if let x = n { }
    return 0
}
// error: 'if let' takes an Optional or a Result, and this is i64
