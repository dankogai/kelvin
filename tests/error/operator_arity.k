// only - takes one value (#42)
struct vec { x: f64; y: f64 }
let +(a:vec):vec { a }
let main():i32 { return 0 }
// error: operator + takes two values
