// error: 'g' needs a type: in (i64, i64[2][...]):i64, an array length names a parameter
let main():i32 {
    let g := { (n:i64, a:i64[2][n]):i64 in a[1][n - 1] };
    return 0;
}
