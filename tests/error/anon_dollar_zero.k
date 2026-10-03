// error: '$00' has a leading zero: write $0
apply(x:i64, f:(i64):i64):i64 { return f(x); }
main():i32 {
    println(apply(5) { $00 });
    return 0;
}
