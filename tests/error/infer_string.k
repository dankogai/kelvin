// a string literal infers cstr (#52), a reference: it is assigned with :=
// error: 's' is a reference (cstr): assign it with ':=', not '='
let f(c:bool):int32 {
    var s = "hi";
    return 0;
}
