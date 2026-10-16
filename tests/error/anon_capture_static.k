// error: an anonymous function cannot use 'k' of the function around it
let apply(x:int64, f:(int64):int64):int64 { return f(x); }
let main():int32 {
    static var k = 3;
    println(apply(1) { $0 + k });
    return 0;
}
