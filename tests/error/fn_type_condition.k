// error: a condition must be a bool, not (i64):i64: compare it, as in 'f != nullptr'
let main():int32 {
    var f:(int64):int64;
    if f {
        println(1);
    }
    return 0;
}
