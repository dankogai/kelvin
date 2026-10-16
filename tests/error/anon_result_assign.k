// error: an assignment has no value (#26), but this function has a result
let apply(x:int64, f:(int64):int64):int64 { return f(x); }
var total:int64 = 0;
let main():int32 {
    println(apply(1) { total += $0 });
    return 0;
}
