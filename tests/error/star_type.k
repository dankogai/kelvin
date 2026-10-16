// error: pointer types are written with a postfix '^', as in 'i32^'
let f(p:i32^):i32 {
    var q:int32* = p;
    return 0;
}
