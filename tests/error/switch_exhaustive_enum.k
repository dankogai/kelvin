// a switch on an enum with values lists every case, or has a default (#63)
enum shape { none; circle: float64; rect: {w:float64, h:float64} }
let main():int32 {
    var s:shape
    switch s {
    case none:
        println(0)
    }
    return 0
}
// error: switch on shape is not exhaustive: circle, rect are missing; write every case, or add 'default:'
