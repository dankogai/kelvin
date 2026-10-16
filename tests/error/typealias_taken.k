// an alias is a new name (#149)
struct point { x: int64; y: int64 }
typealias point = float64
let main():int32 { return 0 }
// error: 'point' is declared already: an alias is a new name
