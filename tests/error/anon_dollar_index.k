// error: $[...] takes a number, as in $[0]
apply(x:i64, f:(i64):i64):i64 { return f(x); }
main():i32 {
    let i = 0;
    println(apply(1) { $[i] });
    return 0;
}
