// a nested type (#389) is named by its path outside the struct it is
// defined in, as in Swift
struct shape { struct size { w:f64 }, s:size }
let main():i32 {
    var z:size = {1.0}
    return 0
}
// error: 'size' is defined in shape, and named shape.size outside it
