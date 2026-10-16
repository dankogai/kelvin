// an operator gives a value (#42)
struct vec { x: float64; y: float64 }
let +(a:vec, b:vec) { }
let main():int32 { return 0 }
// error: operator + has no result: write its type, as in 'let +(...):T'
