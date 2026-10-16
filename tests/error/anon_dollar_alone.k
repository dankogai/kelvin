// error: '$' alone is not a value
let apply(x:int64, f:(int64):int64):int64 { return f(x); }
let main():int32 {
    println(apply(1) { $ });
    return 0;
}
