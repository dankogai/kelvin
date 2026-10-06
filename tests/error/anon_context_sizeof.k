// error: the type of $0, [[i64](...)](2), has an array length or a .type written in another scope
let main():i32 {
    let n:i64 = 3;
    let f:([[i64](sizeof([i64](n)) / 8)](2)):i64 := { $0[1][0] };
    return 0;
}
