// x op= y is x = x op y, so x may not hold a call, also in ?: (#42)
struct vec { x: f64; y: f64 }
let *(a:vec, k:f64):vec { (vec){a.x * k, a.y * k} }
var n:i64 = 0
let next():i64 {
    n += 1
    return n
}
let main():i32 {
    var vs:vec[3] = {{1.0, 1.0}, {2.0, 2.0}, {3.0, 3.0}}
    vs[n > 0 ? next() : 0] *= 2.0
    return 0
}
// error: with an operator a struct defines, 'x *= y' is 'x = x * y', which evaluates x twice, so x may not hold a call
