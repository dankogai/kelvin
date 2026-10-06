// an operator a struct defines is declared with let too (#45)
struct vec { x: f64; y: f64 }
+(a:vec, b:vec):vec { (vec){a.x + b.x, a.y + b.y} }
let main():i32 { return 0 }
// error: a function is declared with let: write 'let +(...)'
