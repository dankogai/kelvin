// error: an anonymous function cannot use 'a' of the function around it
let apply(x:int64, f:(int64):int64):int64 { return f(x); }
let main():int32 {
    println(apply(1) { (a:int64):int64 in apply(2) { $0 + a } });
    return 0;
}
