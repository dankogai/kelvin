// - takes one value or two (#42)
struct vec { x: f64; y: f64 }
-(a:vec, b:vec, c:vec):vec { a }
main():i32 { return 0 }
// error: operator - takes one or two values
