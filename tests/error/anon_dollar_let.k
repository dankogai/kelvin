// error: '$0' is a parameter and cannot change
apply(x:i64, f:(i64):i64):i64 { return f(x); }
main():i32 {
    println(apply(1) {
        $0 = 2;
        return $0;
    });
    return 0;
}
