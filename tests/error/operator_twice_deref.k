// x op= y is x = x op y, so x may not hold a call, also under ^ (#42)
struct vec { x: f64; y: f64 }
let +(a:vec, b:vec):vec { (vec){a.x + b.x, a.y + b.y} }
var store:vec = {0.0, 0.0}
let at():vec^ { &store }
let main():i32 {
    at()^ += (vec){1.0, 2.0}
    return 0
}
// error: with an operator a struct defines, 'x += y' is 'x = x + y', which evaluates x twice, so x may not hold a call
