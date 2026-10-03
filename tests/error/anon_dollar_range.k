// error: '$1': this anonymous function has 1 parameter
apply(x:i64, f:(i64):i64):i64 { return f(x); }
main():i32 {
    println(apply(1) { $1 });
    return 0;
}
