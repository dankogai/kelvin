// a switch on an enum with values lists every case, or has a default (#63)
enum shape { none; circle: f64; rect: {w:f64, h:f64} }
let main():i32 {
    var s:shape
    switch s {
    case none:
        println(0)
    }
    return 0
}
// error: switch on shape is not exhaustive: circle, rect are missing; write every case, or add 'default:'
