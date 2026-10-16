// error: '$0' cannot be used in the parameters or result of the function it names
let apply(x:int64, f:(int64):int64):int64 { return f(x); }
let main():int32 {
    println(apply(2) { apply($0) { (b:int64[$0]):int64 in 1 } });
    return 0;
}
