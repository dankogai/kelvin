// error: '$4294967296': this anonymous function has 1 parameter
apply(x:i64, f:(i64):i64):i64 { return f(x); }
main():i32 {
    println(apply(5) { $4294967296 + 1 });
    return 0;
}
