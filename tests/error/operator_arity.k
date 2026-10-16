// only - takes one value (#42)
struct vec { x: float64; y: float64 }
let +(a:vec):vec { a }
let main():int32 { return 0 }
// error: operator + takes two values
