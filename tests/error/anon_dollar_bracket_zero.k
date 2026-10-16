// error: '$[01]' has a leading zero: write $[1]
let apply(x:int64, f:(int64):int64):int64 { return f(x); }
let main():int32 {
    println(apply(5) { $[01] });
    return 0;
}
