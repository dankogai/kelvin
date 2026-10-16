// error: for over xs: its declared length uses a call, a var or a name that a local hides
let sum(var n:int64, xs:[int32](n)):int64 {
    var t:int64 = 0;
    n = 2;
    for x in xs {
        t += x;
    }
    return t;
}
let main():int32 { return 0; }
