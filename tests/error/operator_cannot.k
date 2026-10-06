// only + - * / % == != < <= > >= and unary - can be defined (#42)
struct vec { x: f64; y: f64 }
<<(a:vec, n:i64):vec { (vec){a.x * f64(1 << n), a.y * f64(1 << n)} }
let main():i32 { return 0 }
// error: '<<' cannot be defined: an operator a struct defines is one of + - * / % == != < <= > >=, or unary -
