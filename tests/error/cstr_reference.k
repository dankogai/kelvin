// error: 'p' is a reference (u8^): assign it with ':=', not '='
// cstr is u8^, so it is assigned with :=
let main():i32 {
    var p:cstr = "text";
    return 0;
}
