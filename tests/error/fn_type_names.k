// error: a function type lists its parameters' types without names
apply(x:i64, f:(a:i64):i64):i64 { return f(x); }
main():i32 { return 0; }
