// uchr(x) of a pointer to no text is an error, where C read the
// integer's bytes as text (#494)
let main():int32 {
    var n:i32 = 65
    println(uchr(&n))
    return 0
}
// error: uchr(x) takes an integer, a uchr or text, and this is i32^
