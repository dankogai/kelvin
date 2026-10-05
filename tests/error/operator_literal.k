// a literal has its type in the message too (#42)
struct vec { x: f64; y: f64 }
+(a:vec, b:vec):vec { (vec){a.x + b.x, a.y + b.y} }
main():i32 {
    let v:vec = {1.0, 2.0}
    let w:vec = v + 5
    return 0
}
// error: no operator + takes vec and i64: define one, as in '+(a:vec, b:i64):... { ... }'
