// .x is self.x, and a plain function has no self (#139)
struct point { x: int64; y: int64 }
let getx(p:point):int64 { .x }
let main():int32 { return 0 }
// error: '.x' is self.x in a method, an attribute or a subscript, and a function has no self
