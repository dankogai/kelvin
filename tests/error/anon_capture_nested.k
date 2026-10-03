// error: an anonymous function cannot use 'a' of the function around it
apply(x:i64, f:(i64):i64):i64 { return f(x); }
main():i32 {
    println(apply(1) { (a:i64):i64 in apply(2) { $0 + a } });
    return 0;
}
