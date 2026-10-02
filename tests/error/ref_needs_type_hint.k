// error: 't' needs a type: write 't: T = ...' (or 't: T := ...' for a reference)
main(): i32 { x: i32 = 1; t = &x; return 0; }
