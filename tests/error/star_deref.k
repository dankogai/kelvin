// error: dereference is a postfix '^' in Kelvin: write 'p^' instead of '*p'
let f(p:i32^):i32 {
    var x:i32 = *p;
    return 0;
}
