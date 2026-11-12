// v.T, a converter's name after a value, is T(v) (#36): b.i64 of a bool
// is 0 or 1, of a bit too, x.f64 of a number converts it, clamped as
// T(v) clamps (#513), c.i64 of an enum's value its number, "42".i64 of
// text reads it; kc reads them as kelvinc does (#533)
enum color { red, green, blue }
struct holder { on: bool; n: i32 }
let yes():bool { true }
let main():int32 {
    let x:u8 = 200
    let f = 2.5
    let b = true
    var h:holder = {true, 7}
    let bs = $[true, false]
    let c = green
    let t := "17"
    let s = $"42"
    println(b.i64, " ", b.u8, " ", b.f64, " ", h.on.i32, " ", bs[1].i64, " ", (x > 5).i64, " ", yes().u64, " ", x.bits[3].i64)
    println(b.bool, " ", (!b).f32, " ", b.i64.typename, " ", b.u8.typename, " ", b.f64.typename, " ", b.i128, " ", b.uint8, " ", b.i64 + 1)
    println(x.i64, " ", f.i32, " ", x.f64, " ", x.bool, " ", x.i8, " ", h.n.f64, " ", (x + 1).u8, " ", 300.u8)
    println(x.int64.hex, " ", 0.bool, " ", 3.bool.i64)
    println(c.i64, " ", "42".i64, " ", t.u8, " ", "2.5".f64, " ", s.i64, " ", (&s).i64, " ", f.float32.typename)
    return 0
}
// out: 1 1 1.0 1 0 1 1 1
// out: true 0.0 i64 u8 f64 1 1 2
// out: 200 2 200.0 true 127 7.0 201 255
// out: +0xc8 false 1
// out: 1 42 17 2.5 42 42 f32
