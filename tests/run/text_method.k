// T.cstr() defines a struct or union text as one template (#53): v.cstr,
// ${v} and the derived text of a struct that holds a T use it, and its
// buffer is sized from the template
struct vector2d { x: f64; y: f64 }
let vector2d.cstr():cstr {
    `(${self.x}, ${self.y})`
}
struct line { a: vector2d; b: vector2d }
union bits { u: u64; f: f64 }
let bits.cstr():cstr { `bits ${self.u.hex}` }
let main():i32 {
    let v:vector2d = {1.5, -2.0}
    let l:line = {{0.0, 0.0}, v}
    var b:bits = {.f = 1.0}
    println(v.cstr, " ", `${v}`, " ", l.cstr, " ", b.cstr, " ", v.cstr.count, " ", v.cstr.typename)
    return 0
}
// out: (1.5, -2.0) (1.5, -2.0) {a: (0.0, 0.0), b: (1.5, -2.0)} bits 0x3ff0000000000000 11 cstr
// c: enum { _kv_vector2d_cstr_size = sizeof "(" ", " ")" + 24 + 24 };
// c: static inline uint8_t *_kv_vector2d_cstr(struct vector2d self, uint8_t *_kv_buf)
// c: kv_cstr_put(_kv_buf,
