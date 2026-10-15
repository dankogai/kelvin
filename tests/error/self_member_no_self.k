// .x is self.x, and a plain function has no self (#139)
struct point { x: i64; y: i64 }
let getx(p:point):i64 { .x }
let main():i32 { return 0 }
// error: '.x' is self.x in a method, an attribute or a subscript, and a function has no self
