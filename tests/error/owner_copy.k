// an owner is never copied by = (#54, O3)
let main():i32 {
    var a = Bytes("x")
    var b = a
    return 0
}
// error: an owner is not copied by '=' (#54): copy its bytes with 'a'.copy(), or borrow it with ':= &a'
