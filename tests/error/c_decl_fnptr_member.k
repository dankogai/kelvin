// error: 'f' looks like a C function-pointer declaration: write 'f:(...):i64' (#31)
struct s { int64 (*f)(int64); };
let main():int32 { return 0; }
