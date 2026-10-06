// error: '$4294967296': this anonymous function has 1 parameter
let apply(x:i64, f:(i64):i64):i64 { return f(x); }
let main():i32 {
    println(apply(5) { $4294967296 + 1 });
    return 0;
}
