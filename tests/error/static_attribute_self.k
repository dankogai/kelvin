// error: an attribute of a type has no self: 'point.origin' is read by the type's name, with no value before it; an attribute of a value, 'let point.name:R { ... }', has one
// a computed attribute of a type has no self (#595)
struct point { x: int64 }
extend point { static let origin:Self { self } }
let main():int32 {
    println(point.origin.x)
    return 0
}
