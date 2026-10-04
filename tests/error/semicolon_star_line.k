// error: dereference is a postfix '^' in Kelvin: write 'p^' instead of '*p'
main():i32 {
    var x:i32 = 0
    var p:i32^ := &x
    println(x)
    *p = 1
    return 0
}
