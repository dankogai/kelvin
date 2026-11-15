// +v is the value of a type with a unary - (#563), and vec has none
struct vec { x: float64; y: float64 }
let -(a:vec, b:vec):vec { (vec){a.x - b.x, a.y - b.y} }
let main():int32 {
    let v:vec = {1.0, 2.0}
    let w:vec = +v
    return 0
}
// error: '+' gives the value of a number, or of a type with a unary '-', and no operator - takes vec: define one, as in 'let -(a:vec):... { ... }'
