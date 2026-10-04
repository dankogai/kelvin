// error: a pointer to a function type, or an array of functions, has no spelling yet
inc(x:i64):i64 { return x + 1; }
main():i32 {
    var hs:inc.type[2];
    return 0;
}
