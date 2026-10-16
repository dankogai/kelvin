// error: tests/error/c_type_error.k:3:
let f(p:int32^):int32 {
    var s:struct nope = 0;
    return 0;
}
