// fallthrough checks no label, so the value a case binds would be none (#386)
enum shape { none; circle: float64 }
let main():int32 {
    let s = shape.none
    switch s {
    case none: fallthrough
    case circle(r): println(r)
    }
    return 0
}
// error: 'fallthrough' cannot go on into a case that binds a value, 'case circle(r):'
