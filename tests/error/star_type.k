// error: pointer types are written with a postfix '^', as in 'i32^'
let f(p:int32^):int32 {
    var q:int32* = p;
    return 0;
}
