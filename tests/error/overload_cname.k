// two functions may not share a name in C (#41)
let twice(n:i64):i64 { n * 2 }
let twice(x:f64):f64 { x * 2.0 }
let twice__i64(n:i64):i64 { n }
let main():i32 { return 0 }
// error: this function and the one at line 2 would both be named twice__i64 in C: rename one
