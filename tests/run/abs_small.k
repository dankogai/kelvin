// x.abs (#381) of i8, i16 and i128, of its own type: i8's least stays
// -128; -x of a small one is an i32, as C promotes it
let main():int32 {
    let m:int8 = -128
    let k:int8 = -7
    let s:int16 = -300
    let w:int128 = -7
    println(m.abs, " ", k.abs, " ", k.abs.size, " ", s.abs, " ", s.abs.size, " ", i64(w.abs), " ", w.abs.size)
    println((-k).abs, " ", (-k).abs.size, " ", (k * 100).abs)
    let f:float32 = -1.5
    println(f.abs.size, " ", (f * 2.0).abs.size)
    return 0
}
// out: -128 7 1 300 2 7 16
// out: 7 4 700
// out: 4 8
