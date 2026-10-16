// error: '$00' has a leading zero: write $0
let apply(x:int64, f:(int64):int64):int64 { return f(x); }
let main():int32 {
    println(apply(5) { $00 });
    return 0;
}
