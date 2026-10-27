// restrict (#393): a pointer's own qualifier, after its ^ as `u8^ const`
// is, C's T *restrict: the programmer's promise that nothing else reaches
// what it points to, which kelvinc cannot check
let copy(dst:u8^ restrict, src:const u8^ restrict, n:i64):() {
    for i in 0..<n { dst[i] = src[i] }
}
let add(a:i64^ restrict, b:const i64^ restrict):() { a^ += b^ }
let first(s:cstr restrict):u8 { return s[0] }
let main():i32 {
    var buf = [u8](8)
    let text:cstr := "kelvin"
    copy(&buf[0], text, 7)
    var x = 1
    let y = 41
    add(&x, &y)
    var p:u8^ restrict := &buf[0]
    let q:u8^ := p
    println(buf[0], " ", x, " ", first(text), " ", q[1], " ", p.typename)
    println(copy.typename)
    return 0
}
// out: 107 42 107 101 u8^ restrict
// out: (u8^ restrict, const u8^ restrict, i64)
// c: void copy(uint8_t *const restrict dst, const uint8_t *const restrict src, const int64_t n)
// c: uint8_t *restrict p = &buf[0];
