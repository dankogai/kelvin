// a function of a type is called by the type's name, not on a value (#111)
struct point { x: int64; y: i64 }
static let point.origin():Self { (Self){0, 0} }
let main():i32 {
    let p = point.origin()
    println(p.origin().x)
    return 0
}
// error: 'origin' is a function of point, not a method: call it as point.origin(...)
