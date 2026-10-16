// error: '.hex' text lives in a buffer of this function, which is gone once it returns
let show(n:int64, f:(int64):cstr) { println(f(n)); }
let main():int32 {
    show(255) { $0 > 0 ? $0.hex as cstr : "neg" as cstr }
    return 0;
}
