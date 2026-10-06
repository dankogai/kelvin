// error: for over xs: its declared length uses a call, a var or a name that a local hides
let sum(n:i64, xs:[i32](n)):i64 {
    let n = 99;
    var t:i64 = 0;
    for x in xs {
        t += x;
    }
    return t;
}
let main():i32 { return 0; }
