// error: $[...] takes a number, as in $[0]
let apply(x:int64, f:(int64):int64):int64 { return f(x); }
let main():int32 {
    let i = 0;
    println(apply(1) { $[i] });
    return 0;
}
