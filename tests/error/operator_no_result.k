// an operator gives a value (#42)
struct vec { x: f64; y: f64 }
let +(a:vec, b:vec) { }
let main():i32 { return 0 }
// error: operator + has no result: write its type, as in 'let +(...):T'
