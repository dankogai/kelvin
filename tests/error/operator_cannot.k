// only + - * / % ** == != < <= > >= & | ~ << >> and unary - and ~ can be
// defined (#42, #380, #502): && is no operator a struct defines
struct vec { x: float64; y: float64 }
let &&(a:vec, b:vec):bool { a.x != 0.0 && b.x != 0.0 }
let main():int32 { return 0 }
// error: '&&' cannot be defined: an operator a struct defines is one of + - * / % ** == != < <= > >= & | ~ << >>, or unary - and ~
