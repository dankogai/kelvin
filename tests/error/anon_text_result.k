// error: which is gone once it returns: the caller takes the text itself, as in '{ println($0.hex) }'
let show(x:int64, f:(int64):cstr) { println(f(x)); }
let main():int32 {
    show(255) { $0.hex }
    return 0;
}
