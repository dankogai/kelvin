// a String takes text it can check, not a borrow of a Bytes (#55)
let main():i32 {
    var s = String("x")
    var b = Bytes("y")
    s += &b
    return 0
}
// error: a String takes text, not a borrow of a Bytes, which may not be UTF-8: give 'b.string()', or 'b.cstr' up to a NUL
