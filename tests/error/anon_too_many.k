// error: 'apply' takes 2 arguments, and this anonymous function would be argument 3
let apply(x:int64, f:(int64):int64):int64 { return f(x); }
let inc(x:int64):int64 { return x + 1; }
let main():int32 {
    println(apply(1, inc) { $0 * 2 });
    return 0;
}
