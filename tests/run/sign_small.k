// x.sign (#382) of i8, i16 and i128, of its own type; of an f32 a bool? (#383)
let main():int32 {
    let k:int8 = -7
    let s:int16 = 300
    let w:int128 = -7
    let f:float32 = -0.0
    println(k.sign, " ", k.sign.size, " ", s.sign, " ", s.sign.size, " ", i64(w.sign), " ", w.sign.size, " ", f.sign)
    return 0
}
// out: -1 1 1 2 -1 16 some(false)
