// error: a condition must be a bool, not (i64):i64: compare it, as in 'f != nullptr'
main():i32 {
    var f:(i64):i64;
    if f {
        println(1);
    }
    return 0;
}
