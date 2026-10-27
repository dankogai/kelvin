// a path names a type defined in the one before it (#389)
struct shape { struct size { w:f64 }, s:size }
let main():i32 {
    var z:shape.nope = {1.0}
    return 0
}
// error: shape has no type 'nope' defined in it
