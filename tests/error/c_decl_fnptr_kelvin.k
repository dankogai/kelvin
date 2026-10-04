// error: 'f' looks like a C function-pointer declaration: write 'var f:(...):i64' (#31)
main():i32 {
    i64 (*f)(i64);
    return 0;
}
