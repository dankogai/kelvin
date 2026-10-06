// a method is a let, never a var (#45)
struct point { x: f64; y: f64 }
var point.norm():f64 { self.x * self.x + self.y * self.y }
let main():i32 { return 0 }
// error: a function is a let: write 'let point.norm(...)', or, for a variable holding a function, 'var f:(T):R := g'
