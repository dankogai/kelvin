// a reference inferred from &x (#47) is assigned with :=, as a written one is
// error: 't' is a reference (i32^): assign it with ':=', not '='
let main():i32 { var x:i32 = 1; var t = &x; return 0; }
