// error: 'g' needs a type: in (i64, [[i64](n)](2)):i64, an array length names a parameter
let main():int32 {
    let g := { (n:int64, a:[[int64](n)](2)):int64 in a[1][n - 1] };
    return 0;
}
