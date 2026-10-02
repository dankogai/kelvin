// error: Kelvin has no 'var': write 'p: T := ...', or 'p := ...' to infer the type
main(): i32 { x: i32 = 1; var p := &x; return 0; }
