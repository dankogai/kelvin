// error: 'cb' looks like a C function-pointer declaration: write 'cb:(...):i64' (#31)
f(i64 (*cb)(i64)) {}
main():i32 { return 0; }
