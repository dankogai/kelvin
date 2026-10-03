// error: an anonymous function cannot use 'k' of the function around it
apply(x:i64, f:(i64):i64):i64 { return f(x); }
main():i32 {
    let k = 3;
    println(apply(1) { $0 + k });
    return 0;
}
