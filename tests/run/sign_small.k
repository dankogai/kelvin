// x.sign (#382) of i8, i16 and i128 and an f32, of its own type
let main():int32 {
    let k:int8 = -7
    let s:int16 = 300
    let w:int128 = -7
    let f:float32 = -0.0
    println(k.sign, " ", k.sign.size, " ", s.sign, " ", s.sign.size, " ", i64(w.sign), " ", w.sign.size, " ", f.sign, " ", f.sign.size)
    return 0
}
// out: -1 1 1 2 -1 16 -1.0 4
