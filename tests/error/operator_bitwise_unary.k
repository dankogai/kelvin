// unary ~ can be defined, and & takes two values: a prefix & is a
// borrow (#502)
struct vec { x: int64 }
let &(a:vec):vec { (vec){a.x} }
let main():int32 { return 0 }
// error: operator & takes two values
