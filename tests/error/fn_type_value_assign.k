// error: 'f' is a reference ((i64):i64): assign it with ':=', not '='
let twice(x:i64):i64 { return x * 2; }
let main():i32 {
    let f:(i64):i64 = twice;
    return 0;
}
