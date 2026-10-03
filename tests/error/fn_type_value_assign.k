// error: 'f' is a reference ((i64):i64): assign it with ':=', not '='
twice(x:i64):i64 { return x * 2; }
main():i32 {
    let f:(i64):i64 = twice;
    return 0;
}
