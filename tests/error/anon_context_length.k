// error: has an array length or a .type written in another scope, which kelvinc cannot carry into this function
let apply(n:i64, a:[[i64](n)](2), f:([[i64](n)](2)):i64):i64 { return f(a); }
let main():i32 {
    var m:[[i64](3)](2) = [[1, 2, 3], [4, 5, 6]];
    println(apply(3, m) { $0[1][0] });
    return 0;
}
