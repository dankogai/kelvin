// error: an anonymous function cannot use 'k' of the function around it
let apply(x:i64, f:(i64):i64):i64 { return f(x); }
let addk(k:i64):i64 {
    return apply(1) { $0 + k };
}
let main():i32 { return 0; }
