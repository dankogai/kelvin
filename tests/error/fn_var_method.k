// a method is a let, never a var (#45)
struct point { x: float64; y: f64 }
var point.norm():f64 { .x * .x + .y * .y }
let main():i32 { return 0 }
// error: a function is a let: write 'let point.norm(...)', or, for a variable holding a function, 'var f:(T):R := g'
