// only + - * / % ** == != < <= > >= & | ~ << >>, unary - and ~, and x op=
// y of them can be defined (#42, #380, #502, #518): && is no operator a
// struct defines
struct vec { x: float64; y: float64 }
let &&(a:vec, b:vec):bool { a.x != 0.0 && b.x != 0.0 }
let main():int32 { return 0 }
// error: '&&' cannot be defined: an operator a struct defines is one of + - * / % ** == != < <= > >= & | ~ << >>, unary - and ~, or x op= y of one of them (#518)
