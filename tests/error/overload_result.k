// overloads differ in their parameter types, not only in their results (#41)
let half(n:i64):i64 { n / 2 }
let half(n:i64):f64 { f64(n) / 2.0 }
let main():i32 { return 0 }
// error: 'half' is declared with these parameter types already, with another result: overloads differ in their parameter types
