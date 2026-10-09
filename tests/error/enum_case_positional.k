// a case is written by its name (#61)
enum shape { none; circle: f64 }
let main():i32 {
    var s:shape = {1.0}
    return 0
}
// error: a case of shape is written by its name: {.none}
