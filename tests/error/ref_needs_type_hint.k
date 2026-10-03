// error: 't' needs a type: write 't:T = ...' (or 't:T := ...' for a reference)
main():i32 { var x:i32 = 1; var t = &x; return 0; }
