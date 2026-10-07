// a string literal infers cstr (#52), a reference: it is assigned with :=
// error: 's' is a reference (cstr): assign it with ':=', not '='
let f(c:bool):i32 {
    var s = "hi";
    return 0;
}
