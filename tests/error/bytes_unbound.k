// a Bytes an expression gives is bound before it is used (#54, O4)
let main():i32 {
    println(Bytes("x").count)
    return 0
}
// error: '.count' of a Bytes that an expression gives: bind it to a variable first, which frees it when its block ends
