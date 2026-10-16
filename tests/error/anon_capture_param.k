// error: an anonymous function cannot use 'k' of the function around it
let apply(x:int64, f:(int64):int64):int64 { return f(x); }
let addk(k:int64):int64 {
    return apply(1) { $0 + k };
}
let main():int32 { return 0; }
