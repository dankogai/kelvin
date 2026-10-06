// error: '$' alone is not a value
let apply(x:i64, f:(i64):i64):i64 { return f(x); }
let main():i32 {
    println(apply(1) { $ });
    return 0;
}
