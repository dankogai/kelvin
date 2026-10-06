// -v is an operator of its own (#42)
struct vec { x: f64; y: f64 }
let -(a:vec, b:vec):vec { (vec){a.x - b.x, a.y - b.y} }
let main():i32 {
    let v:vec = {1.0, 2.0}
    let w:vec = -v
    return 0
}
// error: no operator - takes vec: define one, as in 'let -(a:vec):... { ... }'
