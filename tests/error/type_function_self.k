// a function of a type has no self (#111)
struct point { x: i64; y: i64 }
static let point.bad():i64 { self.x }
let main():i32 { return 0 }
// error: a function of a type has no self: 'point.bad' is called as point.bad(...), with no value before it
