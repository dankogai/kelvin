// error: an anonymous function cannot use 'kk' of the function around it
let apply(x:int64, f:(int64):int64):int64 { return f(x); }
let main():int32 {
    let kk = 1;
    println(apply(1) {
        var x:kk.type = $0;
        return x;
    });
    return 0;
}
