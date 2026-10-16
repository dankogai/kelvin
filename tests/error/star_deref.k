// error: dereference is a postfix '^' in Kelvin: write 'p^' instead of '*p'
let f(p:int32^):int32 {
    var x:int32 = *p;
    return 0;
}
