// - takes one value or two (#42)
struct vec { x: float64; y: float64 }
let -(a:vec, b:vec, c:vec):vec { a }
let main():int32 { return 0 }
// error: operator - takes one or two values
