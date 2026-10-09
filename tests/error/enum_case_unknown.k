// a case is one of the enum's (#61)
enum shape { none; circle: f64 }
let main():i32 {
    var s:shape = {.square = 1.0}
    return 0
}
// error: shape has no case 'square': the cases are none, circle
