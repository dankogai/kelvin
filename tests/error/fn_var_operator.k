// an operator is a let, never a var (#45)
struct vec { x: f64; y: f64 }
var +(a:vec, b:vec):vec { (vec){a.x + b.x, a.y + b.y} }
let main():i32 { return 0 }
// error: a function is a let: write 'let +(...)', or, for a variable holding a function, 'var f:(T):R := g'
