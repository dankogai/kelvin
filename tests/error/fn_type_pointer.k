// error: a pointer to a function type groups the type in parentheses: ((i64):i64)^ (#403)
let inc(x:int64):int64 { return x + 1; }
let main():int32 {
    var f:(int64):int64 := inc;
    var g:(int64)^;
    return 0;
}
