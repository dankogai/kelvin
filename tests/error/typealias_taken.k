// an alias is a new name (#149)
struct point { x: int64; y: i64 }
typealias point = f64
let main():i32 { return 0 }
// error: 'point' is declared already: an alias is a new name
