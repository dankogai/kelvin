// error: 'point.origin' is an attribute of the type: read it as 'point.origin', with no parentheses
// a computed attribute of a type is read, not called (#595)
struct point { x: int64 }
extend point { static let origin:Self { (point){0} } }
let main():int32 {
    println(point.origin().x)
    return 0
}
