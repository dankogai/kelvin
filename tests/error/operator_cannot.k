// only + - * / % == != < <= > >= and unary - can be defined (#42)
struct vec { x: float64; y: float64 }
let <<(a:vec, n:int64):vec { (vec){a.x * float64(1 << n), a.y * float64(1 << n)} }
let main():int32 { return 0 }
// error: '<<' cannot be defined: an operator a struct defines is one of + - * / % == != < <= > >=, or unary -
