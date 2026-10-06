// error: for over xs: its declared length uses a call, a var or a name that a local hides
let sum(var n:i64, xs:[i32](n)):i64 {
    var t:i64 = 0;
    n = 2;
    for x in xs {
        t += x;
    }
    return t;
}
let main():i32 { return 0; }
