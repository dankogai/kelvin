// error: 'p' needs a type: write 'p:T = ...' (or 'p:T := ...' for a reference)
let main():i32 { var x:i32 = 1; var p := &x; return 0; }
