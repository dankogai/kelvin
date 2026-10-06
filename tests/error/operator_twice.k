// x op= y with a struct's operator is x = x op y (#42)
struct vec { x: f64; y: f64 }
let +(a:vec, b:vec):vec { (vec){a.x + b.x, a.y + b.y} }
var at:i64 = 0
let next():i64 { at += 1; return at - 1 }
let main():i32 {
    var vs:vec[2] = [{1.0, 2.0}, {3.0, 4.0}]
    vs[next()] += vs[1]
    return 0
}
// error: with an operator a struct defines, 'x += y' is 'x = x + y', which evaluates x twice, so x may not hold a call
