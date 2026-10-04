// error: 'f' looks like a C function-pointer declaration: write 'f:(...):i64' (#31)
struct s { i64 (*f)(i64); };
main():i32 { return 0; }
