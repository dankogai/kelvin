// error: '$' alone is not a value
apply(x:i64, f:(i64):i64):i64 { return f(x); }
main():i32 {
    println(apply(1) { $ });
    return 0;
}
