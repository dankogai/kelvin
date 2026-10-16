// error: 'cb' looks like a C function-pointer declaration: write 'cb:(...):i64' (#31)
let f(int64 (*cb)(int64)) {}
let main():int32 { return 0; }
