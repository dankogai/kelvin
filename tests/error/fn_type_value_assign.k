// error: 'f' is a reference ((i64):i64): assign it with ':=', not '='
let twice(x:int64):int64 { return x * 2; }
let main():int32 {
    let f:(int64):int64 = twice;
    return 0;
}
