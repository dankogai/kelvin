// error: a pointer to a function type, or an array of functions, has no spelling yet
inc(x:i64):i64 { return x + 1; }
main():i32 {
    var f:(i64):i64 := inc;
    let pf:((i64):i64)^ := &f;
    return 0;
}
