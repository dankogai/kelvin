// a union with no tag (#60): union{i:i32, f:f32} where a type goes, one
// type per spelling, its text its spelling
let main():i32 {
    var u:union{i:i32, f:f32} = {.i = 0x3f800000}
    println(u.f, " ", u.typename, " ", u.size)
    var w:union{i:i32, f:f32} = u
    println(w.i, " ", w.cstr)
    return 0
}
// out: 1.0 union{i: i32, f: f32} 4
// out: 1065353216 <union{i: i32, f: f32}>
// c: /* union{i: i32, f: f32} */
// c: union _kv_anon1
