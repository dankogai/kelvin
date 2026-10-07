// error: 'p' is a reference (cstr): assign it with ':=', not '='
// cstr is a reference, so it is assigned with :=
let main():i32 {
    var p:cstr = "text";
    return 0;
}
