// numbers keep C's operators (#42)
let +(a:i64, b:i64):i64 { a - b }
let main():i32 { return 0 }
// error: an operator is for a Kelvin struct or union: at least one of its values must be one
