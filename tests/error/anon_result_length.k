// error: the result type, i64[...]^, has an array length or a .type written in another scope
var g:i64[2][3] = {{1, 2, 3}, {4, 5, 6}};
main():i32 {
    let k = 3;
    let f:(i64):i64[k]^ := { (i:i64) in &g[i] };
    return 0;
}
