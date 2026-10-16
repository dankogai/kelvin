// a function of a type has no self (#111)
struct point { x: int64; y: int64 }
static let point.bad():int64 { self.x }
let main():int32 { return 0 }
// error: a function of a type has no self: 'point.bad' is called as point.bad(...), with no value before it
