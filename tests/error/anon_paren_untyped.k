// error: an anonymous function here writes its parameters, as in '{ (a:i64):i64 in a + 1 }'
let apply(x:int64, f:(int64):int64):int64 { return f(x); }
let main():int32 {
    println(apply(1, ({ $0 + 1 })));
    return 0;
}
