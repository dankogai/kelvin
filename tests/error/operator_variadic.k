// an operator takes its values, no more (#42)
struct vec { x: float64; y: float64 }
let -(a:vec, ...):vec { (vec){-a.x, -a.y} }
let main():int32 { return 0 }
// error: operator - takes one or two values
