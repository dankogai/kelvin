// error: 'point.origin' is computed, and never set: a stored attribute, 'static var point.origin = v', is
// a computed attribute of a type is not assigned (#595)
struct point { x: int64 }
extend point { static let origin:Self { (point){0} } }
let main():int32 {
    point.origin = (point){1}
    return 0
}
