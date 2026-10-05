// an operator takes its values, no more (#42)
struct vec { x: f64; y: f64 }
-(a:vec, ...):vec { (vec){-a.x, -a.y} }
main():i32 { return 0 }
// error: operator - takes one or two values
