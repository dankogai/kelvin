// error: 'apply' takes 2 arguments, and this anonymous function would be argument 3
let apply(x:i64, f:(i64):i64):i64 { return f(x); }
let inc(x:i64):i64 { return x + 1; }
let main():i32 {
    println(apply(1, inc) { $0 * 2 });
    return 0;
}
