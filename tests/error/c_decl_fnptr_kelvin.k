// error: 'f' looks like a C function-pointer declaration: write 'var f:(...):i64' (#31)
let main():int32 {
    int64 (*f)(int64);
    return 0;
}
