// error: assignment is a statement in Kelvin, not a value
apply(x:i64, f:(i64):i64):i64 { return f(x); }
var total:i64 = 0;
main():i32 {
    println(apply(1) { total += $0 });
    return 0;
}
