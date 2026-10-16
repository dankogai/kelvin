// error: '$0' is a parameter and cannot change
let apply(x:int64, f:(int64):int64):int64 { return f(x); }
let main():int32 {
    println(apply(1) {
        $0 = 2;
        return $0;
    });
    return 0;
}
