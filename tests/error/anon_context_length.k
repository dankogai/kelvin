// error: has an array length or a .type written in another scope, which kelvinc cannot carry into this function
apply(n:i64, a:i64[2][n], f:(i64[2][n]):i64):i64 { return f(a); }
main():i32 {
    var m:i64[2][3] = {{1, 2, 3}, {4, 5, 6}};
    println(apply(3, m) { $0[1][0] });
    return 0;
}
