// a case that binds a value stands alone (#119)
enum shape { none; dot: i64; name: String }
let main():i32 {
    var s = shape.dot(1)
    switch s {
    case dot(n), name: println("either")
    case none: println("none")
    }
    return 0
}
// error: a case that binds a value, 'case dot(n):', stands alone: it cannot share a body with another case
