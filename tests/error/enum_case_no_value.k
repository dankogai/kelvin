// a case with no value cannot be read (#61)
enum shape { none; circle: f64 }
let main():i32 {
    var s:shape = {.none}
    println(s.none)
    return 0
}
// error: case 'none' of shape carries no value: test it with '.is(none)', or set it with {.none}
