// error: $[...] takes a number, as in $[0]
let apply(x:i64, f:(i64):i64):i64 { return f(x); }
let main():i32 {
    let i = 0;
    println(apply(1) { $[i] });
    return 0;
}
