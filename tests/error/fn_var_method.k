// a function of a type is a let, never a var (#45): it has no self to
// change, as a var method's is (#318)
struct point { x: float64; y: float64 }
static var point.origin():point { return {0.0, 0.0} }
let main():int32 { return 0 }
// error: a function is a let: write 'static let point.origin(...)', or, for a variable holding a function, 'var f:(T):R := g'
