// an extern function of a type is a let too (#45), and kc stops at its
// error (#624)
struct T { a: i64 }
extern var T.f() { }
let main():int32 { return 0 }
// error: a function is a let: write 'extern let T.f(...)', or, for a variable holding a function, 'var f:(T):R := g'
