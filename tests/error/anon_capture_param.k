// error: an anonymous function cannot use 'k' of the function around it
apply(x:i64, f:(i64):i64):i64 { return f(x); }
addk(k:i64):i64 {
    return apply(1) { $0 + k };
}
main():i32 { return 0; }
