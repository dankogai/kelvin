// error: an anonymous function here writes its parameters, as in '{ (a:i64):i64 in a + 1 }'
apply(x:i64, f:(i64):i64):i64 { return f(x); }
main():i32 {
    println(apply(1, ({ $0 + 1 })));
    return 0;
}
