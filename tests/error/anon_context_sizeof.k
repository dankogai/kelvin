// error: the type of $0, i64[2][...], has an array length written in another scope
main():i32 {
    let n:i64 = 3;
    let f:(i64[2][sizeof(i64[n]) / 8]):i64 := { $0[1][0] };
    return 0;
}
