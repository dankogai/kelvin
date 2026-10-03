// error: expected 'in' after the parameters
main():i32 {
    let f := { (a:i64):i64 in a };
    let g := { (a:i64):i64 a };
    return 0;
}
