// error: the type of $0, [[i64](...)](2), has an array length or a .type written in another scope
let main():int32 {
    let n:int64 = 3;
    let f:([[int64](sizeof([int64](n)) / 8)](2)):int64 := { $0[1][0] };
    return 0;
}
