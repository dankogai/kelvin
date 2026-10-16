// error: '$1': this anonymous function has 1 parameter
let apply(x:int64, f:(int64):int64):int64 { return f(x); }
let main():int32 {
    println(apply(1) { $1 });
    return 0;
}
