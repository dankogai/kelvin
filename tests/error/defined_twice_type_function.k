// two definitions of one function of a type (#646)
struct point { x:f64; y:f64 }
static let point.unit():point { return {1.0, 0.0} }
static let point.unit():point { return {0.0, 1.0} }
let main():int32 { println(point.unit().x); return 0 }
// error: 'point.unit' is defined already (line 3), with these parameter types: a function is defined once, and its overloads differ in their parameter types
