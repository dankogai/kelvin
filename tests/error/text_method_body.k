// the body of T.cstr() is one template literal, whose text goes into the
// caller's buffer (#53)
struct p { x: i64 }
let p.cstr():cstr {
    var s:cstr := "x"
    s
}
let main():i32 { return 0 }
// error: the body of '.cstr' is one template literal, as in '{ `(${self.x}, ${self.y})` }': its text goes into the caller's buffer, which kelvinc sizes from the template (#53)
