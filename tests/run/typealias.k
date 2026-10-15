// typealias A = T (#149): from there on A is T wherever a name is read,
// as a type, before a dot, as a converter, as an extend's; the aliases
// of math.k, complex64 for c64 (#150); and the full names of the number
// types, int64 for i64, uint8 for u8, float32 for f32 (#151)
#import <math>
struct point { x: int64; y: i64 }
typealias pt = point
typealias real = f64
typealias count = int32
extend pt {
    static let of(x:i64, y:i64):Self { return {x, y} }
    let sum():i64 { .x + .y }
}
let twice(x:real):real { x * 2.0 }
let main():i32 {
    let p:pt = pt.of(3, 4)
    let q = (pt){1, 2}
    var n:count = 7
    println(p.sum(), " ", q, " ", p.typename, " ", twice(real(1.5)), " ", real.pi == f64.pi, " ", n.typename)
    let z:complex64 = complex64(1.0, 2.0)
    println(z.typename, " ", z.conj(), " ", abs(complex32(3.0:f32, 4.0:f32)), " ", (1.0.i).typename)
    let a:int64 = 5
    let b:uint8 = 200
    let c:float32 = 1.5
    println(a.typename, " ", b.typename, " ", c.typename, " ", int32(2.9), " ", float64(3), " ", sizeof(uint16), " ", float64.e)
    return 0
}
// out: 7 {x: 1, y: 2} point 3.0 true i32
// out: c64 {real: 1, imag: -2} 5.0 c64
// out: i64 u8 f32 2 3.0 2 2.718281828459045
