// error: 'p' needs a type: write 'p:T = ...' (or 'p:T := ...' for a reference)
main():i32 { var x:i32 = 1; var p := &x; return 0; }
