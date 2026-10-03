// error: '$[01]' has a leading zero: write $[1]
apply(x:i64, f:(i64):i64):i64 { return f(x); }
main():i32 {
    println(apply(5) { $[01] });
    return 0;
}
