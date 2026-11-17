// error: a computed attribute of a type is read and never set: write 'static let origin:R { ... }', or 'static var origin = v' for a stored one
// a computed attribute of a type has no setter, so it is a let (#595)
struct point { x: int64 }
extend point { static var origin:Self { (point){0} } }
let main():int32 { return 0 }
